/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_GetById] 
	@RequestId INT,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190624
Task: Get Check in/out request by RequestId.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT cio.RequestId
		,cio.OnDate
		,wk.RequestType AS RequestTypeId
		,cio.RequestTime
		,cio.ReasonId
		,wk.Remark
		,cio.RefNo
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,cio.EmpId
		,emp.NickName
		,emp.FullName
		,ce.CompanyId
		,empsum.IsTopManager
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
	FROM dbo.CheckInOutRequest AS cio WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON cio.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON cio.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON cio.OnDate = empca.WorkDate
		AND cio.EmpId = empca.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = cio.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON empca.ShiftId = sh.ShiftId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON ve.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON ap.EmpId = apce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
	WHERE cio.RequestId = @RequestId
END