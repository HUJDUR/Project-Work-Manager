namespace pwm.Model.Requests
{
    /// <summary>
    /// Common shape of <see cref="ReportTypeInsertRequest"/> and <see cref="ReportTypeUpdateRequest"/>,
    /// which - unlike every other Insert/Update pair in this project - do not share an
    /// inheritance relationship, since only the insert carries <c>Id</c>. Lets their
    /// validators share the one rule that both requests actually have in common.
    /// </summary>
    public interface IReportTypeRequest
    {
        string Description { get; set; }
    }
}
