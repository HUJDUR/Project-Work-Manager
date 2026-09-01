using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Enums;

namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        private async Task SeedProjectsAsync()
        {
            _projects =
            [
                CreateProject("Hall roof structure", "MU-2201", "Stahlbau Meyer GmbH", "Steel construction",
                    weight: 12450.5, createdDaysAgo: 96, startedDaysAgo: 88, deliveryInDays: -12,
                    status: "Delivered", carrier: "TransBalkan Logistika d.o.o.",
                    priority: ProjectPriority.High, createdBy: "selma.delic@pwm.ba",
                    description: "Primary roof structure for the new production hall, hot-dip galvanised.",
                    notes: "Customer collected the galvanising certificates on delivery."),

                CreateProject("Conveyor frame", "NM-118", "Nordmetall AG", "Welded assemblies",
                    weight: 3820.0, createdDaysAgo: 74, startedDaysAgo: 66, deliveryInDays: -4,
                    status: "Delivered", carrier: "Euro Spedicija d.o.o.",
                    priority: ProjectPriority.Medium, createdBy: "amar.begic@pwm.ba",
                    description: "Welded support frame for a belt conveyor, delivered in four sections.",
                    notes: null),

                CreateProject("Staircase module", "WM-45", "Wiener Metallwerke GmbH", "Handrails and stairs",
                    weight: 1640.75, createdDaysAgo: 52, startedDaysAgo: 44, deliveryInDays: 3,
                    status: "Ready for delivery", carrier: "TransBalkan Logistika d.o.o.",
                    priority: ProjectPriority.VeryHigh, createdBy: "selma.delic@pwm.ba",
                    description: "Two-flight staircase with landing and powder-coated handrail.",
                    notes: "Delivery window is tight - the site crane is booked for one morning only."),

                CreateProject("Machine base plates", "AK-77", "Adria Konstrukcije d.o.o.", "Machined parts",
                    weight: 2210.0, createdDaysAgo: 40, startedDaysAgo: 31, deliveryInDays: 9,
                    status: "In production", carrier: "Euro Spedicija d.o.o.",
                    priority: ProjectPriority.High, createdBy: "amar.begic@pwm.ba",
                    description: "Machined and drilled base plates for four press foundations.",
                    notes: "Flatness has to be checked before packing."),

                CreateProject("Cladding panels", "AS-903", "Alpina Systems GmbH", "Sheet metal parts",
                    weight: 980.25, createdDaysAgo: 27, startedDaysAgo: 19, deliveryInDays: 16,
                    status: "In production", carrier: null,
                    priority: ProjectPriority.Low, createdBy: "selma.delic@pwm.ba",
                    description: "Folded facade panels in two colours, with fixing rails.",
                    notes: null),

                CreateProject("Platform railing", "MU-2311", "Stahlbau Meyer GmbH", "Handrails and stairs",
                    weight: 745.5, createdDaysAgo: 18, startedDaysAgo: 10, deliveryInDays: 24,
                    status: "In production", carrier: null,
                    priority: ProjectPriority.Medium, createdBy: "amar.begic@pwm.ba",
                    description: "Perimeter railing for a maintenance platform, bolted connections.",
                    notes: null),

                CreateProject("Support brackets", "NM-204", "Nordmetall AG", "Welded assemblies",
                    weight: 1310.0, createdDaysAgo: 9, startedDaysAgo: 2, deliveryInDays: 33,
                    status: "In preparation", carrier: null,
                    priority: ProjectPriority.Medium, createdBy: "selma.delic@pwm.ba",
                    description: "Repeat order of welded pipe brackets, same drawing as NM-118.",
                    notes: "Reuse the NM-118 jigs."),

                CreateProject("Silo segments", "AK-88", "Adria Konstrukcije d.o.o.", "Steel construction",
                    weight: 8600.0, createdDaysAgo: 4, startedDaysAgo: 1, deliveryInDays: 47,
                    status: "New", carrier: null,
                    priority: ProjectPriority.High, createdBy: "admin@pwm.ba",
                    description: "Rolled and welded silo shell segments with stiffening rings.",
                    notes: "Waiting on the customer to confirm the plate grade."),

                CreateProject("Trial batch", "WM-51", "Wiener Metallwerke GmbH", "Sheet metal parts",
                    weight: 320.0, createdDaysAgo: 60, startedDaysAgo: 55, deliveryInDays: -20,
                    status: "Cancelled", carrier: null,
                    priority: ProjectPriority.Low, createdBy: "amar.begic@pwm.ba",
                    description: "Sample batch for a facade tender.",
                    notes: "Cancelled - the customer did not win the tender."),
            ];

            await AddRangeAsync(_projects);
        }

        private Project CreateProject(
            string name,
            string code,
            string customer,
            string category,
            double weight,
            int createdDaysAgo,
            int startedDaysAgo,
            int deliveryInDays,
            string status,
            string? carrier,
            ProjectPriority priority,
            string createdBy,
            string? description,
            string? notes)
        {
            return new Project
            {
                Name = name,
                Code = code,
                Description = description,
                Notes = notes,
                Priority = priority,
                CustomerId = FindCompany(customer).Id,
                ProjectCategoryId = FindCategory(category).Id,
                Weight = weight,
                CreationDate = _today.AddDays(-createdDaysAgo).AddHours(8),
                ProductionStartDate = _today.AddDays(-startedDaysAgo).AddHours(7),
                DeliveryDate = _today.AddDays(deliveryInDays).AddHours(14),
                DeliveryCompanyId = carrier is null ? null : FindCompany(carrier).Id,
                ProjectStatusId = FindStatus(status).Id,
                CreatedByUserId = FindUser(createdBy).Id,
            };
        }

        private async Task SeedWorkLogsAsync()
        {
            // Deterministic, so two seeded databases hold the same numbers
            var random = new Random(20260826);

            var workers = _users
                .Where(u => u.IsActive && u.UserTypeId == FindUserType("Worker").Id)
                .ToArray();

            // Only projects that were actually in production get booked hours
            var bookableProjects = _projects
                .Where(p => p.ProjectStatusId != FindStatus("New").Id
                            && p.ProjectStatusId != FindStatus("Cancelled").Id)
                .ToArray();

            var workLogs = new List<WorkLog>();
            var shifts = new List<(WorkLog Log, DateTime Start, DateTime End)>();

            foreach (var day in WorkingDays(20))
            {
                foreach (var user in workers)
                {
                    // Roughly one absence in every twelve shifts
                    if (random.Next(12) == 0)
                    {
                        continue;
                    }

                    var clockedIn = day.AddHours(7).AddMinutes(random.Next(0, 16));
                    var clockedOut = day.AddHours(15).AddMinutes(30 + random.Next(0, 46));
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

            // Split every shift into two or three booked operations
            var details = new List<WorkLogDetail>();

            foreach (var (log, start, end) in shifts)
            {
                var qualifiedOperations = await QualifiedOperationsAsync(log.UserId);
                var blocks = random.Next(2, 4);
                var shiftHours = (end - start).TotalHours;
                var blockLength = shiftHours / blocks;
                var cursor = start;

                for (var i = 0; i < blocks; i++)
                {
                    var isLast = i == blocks - 1;
                    var finishedAt = isLast ? end : cursor.AddHours(blockLength);
                    var project = bookableProjects[random.Next(bookableProjects.Length)];
                    var operation = qualifiedOperations[random.Next(qualifiedOperations.Length)];

                    details.Add(new WorkLogDetail
                    {
                        WorkLogId = log.Id,
                        ProjectId = project.Id,
                        OperationTypeId = operation,
                        StartedAt = cursor,
                        FinishedAt = finishedAt,
                        Hours = Math.Round((finishedAt - cursor).TotalHours, 2),
                    });

                    cursor = finishedAt;
                }
            }

            _workLogDetails = details.ToArray();
            await AddRangeAsync(_workLogDetails);
        }

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
