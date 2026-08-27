using System;
using System.Collections.Generic;
using System.Linq;
using FluentValidation;
using MapsterMapper;
using pwm.Common.Services.CryptoService;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class UserService
        : BaseCRUDService<User, UserResponse, UserSearchObject, UserInsertRequest, UserUpdateRequest>, IUserService
    {
        private readonly ICryptoService _cryptoService;

        public UserService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<UserInsertRequest> insertValidator,
            IValidator<UserUpdateRequest> updateValidator,
            ICryptoService cryptoService)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _cryptoService = cryptoService;
        }

        protected override IEnumerable<User> ApplyFilters(IEnumerable<User> query, UserSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                var name = search.Name;
                query = query.Where(x => x.Name.Contains(name, StringComparison.OrdinalIgnoreCase));
            }

            if (!string.IsNullOrWhiteSpace(search.Surname))
            {
                var surname = search.Surname;
                query = query.Where(x => x.Surname.Contains(surname, StringComparison.OrdinalIgnoreCase));
            }

            if (!string.IsNullOrWhiteSpace(search.Email))
            {
                var email = search.Email;
                query = query.Where(x => x.Email.Contains(email, StringComparison.OrdinalIgnoreCase));
            }

            if (search.UserTypeId.HasValue)
            {
                query = query.Where(x => x.UserTypeId == search.UserTypeId.Value);
            }

            if (search.IsActive.HasValue)
            {
                query = query.Where(x => x.IsActive == search.IsActive.Value);
            }

            return query;
        }

        // The request carries a plain password, the entity stores hash + salt
        protected override User MapInsertRequestToEntity(UserInsertRequest request)
        {
            var entity = base.MapInsertRequestToEntity(request);
            var salt = _cryptoService.GenerateSlat();

            entity.PasswordSalt = salt;
            entity.PasswordHash = _cryptoService.GenerateHash(request.Password, salt);

            return entity;
        }

        protected override void MapUpdateRequestToEntity(UserUpdateRequest request, User entity)
        {
            base.MapUpdateRequestToEntity(request, entity);

            if (!string.IsNullOrWhiteSpace(request.Password))
            {
                var salt = _cryptoService.GenerateSlat();

                entity.PasswordSalt = salt;
                entity.PasswordHash = _cryptoService.GenerateHash(request.Password, salt);
            }
        }
    }
}
