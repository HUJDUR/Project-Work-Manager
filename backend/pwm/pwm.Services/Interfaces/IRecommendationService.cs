using System.Threading.Tasks;
using pwm.Model.Requests;
using pwm.Model.Responses;

namespace pwm.Services.Interfaces
{
    /// <summary>
    /// The resource estimator behind the Recommendations screen. Learns a per-work-type
    /// hours-per-tonne relationship from past delivered projects of the same category.
    /// </summary>
    public interface IRecommendationService
    {
        Task<RecommendationResponse> EstimateAsync(RecommendationRequest request);
    }
}
