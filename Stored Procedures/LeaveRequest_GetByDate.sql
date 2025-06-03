/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetByDate] @EmpId INT,
	@FromDate DATETIME,
	@ToDate DATETIME,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190619
Task: Get leave request by empId & date range.
DB: HRM
Original:

Revisions:
	- Jay.Do@20250602: show company with nick name for employee in different company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT lr.RequestId
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,wk.Remark
		,lr.RefNo
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,wk.VerifiedStatus
		,wk.ApprovedStatus
		,wk.HRStatus AS ProcessedStatus
		,lr.LeaveType AS LeaveTypeId
		,lv.[Name]
		,lr.EmpId
		,e.NickName
		,e.FullName
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON lr.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON lr.EmpId = e.EmpId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lr.LeaveType = lv.LeaveTypeId
		AND lv.CompanyId = @CompanyId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = lr.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = lr.RequestId ORDER BY LogDate DESC)
	WHERE lr.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId
		AND (
			(
				lr.FromDate >= @fromdate
				AND lr.FromDate <= @todate
				AND lr.ToDate >= @todate
				)
			OR (
				lr.FromDate <= @fromdate
				AND lr.ToDate >= @todate
				)
			OR (
				lr.ToDate >= @fromdate
				AND lr.ToDate <= @todate
				)
			)
	ORDER BY wk.CreatedDate DESC

	SELECT ldt.RequestId
		,ldt.OnDate
		,ldt.WorkType
		,ldt.LeaveType AS LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,ldt.IsHalfDay
		,ldt.FromTime
		,ldt.ToTime
	FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON ldt.LeaveType = lv.LeaveTypeId
		AND lv.CompanyId = @CompanyId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ldt.EmpId
	WHERE lr.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId
		AND (
			(
				lr.FromDate >= @fromdate
				AND lr.FromDate <= @todate
				AND lr.ToDate >= @todate
				)
			OR (
				lr.FromDate <= @fromdate
				AND lr.ToDate >= @todate
				)
			OR (
				lr.ToDate >= @fromdate
				AND lr.ToDate <= @todate
				)
			)
END