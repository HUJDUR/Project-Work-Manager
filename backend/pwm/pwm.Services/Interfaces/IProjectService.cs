using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface IProjectService : IBaseCRUDService<ProjectResponse, ProjectSearchObject, ProjectInsertRequest, ProjectUpdateRequest>
    {
        Task<ProjectResponse> ChangeStatusAsync(int id, int newStatusId, string? reason, int changedByUserId);

        Task<List<ProjectStatusChangeResponse>> GetStatusHistoryAsync(int projectId);
    }
}
