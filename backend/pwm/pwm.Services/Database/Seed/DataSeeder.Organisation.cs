using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

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
                    CityId = FindCity("Munich").Id,
                    Address = "Industriestrasse 14",
                    VAT = "DE811234567",
                    EORI = "DE1234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "Nordmetall AG",
                    CityId = FindCity("Hamburg").Id,
                    Address = "Hafenweg 8",
                    VAT = "DE822345678",
                    EORI = "DE2234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "Wiener Metallwerke GmbH",
                    CityId = FindCity("Vienna").Id,
                    Address = "Ringstrasse 102",
                    VAT = "ATU12345678",
                    EORI = "AT3234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "Adria Konstrukcije d.o.o.",
                    CityId = FindCity("Zagreb").Id,
                    Address = "Slavonska avenija 45",
                    VAT = "HR12345678901",
                    EORI = "HR4234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "Alpina Systems GmbH",
                    CityId = FindCity("Stuttgart").Id,
                    Address = "Weilimdorfer Strasse 61",
                    VAT = "DE833456789",
                    EORI = "DE5234567890123",
                    CompanyTypeId = customer,
                },
                new Company
                {
                    Name = "TransBalkan Logistika d.o.o.",
                    CityId = FindCity("Tuzla").Id,
                    Address = "Magistralni put bb",
                    VAT = "BA200123450001",
                    EORI = "BA6234567890123",
                    CompanyTypeId = transport,
                },
                new Company
                {
                    Name = "Euro Spedicija d.o.o.",
                    CityId = FindCity("Sarajevo").Id,
                    Address = "Rajlovacka cesta 22",
                    VAT = "BA200234560002",
                    EORI = "BA7234567890123",
                    CompanyTypeId = transport,
                },
                new Company
                {
                    Name = "Meyer Baustelle Nord",
                    CityId = FindCity("Hamburg").Id,
                    Address = "Billbrookdeich 210",
                    VAT = "DE844567890",
                    EORI = null,
                    CompanyTypeId = unloadAddress,
                },
                new Company
                {
                    Name = "Nordmetall Montageplatz",
                    CityId = FindCity("Munich").Id,
                    Address = "Lerchenauer Strasse 76",
                    VAT = "DE855678901",
                    EORI = null,
                    CompanyTypeId = unloadAddress,
                },
                new Company
                {
                    Name = "Adria Gradiliste Jug",
                    CityId = FindCity("Ljubljana").Id,
                    Address = "Letaliska cesta 33",
                    VAT = "SI66778899",
                    EORI = null,
                    CompanyTypeId = unloadAddress,
                },
            ];

            await AddRangeAsync(_companies);
        }

        /// <summary>The office, by name; the shop floor below is generated.</summary>
        private static readonly (string Name, string Surname, string Role, string JobTitle)[] NamedStaff =
        [
            // Nadir runs projects as well, but Admin already reaches everything a
            // project manager can, and an account holds exactly one type.
            ("Nadir", "Hujdur", "Admin", "System administrator"),
            ("Nadira", "Stupar", "Finances", "Head of finances"),
            ("Kenan", "Fajic", "Project manager", "Project manager"),
            ("Zuhdija", "Delic", "Project manager", "Project manager"),
            ("Vedad", "Kahrimanovic", "Work preparation", "Work preparation engineer"),
            ("Nevres", "Smajlovic", "Work preparation", "Work preparation engineer"),
            ("Ismail", "Brkic", "Work preparation", "Technical preparation"),
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

        private static readonly string[] ShopFloorTitles =
        [
            "Welder", "CNC operator", "Locksmith", "Painter", "Assembler",
            "Grinder", "Warehouse operator", "Quality controller", "Fitter",
        ];

        private async Task SeedUsersAsync()
        {
            var users = new List<User>();
            var phone = 100;

            foreach (var (name, surname, role, jobTitle) in NamedStaff)
            {
                users.Add(CreateUser(name, surname, Email(name, surname),
                    $"+3876110{phone++}", jobTitle, FindUserType(role).Id));
            }

            var productionWorker = FindUserType("Production worker").Id;
            var taken = new HashSet<string>(users.Select(u => u.Email));

            while (users.Count < NamedStaff.Length + ProductionWorkerCount)
            {
                var name = Pick(WorkerFirstNames);
                var surname = Pick(WorkerSurnames);
                var email = Email(name, surname);

                if (!taken.Add(email))
                {
                    continue;
                }

                users.Add(CreateUser(name, surname, email, $"+3876110{phone++}",
                    Pick(ShopFloorTitles), productionWorker,
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
            string jobTitle,
            int userTypeId,
            bool isActive = true)
        {
            var (hash, salt) = HashPassword(DefaultPassword);

            return new User
            {
                Name = name,
                Surname = surname,
                Email = email,
                PhoneNumber = phoneNumber,
                JobTitle = jobTitle,
                UserTypeId = userTypeId,
                IsActive = isActive,
                PasswordHash = hash,
                PasswordSalt = salt,
            };
        }
    }
}
