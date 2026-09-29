using pwm.Model.Access;
using pwm.Services.Business;

namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        /// <summary>
        /// The status history the Project and Transport overviews show. Runs after
        /// projects and loads are stored, so every date it reads is already UTC. Each seeded row
        /// is given the shortest legal path through <see cref="ProjectStatusRules"/> /
        /// <see cref="TruckLoadStatusRules"/> to the status it was seeded in, so the
        /// history reads exactly as if every move had gone through <c>ChangeStatusAsync</c>.
        /// </summary>
        private async Task SeedStatusHistoryAsync()
        {
            // The creation row is whoever raised the record; every later move is one
            // of the two roles ProjectController/TruckLoadController let change status.
            var statusChangers = _users
                .Where(u => u.IsActive
                    && (u.UserTypeId == FindUserType(Roles.Admin).Id
                        || u.UserTypeId == FindUserType(Roles.ProjectManager).Id))
                .ToArray();

            var projectChanges = new List<ProjectStatusChange>();

            foreach (var project in _projects)
            {
                var status = _projectStatuses.First(x => x.Id == project.ProjectStatusId).Name;
                var at = project.CreationDate;
                ProjectStatusType? from = null;

                void Move(string to, int changedBy, DateTime planned)
                {
                    at = Stamp(planned, at);
                    var toStatus = FindStatus(to);

                    projectChanges.Add(new ProjectStatusChange
                    {
                        ProjectId = project.Id,
                        FromStatusId = from?.Id,
                        ToStatusId = toStatus.Id,
                        ChangedByUserId = changedBy,
                        ChangedAt = at,
                    });

                    from = toStatus;
                }

                projectChanges.Add(new ProjectStatusChange
                {
                    ProjectId = project.Id,
                    FromStatusId = null,
                    ToStatusId = FindStatus(ProjectStatusRules.Potential).Id,
                    ChangedByUserId = project.CreatedByUserId,
                    ChangedAt = at,
                });
                from = FindStatus(ProjectStatusRules.Potential);

                if (status == ProjectStatusRules.Potential)
                {
                    continue;
                }

                var started = project.ProductionStartDate ?? at.AddDays(1);
                Move(ProjectStatusRules.InProduction, Pick(statusChangers).Id, started);

                switch (status)
                {
                    case ProjectStatusRules.Delivered:
                        Move(ProjectStatusRules.Delivered, Pick(statusChangers).Id,
                            project.DeliveryDate ?? started.AddDays(14));
                        break;

                    case ProjectStatusRules.OnHold:
                    case ProjectStatusRules.Rejected:
                        // Somewhere between production starting and today.
                        Move(status, Pick(statusChangers).Id,
                            started + (DateTime.UtcNow - started) / 2);
                        break;
                }
            }

            await AddRangeAsync(projectChanges.ToArray());

            var office = OfficeUsers;
            var loadChanges = new List<TruckLoadStatusChange>();

            foreach (var load in _truckLoads)
            {
                var status = _truckLoadStatuses.First(x => x.Id == load.TruckLoadStatusId).Name;
                // A transport is booked a couple of days before the truck is loaded.
                var at = Stamp(load.LoadDate.AddDays(-2), DateTime.MinValue);
                TruckLoadStatusType? from = null;

                void Move(string to, int changedBy, DateTime planned)
                {
                    at = Stamp(planned, at);
                    var toStatus = FindLoadStatus(to);

                    loadChanges.Add(new TruckLoadStatusChange
                    {
                        TruckLoadId = load.Id,
                        FromStatusId = from?.Id,
                        ToStatusId = toStatus.Id,
                        ChangedByUserId = changedBy,
                        ChangedAt = at,
                    });

                    from = toStatus;
                }

                Move(TruckLoadStatusRules.Ordered, Pick(office).Id, at);

                switch (status)
                {
                    case TruckLoadStatusRules.Delivered:
                        Move(TruckLoadStatusRules.Delivered, Pick(statusChangers).Id, load.LoadDate.AddDays(1));
                        break;

                    case TruckLoadStatusRules.Finished:
                        Move(TruckLoadStatusRules.Delivered, Pick(statusChangers).Id, load.LoadDate.AddDays(1));
                        Move(TruckLoadStatusRules.Finished, Pick(statusChangers).Id, load.LoadDate.AddDays(4));
                        break;

                    case TruckLoadStatusRules.Rejected:
                        Move(TruckLoadStatusRules.Rejected, Pick(statusChangers).Id, load.LoadDate);
                        break;
                }
            }

            await AddRangeAsync(loadChanges.ToArray());
        }

        /// <summary>
        /// A planned moment kept after the previous move and never in the future - a
        /// seeded delivery date can lie ahead of today, but a recorded change cannot.
        /// </summary>
        private static DateTime Stamp(DateTime planned, DateTime previous)
        {
            var earliest = previous == DateTime.MinValue ? previous : previous.AddMinutes(1);
            var latest = DateTime.UtcNow;

            if (planned > latest)
            {
                planned = latest;
            }

            return planned < earliest ? earliest : planned;
        }
    }
}
