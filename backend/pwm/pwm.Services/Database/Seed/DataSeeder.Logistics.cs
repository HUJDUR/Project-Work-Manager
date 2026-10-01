namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        private static readonly string[] DriverNames =
        [
            "Senad", "Ivica", "Mladen", "Fahrudin", "Goran", "Nedzad", "Stipe",
            "Zoran", "Alen", "Josip",
        ];

        private static readonly string[] DriverSurnames =
        [
            "Alispahic", "Maric", "Peric", "Salkic", "Juric", "Bajric", "Kovac",
            "Novak", "Horvat", "Delibasic",
        ];

        private static readonly string[] UnloadColors =
        [
            "Red", "Blue", "Green", "Yellow", "Orange", "Purple", "White",
        ];

        private async Task SeedTruckLoadsAsync()
        {
            var loads = new List<TruckLoad>
            {
                CreateTruckLoad("TransBalkan Logistika d.o.o.", "Senad", "Alispahic", "A12-K-345",
                    daysAgo: 13, emptyWeight: 14200, fullWeight: 26650.5, status: "Finished",
                    note: "Loaded through the north gate, customs cleared in Tuzla.",
                    price: 1850.00m),

                CreateTruckLoad("Euro Spedicija d.o.o.", "Ivica", "Maric", "ZG-4417-BK",
                    daysAgo: 5, emptyWeight: 13800, fullWeight: 17620, status: "Delivered",
                    note: null),

                CreateTruckLoad("TransBalkan Logistika d.o.o.", "Mladen", "Peric", "T88-J-902",
                    daysAgo: 2, emptyWeight: 14050, fullWeight: 15690.75, status: "Rejected",
                    note: "Rejected - the customer's dock could not take an oversized load that week."),

                CreateTruckLoad("Euro Spedicija d.o.o.", "Fahrudin", "Salkic", "E31-M-119",
                    daysAgo: 0, emptyWeight: 13950, fullWeight: 16160, status: "Ordered",
                    note: "Waiting for the delivery note to be signed."),
            };

            var carriers = _companies
                .Where(c => c.CompanyTypeId == FindCompanyType("Transport").Id && c.IsActive)
                .ToArray();

            var statuses = new[] { "Ordered", "Delivered", "Finished", "Rejected" };

            for (var i = 0; i < 16; i++)
            {
                var emptyWeight = _random.Next(13500, 14500);
                var status = statuses[i % statuses.Length];

                loads.Add(CreateTruckLoad(
                    Pick(carriers).Name,
                    Pick(DriverNames),
                    Pick(DriverSurnames),
                    $"{(char)('A' + _random.Next(26))}{_random.Next(10, 100)}-{(char)('A' + _random.Next(26))}-{_random.Next(100, 1000)}",
                    daysAgo: _random.Next(1, 60),
                    emptyWeight: emptyWeight,
                    fullWeight: emptyWeight + _random.Next(800, 12000) + Math.Round(_random.NextDouble(), 2),
                    status: status,
                    note: null,
                    // Only a Finished load ever carries an invoice amount - see
                    // TruckLoadStatusRules.CanEditPrice.
                    price: status == "Finished"
                        ? (decimal?)Math.Round(600 + _random.NextDouble() * 2400, 2)
                        : null));
            }

            _truckLoads = loads.ToArray();
            await AddRangeAsync(_truckLoads);

            var details = new List<TruckLoadDetail>
            {
                CreateTruckLoadDetail(0, "Hall roof structure", 12450.5, 12300.0, 1, "Red"),
                CreateTruckLoadDetail(1, "Conveyor frame", 3820.0, 3760.5, 1, "Blue"),
                CreateTruckLoadDetail(2, "Staircase module", 1640.75, 1610.0, 1, "Green"),
                CreateTruckLoadDetail(3, "Machine base plates", 1230.0, 1205.5, 1, "Yellow"),
                CreateTruckLoadDetail(3, "Extraction ducting", 980.25, 962.0, 2, "Orange"),
            };

            // One to three project lines under each generated load
            for (var index = 4; index < _truckLoads.Length; index++)
            {
                var lines = _random.Next(1, 4);

                for (var line = 1; line <= lines; line++)
                {
                    var bruto = Math.Round(_random.Next(200, 9000) + _random.NextDouble(), 2);

                    details.Add(new TruckLoadDetail
                    {
                        TruckLoadId = _truckLoads[index].Id,
                        ProjectId = Pick(_projects).Id,
                        BrutoWeight = bruto,
                        NetoWeight = Math.Round(bruto * 0.98, 2),
                        UnloadPriority = line,
                        UnloadColor = Pick(UnloadColors),
                    });
                }
            }

            await AddRangeAsync(details.ToArray());
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
            string? note,
            decimal? price = null)
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
                Price = price,
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
