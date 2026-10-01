using Microsoft.EntityFrameworkCore;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    /// <summary>
    /// Project Resource Estimation. For the requested category, learns from every past
    /// <c>Delivered</c> project of that category how many hours per work type its tonnage
    /// usually took, fits one simple linear regression per work type (hours vs. tonnage),
    /// and reads the new project's tonnage through it. Nothing is stored - every call
    /// re-fits from whatever work logs exist right now, so the estimate can only improve
    /// as the shop delivers more projects.
    /// </summary>
    public class RecommendationService : IRecommendationService
    {
        /// <summary>
        /// Below this many past delivered projects the fit is not worth showing - two
        /// points draw a line through anything.
        /// </summary>
        public const int MinSampleSize = 3;

        /// <summary>A worker's day, the same number the reports and work-hours screens use.</summary>
        public const double HoursPerWorkerPerDay = OvertimeRules.RegularHoursPerDay;

        private readonly PWMDbContext _dbContext;

        public RecommendationService(PWMDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task<RecommendationResponse> EstimateAsync(RecommendationRequest request)
        {
            if (request.Tonnes <= 0)
            {
                throw new ClientException("Expected tonnage has to be greater than zero.");
            }

            if (request.WorkingDays <= 0)
            {
                throw new ClientException("The deadline has to be at least one working day.");
            }

            var category = await _dbContext.ProjectCategories
                .FirstOrDefaultAsync(x => x.Id == request.ProjectCategoryId)
                ?? throw new ClientException(
                    $"Project category {request.ProjectCategoryId} does not exist.");

            // Only a completed project has a known outcome to learn from.
            var pastProjects = await _dbContext.Projects
                .Include(x => x.ProjectStatus)
                .Where(x => x.ProjectCategoryId == category.Id)
                .Where(x => x.ProjectStatus.Name == ProjectStatusRules.Delivered)
                .ToListAsync();

            if (pastProjects.Count < MinSampleSize)
            {
                return new RecommendationResponse
                {
                    HasEstimate = false,
                    SampleSize = pastProjects.Count,
                    Message = pastProjects.Count == 0
                        ? $"No delivered projects of \"{category.Name}\" yet - the estimator " +
                          "has nothing to learn this category's hours-per-tonne from."
                        : $"Only {pastProjects.Count} delivered project(s) of \"{category.Name}\" " +
                          $"so far; at least {MinSampleSize} are needed before an estimate is shown.",
                };
            }

            var projectIds = pastProjects.Select(x => x.Id).ToHashSet();

            var blocks = await _dbContext.WorkLogDetails
                .Where(x => projectIds.Contains(x.ProjectId))
                .Select(x => new { x.ProjectId, x.OperationTypeId, x.UserId, x.Hours })
                .ToListAsync();

            var operationTypes = await _dbContext.OperationTypes.ToDictionaryAsync(x => x.Id, x => x.Name);

            // Project.Weight is stored in kilograms; the request and this estimate use tonnes.
            var tonnesById = pastProjects.ToDictionary(x => x.Id, x => x.Weight / 1000.0);

            // Every work type that was ever booked against this category, so a project
            // that needed none of it this time still lands on the line as a zero.
            var workedTypeIds = blocks.Select(x => x.OperationTypeId).Distinct().ToArray();

            var workTypes = new List<RecommendationWorkTypeResponse>();

            foreach (var operationTypeId in workedTypeIds)
            {
                var hoursByProject = pastProjects.ToDictionary(x => x.Id, _ => 0.0);

                foreach (var block in blocks.Where(x => x.OperationTypeId == operationTypeId))
                {
                    hoursByProject[block.ProjectId] += block.Hours;
                }

                var points = pastProjects
                    .Select(x => (Tonnes: tonnesById[x.Id], Hours: hoursByProject[x.Id]))
                    .ToArray();

                var (slope, intercept) = FitLine(points);
                var estimatedHours = Math.Max(0, slope * request.Tonnes + intercept);

                if (estimatedHours < 0.05)
                {
                    continue;
                }

                workTypes.Add(new RecommendationWorkTypeResponse
                {
                    OperationTypeId = operationTypeId,
                    OperationTypeName = operationTypes.GetValueOrDefault(operationTypeId, "Unknown"),
                    EstimatedHours = Math.Round(estimatedHours, 1),
                });
            }

            var totalHours = workTypes.Sum(x => x.EstimatedHours);

            foreach (var workType in workTypes)
            {
                workType.SharePercent = totalHours > 0
                    ? Math.Round(workType.EstimatedHours / totalHours * 100, 1)
                    : 0;
            }

            workTypes = workTypes.OrderByDescending(x => x.EstimatedHours).ToList();

            // A second fit, of the project's total hours against its tonnage, purely to
            // say how well tonnage explains hours for this category - not used for the
            // per-work-type numbers above, which each have their own line.
            var totalPoints = pastProjects
                .Select(x => (Tonnes: tonnesById[x.Id], Hours: blocks
                    .Where(b => b.ProjectId == x.Id)
                    .Sum(b => b.Hours)))
                .ToArray();

            var accuracy = RSquared(totalPoints);
            var accuracyPercent = Math.Round(Math.Clamp(accuracy, 0, 1) * 100, 1);

            // The one sentence that answers "why this number" - shown next to the
            // estimate rather than left for the sample size and accuracy cards to
            // imply on their own.
            var explanation =
                $"Estimated by fitting a linear trend between tonnage and hours per work " +
                $"type across {pastProjects.Count} past delivered \"{category.Name}\" " +
                $"project{(pastProjects.Count == 1 ? "" : "s")}; that trend explains about " +
                $"{accuracyPercent:0.#}% of the variation in the hours those projects actually took.";

            var typicalCrewSize = Math.Max(1, (int)Math.Round(pastProjects
                .Select(x => blocks.Where(b => b.ProjectId == x.Id).Select(b => b.UserId).Distinct().Count())
                .DefaultIfEmpty(1)
                .Average()));

            return new RecommendationResponse
            {
                HasEstimate = true,
                SampleSize = pastProjects.Count,
                AccuracyPercent = accuracyPercent,
                Explanation = explanation,
                TotalHours = Math.Round(totalHours, 1),
                EstimatedWorkers = Math.Max(1,
                    (int)Math.Ceiling(totalHours / (request.WorkingDays * HoursPerWorkerPerDay))),
                EstimatedDurationDays = Math.Max(1,
                    (int)Math.Ceiling(totalHours / (typicalCrewSize * HoursPerWorkerPerDay))),
                WorkTypes = workTypes,
            };
        }

        /// <summary>
        /// Ordinary least squares over (x, y) pairs. Falls back to a flat line through the
        /// mean when every x is identical, which a two-or-more-point sample can still hit
        /// if two past projects happened to carry the same tonnage.
        /// </summary>
        private static (double Slope, double Intercept) FitLine((double X, double Y)[] points)
        {
            var meanX = points.Average(p => p.X);
            var meanY = points.Average(p => p.Y);

            var covariance = points.Sum(p => (p.X - meanX) * (p.Y - meanY));
            var variance = points.Sum(p => (p.X - meanX) * (p.X - meanX));

            if (variance < 1e-9)
            {
                return (0, meanY);
            }

            var slope = covariance / variance;
            var intercept = meanY - slope * meanX;

            return (slope, intercept);
        }

        private static double RSquared((double Tonnes, double Hours)[] points)
        {
            if (points.Length < 2)
            {
                return 0;
            }

            var (slope, intercept) = FitLine(points.Select(p => (p.Tonnes, p.Hours)).ToArray());
            var meanY = points.Average(p => p.Hours);

            var totalSumOfSquares = points.Sum(p => (p.Hours - meanY) * (p.Hours - meanY));

            if (totalSumOfSquares < 1e-9)
            {
                return 1;
            }

            var residualSumOfSquares = points.Sum(p =>
            {
                var predicted = slope * p.Tonnes + intercept;
                return (p.Hours - predicted) * (p.Hours - predicted);
            });

            return 1 - residualSumOfSquares / totalSumOfSquares;
        }
    }
}
