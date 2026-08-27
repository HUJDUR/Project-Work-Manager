using System;

namespace pwm.Model.SearchObjects
{
    public class UserOperationSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }

        public int? OperationTypeId { get; set; }
    }
}
