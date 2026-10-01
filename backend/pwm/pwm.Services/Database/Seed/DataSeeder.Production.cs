using Microsoft.EntityFrameworkCore;
using pwm.Model.Enums;

namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        /// <summary>The office accounts a project can be raised by.</summary>
        private User[] OfficeUsers => _users
            .Where(u => u.UserTypeId != FindUserType("Production worker").Id)
            .ToArray();

        private async Task SeedProjectsAsync()
        {
            var projects = new List<Project>
            {
                CreateProject("Hall roof structure", "Stahlbau Meyer GmbH", "General steel construction",
                    weight: 12450.5, createdDaysAgo: 96, startedDaysAgo: 88, deliveryInDays: -12,
                    status: "Delivered", deliveryArranged: true,
                    priority: ProjectPriority.High, createdBy: "kenan.fajic@pwm.ba",
                    description: "Primary roof structure for the new production hall, hot-dip galvanised.",
                    notes: "Customer collected the galvanising certificates on delivery."),

                CreateProject("Conveyor frame", "Nordmetall AG", "Sections",
                    weight: 3820.0, createdDaysAgo: 74, startedDaysAgo: 66, deliveryInDays: -4,
                    status: "Delivered", deliveryArranged: true,
                    priority: ProjectPriority.Medium, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Welded support frame for a belt conveyor, delivered in four sections.",
                    notes: null),

                CreateProject("Staircase module", "Wiener Metallwerke GmbH", "General steel construction",
                    weight: 1640.75, createdDaysAgo: 52, startedDaysAgo: 44, deliveryInDays: 3,
                    status: "In production", deliveryArranged: true,
                    priority: ProjectPriority.VeryHigh, createdBy: "kenan.fajic@pwm.ba",
                    description: "Two-flight staircase with landing and powder-coated handrail.",
                    notes: "Delivery window is tight - the site crane is booked for one morning only."),

                CreateProject("Machine base plates", "Adria Konstrukcije d.o.o.", "Foundations - steel",
                    weight: 2210.0, createdDaysAgo: 40, startedDaysAgo: 31, deliveryInDays: 9,
                    status: "In production", deliveryArranged: true,
                    priority: ProjectPriority.High, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Machined and drilled base plates for four press foundations.",
                    notes: "Flatness has to be checked before packing."),

                CreateProject("Extraction ducting", "Alpina Systems GmbH", "Heavy ducting - stainless steel",
                    weight: 980.25, createdDaysAgo: 27, startedDaysAgo: 19, deliveryInDays: 16,
                    status: "In production", deliveryArranged: false,
                    priority: ProjectPriority.Low, createdBy: "kenan.fajic@pwm.ba",
                    description: "Rolled and welded extraction ducting with flanged joints.",
                    notes: null),

                CreateProject("Platform driptrays", "Stahlbau Meyer GmbH", "Driptrays - aluminum",
                    weight: 745.5, createdDaysAgo: 18, startedDaysAgo: 10, deliveryInDays: 24,
                    status: "In production", deliveryArranged: false,
                    priority: ProjectPriority.Medium, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Folded aluminium driptrays for a maintenance platform.",
                    notes: null),

                CreateProject("Support brackets", "Nordmetall AG", "Sections",
                    weight: 1310.0, createdDaysAgo: 9, startedDaysAgo: 2, deliveryInDays: 33,
                    status: "On hold", deliveryArranged: false,
                    priority: ProjectPriority.Medium, createdBy: "kenan.fajic@pwm.ba",
                    description: "Repeat order of welded pipe brackets, same drawing as the conveyor frame.",
                    notes: "On hold until the customer confirms the revised drawing."),

                CreateProject("Silo foundations", "Adria Konstrukcije d.o.o.", "Foundations - steel",
                    weight: 8600.0, createdDaysAgo: 4, startedDaysAgo: 1, deliveryInDays: 47,
                    status: "On hold", deliveryArranged: false,
                    priority: ProjectPriority.High, createdBy: "nadir.hujdur@pwm.ba",
                    description: "Anchor cages and base frames for four silo legs.",
                    notes: "Waiting on the customer to confirm the plate grade."),

                CreateProject("Trial batch", "Wiener Metallwerke GmbH", "Driptrays - stainless steel",
                    weight: 320.0, createdDaysAgo: 60, startedDaysAgo: 55, deliveryInDays: -20,
                    status: "Rejected", deliveryArranged: false,
                    priority: ProjectPriority.Low, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Sample batch for a facade tender.",
                    notes: "Rejected - the customer did not win the tender."),

                // Still being quoted - no production hours or delivery company yet,
                // only the office work an offer needs.
                CreateProject("Loading dock canopy", "Alpina Systems GmbH", "General steel construction",
                    weight: 5400.0, createdDaysAgo: 6, startedDaysAgo: 0, deliveryInDays: 70,
                    status: "Potential", deliveryArranged: false,
                    priority: ProjectPriority.Medium, createdBy: "kenan.fajic@pwm.ba",
                    description: "Cantilevered canopy over the customer's loading dock - awaiting their go-ahead.",
                    notes: null),

                CreateProject("Filter tower access", "Adria Konstrukcije d.o.o.", "General steel construction",
                    weight: 2900.0, createdDaysAgo: 2, startedDaysAgo: 0, deliveryInDays: 90,
                    status: "Potential", deliveryArranged: false,
                    priority: ProjectPriority.Low, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Access platform and ladder cage for a new filter tower - drawings in progress.",
                    notes: null),

                // These four exist so the Recommendations screen's estimator has
                // more than one delivered project of a category to learn from -
                // RecommendationService.MinSampleSize is 3, and without them no
                // seeded category reliably clears it.
                CreateProject("Roof purlin batch two", "Nordmetall AG", "Sections",
                    weight: 2650.0, createdDaysAgo: 100, startedDaysAgo: 92, deliveryInDays: -30,
                    status: "Delivered", deliveryArranged: true,
                    priority: ProjectPriority.Medium, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Second run of welded purlins, same drawing as the first batch.",
                    notes: null),

                CreateProject("Mezzanine support sections", "Wiener Metallwerke GmbH", "Sections",
                    weight: 4980.0, createdDaysAgo: 85, startedDaysAgo: 78, deliveryInDays: -18,
                    status: "Delivered", deliveryArranged: true,
                    priority: ProjectPriority.Low, createdBy: "kenan.fajic@pwm.ba",
                    description: "Welded sections for a warehouse mezzanine deck.",
                    notes: null),

                CreateProject("Access gantry frame", "Stahlbau Meyer GmbH", "General steel construction",
                    weight: 6200.0, createdDaysAgo: 70, startedDaysAgo: 63, deliveryInDays: -9,
                    status: "Delivered", deliveryArranged: true,
                    priority: ProjectPriority.High, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Welded gantry frame for a maintenance access walkway.",
                    notes: null),

                CreateProject("Workshop extension frame", "Adria Konstrukcije d.o.o.",
                    "General steel construction",
                    weight: 3150.0, createdDaysAgo: 45, startedDaysAgo: 38, deliveryInDays: -2,
                    status: "Delivered", deliveryArranged: true,
                    priority: ProjectPriority.Medium, createdBy: "nadir.hujdur@pwm.ba",
                    description: "Structural steel frame for the workshop's new bay.",
                    notes: null),
            };

            projects.AddRange(RandomProjects(15, startingAt: projects.Count));

            AssignCodes(projects);

            _projects = projects.ToArray();
            await AddRangeAsync(_projects);
        }

        /// <summary>
        /// The shop's own reference, handed out in creation order and restarting
        /// each year: 26-001, 26-002, ... 27-001.
        /// </summary>
        private static void AssignCodes(List<Project> projects)
        {
            var nextInYear = new Dictionary<int, int>();

            foreach (var project in projects.OrderBy(p => p.CreationDate).ThenBy(p => p.Name))
            {
                var year = project.CreationDate.Year;
                nextInYear[year] = nextInYear.GetValueOrDefault(year) + 1;

                project.Code = $"{year % 100:00}-{nextInYear[year]:000}";
            }
        }

        /// <summary>Fills the book out beyond the handful written by hand.</summary>
        private IEnumerable<Project> RandomProjects(int count, int startingAt)
        {
            var customers = _companies
                .Where(c => c.CompanyTypeId == FindCompanyType("Customer").Id)
                .ToArray();

            var office = OfficeUsers;
            var priorities = Enum.GetValues<ProjectPriority>();
            var statuses = new[]
                { "Delivered", "In production", "In production", "On hold", "Rejected", "Potential" };

            var subjects = new[]
            {
                "Access platform", "Anchor frames", "Bunker lining", "Cable ducting",
                "Chute segments", "Column bases", "Filter housing", "Gangway frames",
                "Hopper shell", "Inspection covers", "Ladder cages", "Pipe supports",
                "Purlin sets", "Screen frames", "Skid frames", "Tank saddles",
                "Transfer chute", "Walkway grating",
            };

            for (var i = 0; i < count; i++)
            {
                var customer = Pick(customers);
                var status = statuses[(startingAt + i) % statuses.Length];
                var isPotential = status == "Potential";
                var createdDaysAgo = isPotential ? _random.Next(0, 14) : _random.Next(6, 110);
                var startedDaysAgo = createdDaysAgo - _random.Next(2, 9);

                yield return new Project
                {
                    Name = subjects[(startingAt + i) % subjects.Length],
                    Code = string.Empty,
                    Description = null,
                    Notes = null,
                    Priority = Pick(priorities),
                    CustomerId = customer.Id,
                    ProjectCategoryId = Pick(_projectCategories).Id,
                    Weight = Math.Round(_random.Next(200, 14000) + _random.NextDouble(), 2),
                    CreationDate = _today.AddDays(-createdDaysAgo).AddHours(8),
                    // Null while still being quoted - a Potential project has not
                    // reached the shop floor yet.
                    ProductionStartDate =
                        isPotential ? null : _today.AddDays(-startedDaysAgo).AddHours(7),
                    DeliveryDate = _today.AddDays(_random.Next(-30, 60)).AddHours(14),
                    // Null while delivery is not arranged yet; otherwise where the
                    // customer takes it - never the carrier, which is a TruckLoad's.
                    // Never arranged for a project still being quoted, either.
                    DeliveryCompanyId = isPotential || _random.Next(3) == 0
                        ? null
                        : DeliveryPlaceFor(customer).Id,
                    ProjectStatusId = FindStatus(status).Id,
                    CreatedByUserId = Pick(office).Id,
                };
            }
        }

        private Project CreateProject(
            string name,
            string customer,
            string category,
            double weight,
            int createdDaysAgo,
            int startedDaysAgo,
            int deliveryInDays,
            string status,
            bool deliveryArranged,
            ProjectPriority priority,
            string createdBy,
            string? description,
            string? notes)
        {
            // Still being quoted - no production start and no delivery arranged,
            // whatever the caller passed for either.
            var isPotential = status == "Potential";

            return new Project
            {
                Name = name,
                Code = string.Empty,
                Description = description,
                Notes = notes,
                Priority = priority,
                CustomerId = FindCompany(customer).Id,
                ProjectCategoryId = FindCategory(category).Id,
                Weight = weight,
                CreationDate = _today.AddDays(-createdDaysAgo).AddHours(8),
                ProductionStartDate = isPotential ? null : _today.AddDays(-startedDaysAgo).AddHours(7),
                DeliveryDate = _today.AddDays(deliveryInDays).AddHours(14),
                DeliveryCompanyId = isPotential || !deliveryArranged
                    ? null
                    : DeliveryPlaceFor(FindCompany(customer)).Id,
                ProjectStatusId = FindStatus(status).Id,
                CreatedByUserId = FindUser(createdBy).Id,
            };
        }

        private async Task SeedWorkLogsAsync()
        {
            var workers = _users
                .Where(u => u.IsActive && u.UserTypeId == FindUserType("Production worker").Id)
                .ToArray();

            // A rejected project - or one still being quoted - never reached the
            // shop floor, so there are no production hours to seed against it.
            var bookableProjects = _projects
                .Where(p => p.ProjectStatusId != FindStatus("Rejected").Id
                    && p.ProjectStatusId != FindStatus("Potential").Id)
                .ToArray();

            var workLogs = new List<WorkLog>();
            var shifts = new List<(WorkLog Log, DateTime Start, DateTime End)>();

            // Whole months, so Monthly Reports has a few full ones to show.
            foreach (var day in WorkingDaysSince(new DateTime(_today.Year, _today.Month, 1).AddMonths(-2)))
            {
                foreach (var user in workers)
                {
                    // Roughly one absence in every twelve shifts
                    if (_random.Next(12) == 0)
                    {
                        continue;
                    }

                    var clockedIn = day.AddHours(7).AddMinutes(_random.Next(0, 16));
                    var clockedOut = day.AddHours(15).AddMinutes(30 + _random.Next(0, 46));
                    var hours = Math.Round((clockedOut - clockedIn).TotalHours, 2);

                    var workLog = new WorkLog
                    {
                        UserId = user.Id,
                        ClockedIn = clockedIn,
                        ClockedOut = clockedOut,
                        Hours = hours,
                    };

                    workLogs.Add(workLog);
                    shifts.Add((workLog, clockedIn, clockedOut));
                }
            }

            _workLogs = workLogs.ToArray();
            await AddRangeAsync(_workLogs);

            // A shift is one day of work; the blocks under it are the individual
            // operations that worker did that day.
            var details = new List<WorkLogDetail>();

            // Its own sequence, so adding notes left every other seeded value as it was.
            var noteRandom = new Random(20260930);

            foreach (var (log, start, end) in shifts)
            {
                var qualifiedOperations = await QualifiedOperationsAsync(log.UserId);
                // Only projects already in production that day - falling back to the
                // longest-running one for the first days of the seeded range.
                var started = bookableProjects
                    .Where(p => p.ProductionStartDate is { } began && began.Date <= start.Date)
                    .ToArray();
                if (started.Length == 0)
                {
                    started = [bookableProjects.MinBy(p => p.ProductionStartDate)!];
                }

                var blocks = _random.Next(2, 4);
                var shiftHours = (end - start).TotalHours;
                var blockLength = shiftHours / blocks;
                var cursor = start;

                for (var i = 0; i < blocks; i++)
                {
                    var isLast = i == blocks - 1;
                    var finishedAt = isLast ? end : cursor.AddHours(blockLength);

                    details.Add(new WorkLogDetail
                    {
                        WorkLogId = log.Id,
                        UserId = log.UserId,
                        ProjectId = Pick(started).Id,
                        OperationTypeId = Pick(qualifiedOperations),
                        StartedAt = cursor,
                        FinishedAt = finishedAt,
                        Hours = Math.Round((finishedAt - cursor).TotalHours, 2),
                        // Roughly one block in eight carries a note, as on the shop floor.
                        Note = noteRandom.Next(8) == 0 ? SeedNotes[noteRandom.Next(SeedNotes.Length)] : null,
                    });

                    cursor = finishedAt;
                }
            }

            _workLogDetails = details.ToArray();
            await AddRangeAsync(_workLogDetails);
        }

        private static readonly string[] SeedNotes =
        [
            "Waited for material from the warehouse.",
            "Crane was busy, started late.",
            "Rework on two welds after inspection.",
            "Helped with loading the truck.",
            "Grinder disc changed twice - worn batch.",
            "Drawing revision B used.",
            "Finished the remaining brackets.",
            "Measured on site with the foreman.",
        ];

        private Dictionary<int, int[]>? _qualificationCache;

        private async Task<int[]> QualifiedOperationsAsync(int userId)
        {
            _qualificationCache ??= await BuildQualificationCacheAsync();

            return _qualificationCache.TryGetValue(userId, out var operations) && operations.Length > 0
                ? operations
                : _operationTypes.Select(o => o.Id).ToArray();
        }

        private async Task<Dictionary<int, int[]>> BuildQualificationCacheAsync()
        {
            var rows = await _db.UserOperations.ToListAsync();

            return rows
                .GroupBy(x => x.UserId)
                .ToDictionary(g => g.Key, g => g.Select(x => x.OperationTypeId).ToArray());
        }
    }
}
