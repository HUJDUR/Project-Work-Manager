using System;

namespace pwm.Model.Requests
{
    public class UserOperationUpdateRequest
    {
        public int UserId { get; set; }

        public int OperationTypeId { get; set; }
    }
}
