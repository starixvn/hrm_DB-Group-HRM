/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetById]
(
    @RequestId BIGINT,
    @CompanyId SMALLINT
)
AS
/*
    Created: Quinn.Vo@20190617
    Task: Get Leave request by RequestId.
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT lr.RequestId
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,hl.IsHospitalApplication
		,wk.Remark
		,lr.RefNo
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,lr.LeaveType AS LeaveTypeId
		,lv.[Name]
		,lr.EmpId
		,ce.NickName
		,e.FullName
		,ce.CompanyId
		,ce.AutoApproveRequest
		,vece.EmpId AS VerifierId
		,vece.NickName
		,Ve.FullName
		,vece.CompanyId
		,apce.EmpId AS ApproverId
		,apce.NickName
		,ap.FullName
		,apce.CompanyId
		,prce.EmpId AS HRId
		,prce.NickName
		,pr.FullName
	FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON lr.RequestId = wk.RequestId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = lr.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
        --AND ce.CompanyId = @CompanyId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lr.LeaveType = lv.LeaveTypeId
        AND lv.CompanyId = @CompanyId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON wk.VerifierId = vece.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON vece.UserId = vece.UserId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON wk.ApproverId = apce.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON apce.UserId = ap.UserId
		LEFT JOIN dbo.CompanyEmployee AS prce WITH (NOLOCK) ON wk.HRId = prce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON prce.UserId = pr.UserId
		LEFT JOIN dbo.HospitalLeave AS hl WITH (NOLOCK) ON hl.RequestId = lr.RequestId
	WHERE lr.RequestId = @RequestId

	SELECT ldt.RequestId
		,ldt.OnDate
		,ldt.WorkType
		,ldt.LeaveType AS LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,ldt.IsHalfDay
		,ldt.FromTime
		,ldt.ToTime
	FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON ldt.LeaveType = lv.LeaveTypeId
	WHERE ldt.RequestId = @RequestId
        AND lv.CompanyId = @CompanyId
END
