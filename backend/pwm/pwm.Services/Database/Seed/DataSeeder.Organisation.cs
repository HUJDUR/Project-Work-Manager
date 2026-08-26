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
            var supplier = FindCompanyType("Supplier").Id;

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
                    Name = "Metalprom d.o.o.",
                    CityId = FindCity("Zenica").Id,
                    Address = "Bulevar Kralja Tvrtka 5",
                    VAT = "BA200345670003",
                    EORI = null,
                    CompanyTypeId = supplier,
                },
            ];

            await AddRangeAsync(_companies);
        }

        private async Task SeedUsersAsync()
        {
            var administrator = FindUserType("Administrator").Id;
            var manager = FindUserType("Manager").Id;
            var worker = FindUserType("Worker").Id;

            _users =
            [
                CreateUser("Nadir", "Hujdur", "admin@pwm.ba", "+38761100100", "System administrator", administrator),
                CreateUser("Amar", "Begic", "amar.begic@pwm.ba", "+38761100101", "Production manager", manager),
                CreateUser("Selma", "Delic", "selma.delic@pwm.ba", "+38761100102", "Project manager", manager),
                CreateUser("Emir", "Kovacevic", "emir.kovacevic@pwm.ba", "+38761100103", "Welder", worker),
                CreateUser("Damir", "Softic", "damir.softic@pwm.ba", "+38761100104", "CNC operator", worker),
                CreateUser("Adnan", "Mujic", "adnan.mujic@pwm.ba", "+38761100105", "Locksmith", worker),
                CreateUser("Haris", "Zulic", "haris.zulic@pwm.ba", "+38761100106", "Painter", worker),
                CreateUser("Vedad", "Imamovic", "vedad.imamovic@pwm.ba", "+38761100107", "Assembler", worker),
                CreateUser("Lejla", "Hodzic", "lejla.hodzic@pwm.ba", "+38761100108", "Quality controller", worker),
                CreateUser("Mirza", "Tufekcic", "mirza.tufekcic@pwm.ba", "+38761100109", "Warehouse operator", worker, isActive: false),
            ];

            await AddRangeAsync(_users);

            // Which operations each worker is qualified for
            var qualifications = new Dictionary<string, string[]>
            {
                ["emir.kovacevic@pwm.ba"] = ["Welding", "Grinding", "Assembly"],
                ["damir.softic@pwm.ba"] = ["Cutting", "Bending", "Drilling"],
                ["adnan.mujic@pwm.ba"] = ["Cutting", "Drilling", "Assembly", "Grinding"],
                ["haris.zulic@pwm.ba"] = ["Painting", "Packing"],
                ["vedad.imamovic@pwm.ba"] = ["Assembly", "Welding", "Packing"],
                ["lejla.hodzic@pwm.ba"] = ["Quality control", "Packing"],
                ["mirza.tufekcic@pwm.ba"] = ["Packing"],
            };

            var userOperations = qualifications
                .SelectMany(entry => entry.Value.Select(operation => new UserOperation
                {
                    UserId = FindUser(entry.Key).Id,
                    OperationTypeId = FindOperation(operation).Id,
                }))
                .ToArray();

            await AddRangeAsync(userOperations);
        }

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
