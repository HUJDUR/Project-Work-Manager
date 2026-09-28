using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface IUserService : IBaseCRUDService<UserResponse, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        /// <summary>
        /// Returns the account when <paramref name="emailOrUsername"/> matches its e-mail or
        /// its name+surname username and the password matches, otherwise null.
        /// </summary>
        Task<AuthenticatedUser?> AuthenticateAsync(string emailOrUsername, string password);

        /// <summary>The same shape as <see cref="AuthenticateAsync"/>, for refreshing a token.</summary>
        Task<AuthenticatedUser?> GetAuthenticatedUserAsync(int id);

        /// <summary>
        /// The same lookup <see cref="AuthenticateAsync"/> does, minus the password check -
        /// for "Reset password", where there is no password to check. Null when nothing
        /// matches; the caller must not let that difference reach the client; see
        /// <c>AccessManager.RequestPasswordResetAsync</c>.
        /// </summary>
        Task<UserResponse?> FindByEmailOrUsernameAsync(string emailOrUsername);

        /// <summary>
        /// Updates the account identified by <paramref name="userId"/> from the
        /// narrow profile request. The caller passes the id from the token,
        /// never from the route or the body.
        /// </summary>
        Task<UserResponse> UpdateProfileAsync(int userId, UserProfileUpdateRequest request);

        /// <summary>
        /// The value every access token this user currently holds should carry - null
        /// when the account no longer exists. Checked on every authenticated request
        /// (<c>OnTokenValidated</c> in <c>Program.cs</c>), so this is cached rather than
        /// read from the database each time; <see cref="RevokeTokensAsync"/> is what
        /// drops that cache entry.
        /// </summary>
        Task<int?> GetTokenVersionAsync(int userId);

        /// <summary>
        /// Bumps the account's token version, which immediately invalidates every
        /// access token already issued to it - see <see cref="GetTokenVersionAsync"/>.
        /// Called on logout, alongside deleting the refresh token.
        /// </summary>
        Task RevokeTokensAsync(int userId);
    }
}
