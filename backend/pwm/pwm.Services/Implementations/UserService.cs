using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Access;
using pwm.Common.Services.CryptoService;
using pwm.Model.Exceptions;
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
        private readonly IValidator<UserProfileUpdateRequest> _profileValidator;
        private readonly ICryptoService _cryptoService;

        public UserService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<UserInsertRequest> insertValidator,
            IValidator<UserUpdateRequest> updateValidator,
            IValidator<UserProfileUpdateRequest> profileValidator,
            ICryptoService cryptoService)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _profileValidator = profileValidator;
            _cryptoService = cryptoService;
        }

        public async Task<AuthenticatedUser?> AuthenticateAsync(string email, string password)
        {
            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
            {
                return null;
            }

            var user = await _dbContext.Users
                .Include(x => x.UserType)
                .FirstOrDefaultAsync(x => x.Email == email);

            if (user == null || !_cryptoService.Verify(user.PasswordHash, user.PasswordSalt, password))
            {
                return null;
            }

            return ToAuthenticatedUser(user);
        }

        public async Task<AuthenticatedUser?> GetAuthenticatedUserAsync(int id)
        {
            var user = await _dbContext.Users
                .Include(x => x.UserType)
                .FirstOrDefaultAsync(x => x.Id == id);

            return user == null ? null : ToAuthenticatedUser(user);
        }

        private AuthenticatedUser ToAuthenticatedUser(User user) => new()
        {
            User = _mapper.Map<UserResponse>(user),
            Role = user.UserType?.Type ?? string.Empty,
        };

        /// <summary>
        /// A user editing their own account. Neither the role nor the active flag
        /// can be reached from here, and changing the password means proving the
        /// current one first.
        /// </summary>
        public async Task<UserResponse> UpdateProfileAsync(
            int userId, UserProfileUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _profileValidator.ValidateAndThrowAsync(request);

            var user = await _dbContext.Users.FirstOrDefaultAsync(x => x.Id == userId)
                ?? throw new ClinetException("That account no longer exists.");

            var email = request.Email.Trim();
            var taken = await _dbContext.Users
                .AnyAsync(x => x.Id != userId && x.Email == email);
            if (taken)
            {
                throw new ClinetException("Another account already uses that e-mail address.");
            }

            if (!string.IsNullOrEmpty(request.NewPassword))
            {
                var matches = _cryptoService.Verify(
                    user.PasswordHash, user.PasswordSalt, request.CurrentPassword ?? string.Empty);
                if (!matches)
                {
                    throw new ClinetException("Your current password is not right.");
                }

                var salt = _cryptoService.GenerateSalt();
                user.PasswordSalt = salt;
                user.PasswordHash = _cryptoService.GenerateHash(request.NewPassword, salt);
            }

            user.Name = request.Name.Trim();
            user.Surname = request.Surname.Trim();
            user.Email = email;
            user.PhoneNumber = request.PhoneNumber?.Trim();
            user.JobTitle = request.JobTitle?.Trim();

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<UserResponse>(user);
        }

        protected override IEnumerable<User> ApplyFilters(IEnumerable<User> query, UserSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Search))
            {
                var needle = search.Search;
                query = query.Where(x =>
                    x.Name.Contains(needle, StringComparison.OrdinalIgnoreCase)
                    || x.Surname.Contains(needle, StringComparison.OrdinalIgnoreCase)
                    || x.Email.Contains(needle, StringComparison.OrdinalIgnoreCase)
                    || (x.JobTitle != null
                        && x.JobTitle.Contains(needle, StringComparison.OrdinalIgnoreCase)));
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
            var salt = _cryptoService.GenerateSalt();

            entity.PasswordSalt = salt;
            entity.PasswordHash = _cryptoService.GenerateHash(request.Password, salt);

            return entity;
        }

        protected override void MapUpdateRequestToEntity(UserUpdateRequest request, User entity)
        {
            base.MapUpdateRequestToEntity(request, entity);

            if (!string.IsNullOrWhiteSpace(request.Password))
            {
                var salt = _cryptoService.GenerateSalt();

                entity.PasswordSalt = salt;
                entity.PasswordHash = _cryptoService.GenerateHash(request.Password, salt);
            }
        }
    }
}
