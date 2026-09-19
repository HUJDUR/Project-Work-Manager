using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface IUserService : IBaseCRUDService<UserResponse, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        /// <summary>Returns the account when the password matches, otherwise null.</summary>
        Task<AuthenticatedUser?> AuthenticateAsync(string email, string password);

        /// <summary>The same shape as <see cref="AuthenticateAsync"/>, for refreshing a token.</summary>
        Task<AuthenticatedUser?> GetAuthenticatedUserAsync(int id);

        /// <summary>
        /// Updates the account identified by <paramref name="userId"/> from the
        /// narrow profile request. The caller passes the id from the token,
        /// never from the route or the body.
        /// </summary>
        Task<UserResponse> UpdateProfileAsync(int userId, UserProfileUpdateRequest request);
    }
}
