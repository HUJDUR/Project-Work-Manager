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
        /// <summary>The office accounts a project can be raised by.</summary>
        private User[] OfficeUsers => _users
            .Where(u => u.UserTypeId != FindUserType("Production worker").Id)
            .ToArray();

        private async Task SeedProjectsAsync()
        {
            var projects = new List<Project>
            {
                CreateProject("Hall roof structure", "MU-2201", "Stahlbau Meyer GmbH", "General steel construction",
                    weight: 12450.5, createdDaysAgo: 96, startedDaysAgo: 88, deliveryInDays: -12,
                    status: "Delivered", carrier: "TransBalkan Logistika d.o.o.",
                    priority: ProjectPriority.High, createdBy: "kenan.fajic@pwm.ba",
                    description: "Primary roof structure for the new production hall, hot-dip galvanised.",
                    notes: "Customer collected the galvanising certificates on delivery."),

                CreateProject("Conveyor frame", "NM-118", "Nordmetall AG", "Sections",
                    weight: 3820.0, createdDaysAgo: 74, startedDaysAgo: 66, deliveryInDays: -4,
                    status: "Delivered", carrier: "Euro Spedicija d.o.o.",
                    priority: ProjectPriority.Medium, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Welded support frame for a belt conveyor, delivered in four sections.",
                    notes: null),

                CreateProject("Staircase module", "WM-45", "Wiener Metallwerke GmbH", "General steel construction",
                    weight: 1640.75, createdDaysAgo: 52, startedDaysAgo: 44, deliveryInDays: 3,
                    status: "In production", carrier: "TransBalkan Logistika d.o.o.",
                    priority: ProjectPriority.VeryHigh, createdBy: "kenan.fajic@pwm.ba",
                    description: "Two-flight staircase with landing and powder-coated handrail.",
                    notes: "Delivery window is tight - the site crane is booked for one morning only."),

                CreateProject("Machine base plates", "AK-77", "Adria Konstrukcije d.o.o.", "Foundations - steel",
                    weight: 2210.0, createdDaysAgo: 40, startedDaysAgo: 31, deliveryInDays: 9,
                    status: "In production", carrier: "Euro Spedicija d.o.o.",
                    priority: ProjectPriority.High, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Machined and drilled base plates for four press foundations.",
                    notes: "Flatness has to be checked before packing."),

                CreateProject("Extraction ducting", "AS-903", "Alpina Systems GmbH", "Heavy ducting - stainless steel",
                    weight: 980.25, createdDaysAgo: 27, startedDaysAgo: 19, deliveryInDays: 16,
                    status: "In production", carrier: null,
                    priority: ProjectPriority.Low, createdBy: "kenan.fajic@pwm.ba",
                    description: "Rolled and welded extraction ducting with flanged joints.",
                    notes: null),

                CreateProject("Platform driptrays", "MU-2311", "Stahlbau Meyer GmbH", "Driptrays - aluminum",
                    weight: 745.5, createdDaysAgo: 18, startedDaysAgo: 10, deliveryInDays: 24,
                    status: "In production", carrier: null,
                    priority: ProjectPriority.Medium, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Folded aluminium driptrays for a maintenance platform.",
                    notes: null),

                CreateProject("Support brackets", "NM-204", "Nordmetall AG", "Sections",
                    weight: 1310.0, createdDaysAgo: 9, startedDaysAgo: 2, deliveryInDays: 33,
                    status: "On hold", carrier: null,
                    priority: ProjectPriority.Medium, createdBy: "kenan.fajic@pwm.ba",
                    description: "Repeat order of welded pipe brackets, same drawing as NM-118.",
                    notes: "On hold until the customer confirms the revised drawing."),

                CreateProject("Silo foundations", "AK-88", "Adria Konstrukcije d.o.o.", "Foundations - steel",
                    weight: 8600.0, createdDaysAgo: 4, startedDaysAgo: 1, deliveryInDays: 47,
                    status: "On hold", carrier: null,
                    priority: ProjectPriority.High, createdBy: "nadir.hujdur@pwm.ba",
                    description: "Anchor cages and base frames for four silo legs.",
                    notes: "Waiting on the customer to confirm the plate grade."),

                CreateProject("Trial batch", "WM-51", "Wiener Metallwerke GmbH", "Driptrays - stainless steel",
                    weight: 320.0, createdDaysAgo: 60, startedDaysAgo: 55, deliveryInDays: -20,
                    status: "Rejected", carrier: null,
                    priority: ProjectPriority.Low, createdBy: "zuhdija.delic@pwm.ba",
                    description: "Sample batch for a facade tender.",
                    notes: "Rejected - the customer did not win the tender."),
            };

            projects.AddRange(RandomProjects(15, startingAt: projects.Count));

            _projects = projects.ToArray();
            await AddRangeAsync(_projects);
        }

        /// <summary>Fills the book out beyond the handful written by hand.</summary>
        private IEnumerable<Project> RandomProjects(int count, int startingAt)
        {
            var customers = _companies
                .Where(c => c.CompanyTypeId == FindCompanyType("Customer").Id)
                .ToArray();

            var carriers = _companies
                .Where(c => c.CompanyTypeId == FindCompanyType("Transport").Id)
                .ToArray();

            var office = OfficeUsers;
            var priorities = Enum.GetValues<ProjectPriority>();
            var statuses = new[] { "Delivered", "In production", "In production", "On hold", "Rejected" };

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
                var createdDaysAgo = _random.Next(6, 110);
                var startedDaysAgo = createdDaysAgo - _random.Next(2, 9);

                yield return new Project
                {
                    Name = subjects[(startingAt + i) % subjects.Length],
                    Code = $"{customer.Name[..2].ToUpperInvariant()}-{2400 + startingAt + i}",
                    Description = null,
                    Notes = null,
                    Priority = Pick(priorities),
                    CustomerId = customer.Id,
                    ProjectCategoryId = Pick(_projectCategories).Id,
                    Weight = Math.Round(_random.Next(200, 14000) + _random.NextDouble(), 2),
                    CreationDate = _today.AddDays(-createdDaysAgo).AddHours(8),
                    ProductionStartDate = _today.AddDays(-startedDaysAgo).AddHours(7),
                    DeliveryDate = _today.AddDays(_random.Next(-30, 60)).AddHours(14),
                    DeliveryCompanyId = _random.Next(3) == 0 ? null : Pick(carriers).Id,
                    ProjectStatusId = FindStatus(status).Id,
                    CreatedByUserId = Pick(office).Id,
                };
            }
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
            var workers = _users
                .Where(u => u.IsActive && u.UserTypeId == FindUserType("Production worker").Id)
                .ToArray();

            // A rejected project never reached the shop floor
            var bookableProjects = _projects
                .Where(p => p.ProjectStatusId != FindStatus("Rejected").Id)
                .ToArray();

            var workLogs = new List<WorkLog>();
            var shifts = new List<(WorkLog Log, DateTime Start, DateTime End)>();

            foreach (var day in WorkingDays(20))
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

            foreach (var (log, start, end) in shifts)
            {
                var qualifiedOperations = await QualifiedOperationsAsync(log.UserId);
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
                        ProjectId = Pick(bookableProjects).Id,
                        OperationTypeId = Pick(qualifiedOperations),
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
