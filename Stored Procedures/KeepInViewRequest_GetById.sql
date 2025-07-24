/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_GetById]
(
    @RequestId INT,
    @CompanyId SMALLINT
)
AS
/*
    Created: Quinn.Vo@20190606
    Task: Get Keep In View request by RequestId.
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT kiv.RequestId
		,kiv.KeepInViewType AS KeepInViewTypeId
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,kiv.IsHalfDay
		,kiv.ShiftId
		,wk.Remark
		,kiv.RefNo
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,shift.[Name] AS ShiftName
		,kiv.EmpId
		,emp.NickName
		,emp.FullName
		,ce.CompanyId
		,ce.AutoApproveRequest
		,ve.EmpId AS VerifierId
		,ve.NickName
		,vece.CompanyId
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,apce.CompanyId
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
	FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON kiv.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON kiv.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        AND ce.CompanyId = @CompanyId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON ve.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON ap.EmpId = apce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON kiv.EmpId = empca.EmpId
		AND kiv.OnDate = empca.WorkDate
		LEFT JOIN dbo.[Shift] AS shift WITH (NOLOCK) ON empca.ShiftId = shift.ShiftId
	WHERE kiv.RequestId = @RequestId
END