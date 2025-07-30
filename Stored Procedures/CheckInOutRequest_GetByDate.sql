/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_GetByDate] @EmpId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190624
Task: Get Check In/Out request by empId & date range.
DB: HRM
Original:

Revisions:
	- Jay.Do: 20250602: Cross company
	- Mira@20250716: remove company with nick name for employee in different company [#Redmine: 232030]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT mis.RequestId
		,mis.OnDate
		,wk.RequestType AS RequestTypeId
		,mis.RequestTime
		,mis.ReasonId
		,wk.Remark
		,mis.RefNo
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,mis.EmpId
		,e.NickName
		,e.FullName
		,ve.EmpId AS VerifierId
		,ve.NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.CheckInOutRequest AS mis WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON mis.RequestId = wk.RequestId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON mis.OnDate = cl.WorkDate
		AND mis.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON mis.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = mis.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = mis.RequestId ORDER BY LogDate DESC)
	WHERE (
			@EmpId IS NULL
			OR mis.EmpId = @EmpId
			)
		AND ce.CompanyId = @CompanyId
		AND mis.OnDate BETWEEN @FromDate
			AND @ToDate
	ORDER BY wk.CreatedDate DESC
END