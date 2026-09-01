using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        private async Task SeedTruckLoadsAsync()
        {
            _truckLoads =
            [
                CreateTruckLoad("TransBalkan Logistika d.o.o.", "Senad", "Alispahic", "A12-K-345",
                    daysAgo: 13, emptyWeight: 14200, fullWeight: 26650.5, status: "Delivered",
                    note: "Loaded through the north gate, customs cleared in Tuzla."),

                CreateTruckLoad("Euro Spedicija d.o.o.", "Ivica", "Maric", "ZG-4417-BK",
                    daysAgo: 5, emptyWeight: 13800, fullWeight: 17620, status: "Delivered",
                    note: null),

                CreateTruckLoad("TransBalkan Logistika d.o.o.", "Mladen", "Peric", "T88-J-902",
                    daysAgo: 2, emptyWeight: 14050, fullWeight: 15690.75, status: "In transit",
                    note: "Partial load, second truck follows on Monday."),

                CreateTruckLoad("Euro Spedicija d.o.o.", "Fahrudin", "Salkic", "E31-M-119",
                    daysAgo: 0, emptyWeight: 13950, fullWeight: 16160, status: "Loaded",
                    note: "Waiting for the delivery note to be signed."),
            ];

            await AddRangeAsync(_truckLoads);

            var details = new[]
            {
                CreateTruckLoadDetail(0, "Hall roof structure", 12450.5, 12300.0, 1, "Red"),
                CreateTruckLoadDetail(1, "Conveyor frame", 3820.0, 3760.5, 1, "Blue"),
                CreateTruckLoadDetail(2, "Staircase module", 1640.75, 1610.0, 1, "Green"),
                CreateTruckLoadDetail(3, "Machine base plates", 1230.0, 1205.5, 1, "Yellow"),
                CreateTruckLoadDetail(3, "Cladding panels", 980.25, 962.0, 2, "Orange"),
            };

            await AddRangeAsync(details);
        }

        private TruckLoad CreateTruckLoad(
            string transportCompany,
            string driverName,
            string driverSurname,
            string vehicleRegistration,
            int daysAgo,
            double emptyWeight,
            double fullWeight,
            string status,
            string? note)
        {
            return new TruckLoad
            {
                TransportCompanyId = FindCompany(transportCompany).Id,
                TruckLoadStatusId = FindLoadStatus(status).Id,
                LoadDate = _today.AddDays(-daysAgo).AddHours(9),
                DriverName = driverName,
                DriverSurname = driverSurname,
                VehicleRegistration = vehicleRegistration,
                EmptyWeight = emptyWeight,
                FullWeight = fullWeight,
                Note = note,
            };
        }

        private TruckLoadDetail CreateTruckLoadDetail(
            int truckLoadIndex,
            string project,
            double brutoWeight,
            double netoWeight,
            int unloadPriority,
            string unloadColor)
        {
            return new TruckLoadDetail
            {
                TruckLoadId = _truckLoads[truckLoadIndex].Id,
                ProjectId = FindProject(project).Id,
                BrutoWeight = brutoWeight,
                NetoWeight = netoWeight,
                UnloadPriority = unloadPriority,
                UnloadColor = unloadColor,
            };
        }

        private Project FindProject(string name) => _projects.First(x => x.Name == name);
    }
}
