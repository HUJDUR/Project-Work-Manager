using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
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
        private readonly IMemoryCache _cache;
        private readonly IActivityLogService _activityLogService;
        private readonly ICurrentUser _currentUser;

        public UserService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<UserInsertRequest> insertValidator,
            IValidator<UserUpdateRequest> updateValidator,
            IValidator<UserProfileUpdateRequest> profileValidator,
            ICryptoService cryptoService,
            IMemoryCache cache,
            IActivityLogService activityLogService,
            ICurrentUser currentUser)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _activityLogService = activityLogService;
            _currentUser = currentUser;
            _profileValidator = profileValidator;
            _cryptoService = cryptoService;
            _cache = cache;
        }

        public async Task<AuthenticatedUser?> AuthenticateAsync(string emailOrUsername, string password)
        {
            if (string.IsNullOrWhiteSpace(emailOrUsername) || string.IsNullOrWhiteSpace(password))
            {
                return null;
            }

            var user = await _dbContext.Users
                .Include(x => x.UserType)
                .FirstOrDefaultAsync(MatchesLogin(emailOrUsername));

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

        public async Task<UserResponse?> FindByEmailOrUsernameAsync(string emailOrUsername)
        {
            if (string.IsNullOrWhiteSpace(emailOrUsername))
            {
                return null;
            }

            var user = await _dbContext.Users.FirstOrDefaultAsync(MatchesLogin(emailOrUsername));

            return user == null ? null : _mapper.Map<UserResponse>(user);
        }

        /// <summary>
        /// The one account an e-mail or username names - both are unique, so this
        /// can never pick one of two people who share a name.
        /// </summary>
        private static System.Linq.Expressions.Expression<Func<User, bool>> MatchesLogin(string emailOrUsername)
        {
            var login = emailOrUsername.Trim().ToLower();
            return x => x.Email.ToLower() == login || x.Username.ToLower() == login;
        }

        private AuthenticatedUser ToAuthenticatedUser(User user) => new()
        {
            User = _mapper.Map<UserResponse>(user),
            Role = user.UserType?.Type ?? string.Empty,
            TokenVersion = user.TokenVersion,
        };

        private static string TokenVersionCacheKey(int userId) => $"user-token-version:{userId}";

        public async Task<int?> GetTokenVersionAsync(int userId)
        {
            var key = TokenVersionCacheKey(userId);

            if (_cache.TryGetValue(key, out int cached))
            {
                return cached;
            }

            var version = await _dbContext.Users
                .Where(x => x.Id == userId)
                .Select(x => (int?)x.TokenVersion)
                .FirstOrDefaultAsync();

            if (version.HasValue)
            {
                // Same five-minute safety-net window CachedLookupService uses - the
                // normal way a change here is seen is immediate, via SignOutAsync
                // dropping this entry, not this expiry.
                _cache.Set(key, version.Value, TimeSpan.FromMinutes(5));
            }

            return version;
        }

        public async Task SignOutAsync(int userId)
        {
            var user = await _dbContext.Users.FirstOrDefaultAsync(x => x.Id == userId);
            if (user is null)
            {
                return;
            }

            var tokens = await _dbContext.RefreshTokens.Where(x => x.UserId == userId).ToListAsync();
            _dbContext.RefreshTokens.RemoveRange(tokens);

            user.TokenVersion++;

            // Tracked on the same context, not saved yet - see RecordAsync's doc.
            await _activityLogService.RecordAsync(userId, ActivityLogTypeNames.LogOut);

            await _dbContext.SaveChangesAsync();

            _cache.Remove(TokenVersionCacheKey(userId));
        }

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
                ?? throw new ClientException("That account no longer exists.");

            var email = request.Email.Trim();
            await EnsureEmailFreeAsync(email, userId);

            if (!string.IsNullOrEmpty(request.NewPassword))
            {
                var matches = _cryptoService.Verify(
                    user.PasswordHash, user.PasswordSalt, request.CurrentPassword ?? string.Empty);
                if (!matches)
                {
                    throw new ClientException("Your current password is not right.");
                }

                var salt = _cryptoService.GenerateSalt();
                user.PasswordSalt = salt;
                user.PasswordHash = _cryptoService.GenerateHash(request.NewPassword, salt);
            }

            user.Name = request.Name.Trim();
            user.Surname = request.Surname.Trim();
            user.Email = email;
            user.PhoneNumber = request.PhoneNumber?.Trim();
            user.Picture = request.Picture;

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<UserResponse>(user);
        }

        // The unique indexes on Email and Username would otherwise surface as a bare 500.
        public override async Task<UserResponse> InsertAsync(UserInsertRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _insertValidator.ValidateAndThrowAsync(request);
            await EnsureEmailFreeAsync(request.Email.Trim(), exceptUserId: null);
            await EnsureUsernameFreeAsync(request.Username.Trim(), exceptUserId: null);
            return await base.InsertAsync(request);
        }

        public override async Task<UserResponse> UpdateAsync(int id, UserUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _updateValidator.ValidateAndThrowAsync(request);
            await EnsureEmailFreeAsync(request.Email.Trim(), exceptUserId: id);
            await EnsureUsernameFreeAsync(request.Username.Trim(), exceptUserId: id);
            return await base.UpdateAsync(id, request);
        }

        /// <summary>
        /// Reported against the field, like any other validation error, so the form
        /// can show it under the username box.
        /// </summary>
        private async Task EnsureUsernameFreeAsync(string username, int? exceptUserId)
        {
            var taken = await _dbContext.Users
                .AnyAsync(x => x.Id != exceptUserId && x.Username == username);

            if (taken)
            {
                throw new ValidationException(
                [
                    new FluentValidation.Results.ValidationFailure(
                        nameof(UserInsertRequest.Username), "That username is taken - pick another one."),
                ]);
            }
        }

        private async Task EnsureEmailFreeAsync(string email, int? exceptUserId)
        {
            var taken = await _dbContext.Users
                .AnyAsync(x => x.Id != exceptUserId && x.Email == email);

            if (taken)
            {
                throw new ClientException("Another account already uses that e-mail address.");
            }
        }

        /// <summary>
        /// Lists never carry the picture - up to 5 MB each - and do not read the
        /// column at all. <c>GET /User/{id}</c>, sign-in and <c>PUT /User/Me</c>
        /// return it for the one account they are about.
        /// </summary>
        protected override IQueryable<UserResponse> ProjectForList(IQueryable<User> query) =>
            query.Select(x => new UserResponse
            {
                Id = x.Id,
                Name = x.Name,
                Surname = x.Surname,
                Username = x.Username,
                PhoneNumber = x.PhoneNumber,
                Email = x.Email,
                UserTypeId = x.UserTypeId,
                IsActive = x.IsActive,
            });

        /// <summary>A production worker reads only their own account; the office anyone's.</summary>
        public override async Task<UserResponse> GetByIdAsync(int id)
        {
            if (_currentUser.IsWorker && id != _currentUser.Id)
            {
                throw new NotFoundException($"User with id {id} not found.");
            }

            return await base.GetByIdAsync(id);
        }

        protected override IQueryable<User> ApplyFilters(IQueryable<User> query, UserSearchObject? search)
        {
            // The shop floor has no business with the staff list - e-mails, phone
            // numbers - so a worker's list is only ever their own account.
            if (_currentUser.IsWorker)
            {
                var me = _currentUser.Id ?? throw new ForbiddenException("The token carries no user.");
                query = query.Where(x => x.Id == me);
            }

            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Search))
            {
                var needle = search.Search;
                query = query.Where(x =>
                    EF.Functions.Like(x.Name, $"%{needle}%")
                    || EF.Functions.Like(x.Surname, $"%{needle}%")
                    || EF.Functions.Like(x.Username, $"%{needle}%")
                    || EF.Functions.Like(x.Email, $"%{needle}%"));
            }

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                var name = search.Name;
                query = query.Where(x => EF.Functions.Like(x.Name, $"%{name}%"));
            }

            if (!string.IsNullOrWhiteSpace(search.Surname))
            {
                var surname = search.Surname;
                query = query.Where(x => EF.Functions.Like(x.Surname, $"%{surname}%"));
            }

            if (!string.IsNullOrWhiteSpace(search.Email))
            {
                var email = search.Email;
                query = query.Where(x => EF.Functions.Like(x.Email, $"%{email}%"));
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
            entity.Username = request.Username.Trim();
            var salt = _cryptoService.GenerateSalt();

            entity.PasswordSalt = salt;
            entity.PasswordHash = _cryptoService.GenerateHash(request.Password, salt);

            return entity;
        }

        protected override void MapUpdateRequestToEntity(UserUpdateRequest request, User entity)
        {
            base.MapUpdateRequestToEntity(request, entity);
            entity.Username = request.Username.Trim();

            if (!string.IsNullOrWhiteSpace(request.Password))
            {
                var salt = _cryptoService.GenerateSalt();

                entity.PasswordSalt = salt;
                entity.PasswordHash = _cryptoService.GenerateHash(request.Password, salt);
            }
        }
    }
}
