namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        private async Task SeedCompaniesAsync()
        {
            var customer = FindCompanyType("Customer").Id;
            var transport = FindCompanyType("Transport").Id;
            var unloadAddress = FindCompanyType("Unload address for customer").Id;

            _companies =
            [
                new Company
                {
                    Name = "Stahlbau Meyer GmbH",
                    CountryId = FindCity("Munich").CountryId,
                    CityId = FindCity("Munich").Id,
                    Address = "Industriestrasse 14",
                    VAT = "DE811234567",
                    EORI = "DE1234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "Nordmetall AG",
                    CountryId = FindCity("Hamburg").CountryId,
                    CityId = FindCity("Hamburg").Id,
                    Address = "Hafenweg 8",
                    VAT = "DE822345678",
                    EORI = "DE2234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "Wiener Metallwerke GmbH",
                    CountryId = FindCity("Vienna").CountryId,
                    CityId = FindCity("Vienna").Id,
                    Address = "Ringstrasse 102",
                    VAT = "ATU12345678",
                    EORI = "AT3234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "Adria Konstrukcije d.o.o.",
                    CountryId = FindCity("Zagreb").CountryId,
                    CityId = FindCity("Zagreb").Id,
                    Address = "Slavonska avenija 45",
                    VAT = "HR12345678901",
                    EORI = "HR4234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "Alpina Systems GmbH",
                    CountryId = FindCity("Stuttgart").CountryId,
                    CityId = FindCity("Stuttgart").Id,
                    Address = "Weilimdorfer Strasse 61",
                    VAT = "DE833456789",
                    EORI = "DE5234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "TransBalkan Logistika d.o.o.",
                    CountryId = FindCity("Tuzla").CountryId,
                    CityId = FindCity("Tuzla").Id,
                    Address = "Magistralni put bb",
                    VAT = "BA200123450001",
                    EORI = "BA6234567890123",
                    CompanyTypeId = transport,
                },
                new Company
                {
                    Name = "Euro Spedicija d.o.o.",
                    CountryId = FindCity("Sarajevo").CountryId,
                    CityId = FindCity("Sarajevo").Id,
                    Address = "Rajlovacka cesta 22",
                    VAT = "BA200234560002",
                    EORI = "BA7234567890123",
                    CompanyTypeId = transport,
                },
                // A carrier the firm no longer works with, to show a deactivated company.
                new Company
                {
                    Name = "Brzi Prevoz d.o.o.",
                    CountryId = FindCity("Sarajevo").CountryId,
                    CityId = FindCity("Sarajevo").Id,
                    Address = "Butmirska cesta 14",
                    VAT = "BA200345670003",
                    EORI = "BA7345678901234",
                    CompanyTypeId = transport,
                    IsActive = false,
                },
                new Company
                {
                    Name = "Meyer Baustelle Nord",
                    CountryId = FindCity("Hamburg").CountryId,
                    CityId = FindCity("Hamburg").Id,
                    Address = "Billbrookdeich 210",
                    VAT = "DE844567890",
                    EORI = null,
                    CompanyTypeId = unloadAddress,
                },
                new Company
                {
                    Name = "Nordmetall Montageplatz",
                    CountryId = FindCity("Munich").CountryId,
                    CityId = FindCity("Munich").Id,
                    Address = "Lerchenauer Strasse 76",
                    VAT = "DE855678901",
                    EORI = null,
                    CompanyTypeId = unloadAddress,
                },
                new Company
                {
                    Name = "Adria Gradiliste Jug",
                    CountryId = FindCity("Ljubljana").CountryId,
                    CityId = FindCity("Ljubljana").Id,
                    Address = "Letaliska cesta 33",
                    VAT = "SI66778899",
                    EORI = null,
                    CompanyTypeId = unloadAddress,
                },
            ];

            await AddRangeAsync(_companies);
        }

        /// <summary>
        /// Where a customer takes delivery, when it is not their own address. The
        /// <c>Unload address for customer</c> companies are sites, and which site
        /// belongs to which customer is not a foreign key anywhere - so the pairing
        /// is stated here, beside the companies it pairs.
        /// </summary>
        private static readonly (string Customer, string Site)[] UnloadSites =
        [
            ("Stahlbau Meyer GmbH", "Meyer Baustelle Nord"),
            ("Nordmetall AG", "Nordmetall Montageplatz"),
            ("Adria Konstrukcije d.o.o.", "Adria Gradiliste Jug"),
        ];

        /// <summary>
        /// The company a project is delivered **to** - the customer's unload site
        /// where they have one, otherwise the customer themselves. This is what
        /// <c>Project.DeliveryCompanyId</c> means; the carrier that hauls it is
        /// <c>TruckLoad.TransportCompanyId</c>, which is a different thing.
        /// </summary>
        private Company DeliveryPlaceFor(Company customer)
        {
            var site = UnloadSites
                .Where(pair => pair.Customer == customer.Name)
                .Select(pair => FindCompany(pair.Site))
                .FirstOrDefault();

            return site ?? customer;
        }

        /// <summary>The office, by name; the shop floor below is generated.</summary>
        private static readonly (string Name, string Surname, string Role)[] NamedStaff =
        [
            // Nadir runs projects as well, but Admin already reaches everything a
            // project manager can, and an account holds exactly one type.
            ("Nadir", "Hujdur", "Admin"),
            ("Nadira", "Stupar", "Finances"),
            ("Kenan", "Fajic", "Project manager"),
            ("Zuhdija", "Delic", "Project manager"),
            ("Vedad", "Kahrimanovic", "Work preparation"),
            ("Nevres", "Smajlovic", "Work preparation"),
            ("Ismail", "Brkic", "Work preparation"),
        ];

        /// <summary>
        /// Fixed logins for grading/testing: the usernames "desktop" and "mobile" the
        /// project checklist expects. One office role and one shop-floor role, so each
        /// is reachable from the app it is named after.
        /// </summary>
        private static readonly (string Name, string Surname, string Role, string Email, string Username)[] DemoAccounts =
        [
            ("Desktop", "", "Admin", "desktop@pwm.ba", "desktop"),
            ("Mobile", "", "Production worker", "mobile@pwm.ba", "mobile"),
        ];

        private const int ProductionWorkerCount = 30;

        private static readonly string[] WorkerFirstNames =
        [
            "Adnan", "Amar", "Amir", "Armin", "Benjamin", "Damir", "Dario", "Denis",
            "Edin", "Elvis", "Emir", "Faruk", "Haris", "Igor", "Jasmin", "Kemal",
            "Mirza", "Muhamed", "Nedim", "Nermin", "Rijad", "Samir", "Sead", "Senad",
            "Tarik", "Vahid", "Zlatan", "Almir", "Bakir", "Dino",
        ];

        private static readonly string[] WorkerSurnames =
        [
            "Alispahic", "Begic", "Causevic", "Cengic", "Dedic", "Duric", "Ferhatovic",
            "Halilovic", "Hodzic", "Imamovic", "Jahic", "Karic", "Kovacevic", "Latic",
            "Mehmedovic", "Mujic", "Muratovic", "Nuhanovic", "Omerovic", "Pasic",
            "Ramic", "Salihovic", "Sarajlic", "Softic", "Suljic", "Tufekcic",
            "Vehabovic", "Zahirovic", "Zulic", "Beganovic",
        ];

        private async Task SeedUsersAsync()
        {
            _pictures = LoadPictures();

            var users = new List<User>();
            var phone = 100;

            foreach (var (name, surname, role) in NamedStaff)
            {
                users.Add(CreateUser(name, surname, Email(name, surname),
                    $"+3876110{phone++}", FindUserType(role).Id));
            }

            foreach (var (name, surname, role, email, username) in DemoAccounts)
            {
                users.Add(CreateUser(name, surname, email,
                    $"+3876110{phone++}", FindUserType(role).Id, username: username));
            }

            var productionWorker = FindUserType("Production worker").Id;
            var taken = new HashSet<string>(users.Select(u => u.Email));

            while (users.Count < NamedStaff.Length + DemoAccounts.Length + ProductionWorkerCount)
            {
                var name = Pick(WorkerFirstNames);
                var surname = Pick(WorkerSurnames);
                var email = Email(name, surname);

                if (!taken.Add(email))
                {
                    continue;
                }

                users.Add(CreateUser(name, surname, email, $"+3876110{phone++}",
                    productionWorker,
                    // Roughly one in ten has left the shop
                    isActive: _random.Next(10) != 0));
            }

            _users = users.ToArray();
            await AddRangeAsync(_users);

            await SeedUserOperationsAsync();
        }

        /// <summary>
        /// Every production worker is qualified for two to five operations; the office
        /// books its time against office work and technical preparation.
        /// </summary>
        private async Task SeedUserOperationsAsync()
        {
            var productionWorker = FindUserType("Production worker").Id;

            var shopFloorOperations = _operationTypes
                .Where(o => o.Name != "Office work")
                .ToArray();

            var officeOperations = new[]
            {
                FindOperation("Office work").Id,
                FindOperation("Technical preparation").Id,
            };

            var qualifications = new List<UserOperation>();

            foreach (var user in _users)
            {
                if (user.UserTypeId != productionWorker)
                {
                    qualifications.AddRange(officeOperations.Select(id => new UserOperation
                    {
                        UserId = user.Id,
                        OperationTypeId = id,
                    }));

                    continue;
                }

                var wanted = _random.Next(2, 6);
                var chosen = new HashSet<int>();

                while (chosen.Count < wanted)
                {
                    chosen.Add(Pick(shopFloorOperations).Id);
                }

                qualifications.AddRange(chosen.Select(id => new UserOperation
                {
                    UserId = user.Id,
                    OperationTypeId = id,
                }));
            }

            await AddRangeAsync(qualifications.ToArray());
        }

        private static string Email(string name, string surname) =>
            $"{name.ToLowerInvariant()}.{surname.ToLowerInvariant()}@pwm.ba";

        private User CreateUser(
            string name,
            string surname,
            string email,
            string phoneNumber,
            int userTypeId,
            bool isActive = true,
            string? username = null)
        {
            var (hash, salt) = HashPassword(DefaultPassword);

            return new User
            {
                Name = name,
                Surname = surname,
                // Name and surname run together - unique here, since the e-mails are.
                Username = username ?? $"{name}{surname}".ToLowerInvariant(),
                Email = email,
                PhoneNumber = phoneNumber,
                Picture = _pictures.Length > 0 ? Pick(_pictures) : null,
                UserTypeId = userTypeId,
                IsActive = isActive,
                PasswordHash = hash,
                PasswordSalt = salt,
            };
        }
    }
}
