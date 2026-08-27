using System;
using System.Collections.Generic;
using System.Linq;
using FluentValidation;
using MapsterMapper;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class NotificationService
        : BaseReadService<Notification, NotificationResponse, NotificationSearchObject>, INotificationService
    {
        public NotificationService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IEnumerable<Notification> ApplyFilters(IEnumerable<Notification> query, NotificationSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.IsRead.HasValue)
            {
                query = query.Where(x => x.IsRead == search.IsRead.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.Title))
            {
                var title = search.Title;
                query = query.Where(x => x.Title.Contains(title, StringComparison.OrdinalIgnoreCase));
            }

            return query;
        }
    }
}
