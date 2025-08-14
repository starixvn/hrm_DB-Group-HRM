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
        20250722@Tim: auto approve request [Redmine: #233324]
        20250813@Jay: change db structure [Redmine: #235678]
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
		,ce.NickName
		,emp.FullName
		,ce.CompanyId
		,ce.AutoApproveRequest
		,vece.EmpId AS VerifierId
		,vece.NickName
		,vece.CompanyId
		,Ve.FullName
		,apce.EmpId AS ApproverId
		,apce.NickName
		,ap.FullName
		,apce.CompanyId
		,prce.EmpId AS HRId
		,prce.NickName
		,pr.FullName
	FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON kiv.RequestId = wk.RequestId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON kiv.EmpId = ce.EmpId
        --AND ce.CompanyId = @CompanyId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON wk.VerifierId = vece.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON vece.UserId = ve.UserId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON wk.ApproverId = apce.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON apce.UserId = ap.UserId
		LEFT JOIN dbo.CompanyEmployee AS prce WITH (NOLOCK) ON wk.HRId = prce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON prce.UserId = pr.UserId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON kiv.EmpId = empca.EmpId
		AND kiv.OnDate = empca.WorkDate
		LEFT JOIN dbo.[Shift] AS shift WITH (NOLOCK) ON empca.ShiftId = shift.ShiftId
	WHERE kiv.RequestId = @RequestId
END
