/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetByDate]
(
    @EmpId INT,    
    @CompanyId SMALLINT,
    @FromDate DATETIME,
    @ToDate DATETIME
)
AS
/*
    Created: Quinn.Vo@20190619
    Task: Get leave request by empId & date range.
    DB: bodb_HRM

    Revisions:
	    20250602@Jay: show company with nick name for employee in different company
	    20250716@Mira: remove company with nick name for employee in different company [#Redmine: 232030]
        20250724@Tim: return system in case auto approve request [Redmine: #233324]
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    WITH tmpRequestHistory AS (
        SELECT ROW_NUMBER() OVER (PARTITION BY rh.RequestId ORDER BY rh.LogDate DESC) AS RowIndex
            ,rh.RequestId
            ,apce_AH.ModifiedBy AS EmpId
            ,CASE WHEN rh.ModifiedBy = -1 THEN 'System' ELSE apce_AH.NickName END AS Nickname
            ,CASE WHEN rh.ModifiedBy = -1 THEN '' ELSE ape_AH.FullName END AS FullName
        FROM dbo.WorkingTimeRequestHistory AS rh WITH (NOLOCK)
            INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON rh.RequestId = lr.RequestId
			LEFT JOIN dbo.CompanyEmployee AS apce_AH WITH (NOLOCK) ON apce_AH.EmpId = rh.ModifiedBy
            LEFT JOIN dbo.Employee AS ape_AH WITH (NOLOCK) ON ape_AH.UserId = apce_AH.UserId
        WHERE rh.EmpId = @EmpId
    )

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
		,ce.NickName
		,e.FullName
		,vece.EmpId AS VerifierId
		,vece.NickName
		,Ve.FullName
		,apce.EmpId AS ApproverId
		,apce.NickName
		,ap.FullName
		,prce.EmpId AS HRId
		,prce.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.Nickname
		,ap_AH.FullName
	FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON lr.RequestId = wk.RequestId
		INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = lr.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lr.LeaveType = lv.LeaveTypeId
			AND lv.CompanyId = @CompanyId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = wk.VerifierId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON vece.UserId = ve.UserId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = wk.ApproverId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON apce.UserId = ap.UserId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.CompanyEmployee prce WITH (NOLOCK) ON prce.EmpId = wk.HRId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON prce.UserId = pr.UserId
        LEFT JOIN tmpRequestHistory AS ap_AH ON lr.RequestId = ap_AH.RequestId AND ap_AH.RowIndex = 1
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