/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_GetByDate]
(
    @EmpId INT,
    @CompanyId SMALLINT,
    @FromDate DATE,
    @ToDate DATE
)
AS
/*
    Created: Quinn.Vo@20190626
    Task: Get late in/early out request by empId & date range.
    DB: bodb_HRM

    Revisions:
        20250602@Jay: Cross company
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
            INNER JOIN dbo.LateInEarlyOutRequest AS lie WITH (NOLOCK) ON rh.RequestId = lie.RequestId
			LEFT JOIN dbo.CompanyEmployee AS apce_AH WITH (NOLOCK) ON apce_AH.EmpId = rh.ModifiedBy
				AND apce_AH.[Enabled] = 1
            LEFT JOIN dbo.Employee AS ape_AH WITH (NOLOCK) ON ape_AH.UserId = apce_AH.UserId
        WHERE rh.EmpId = @EmpId
    )

	SELECT le.RequestId
		,le.OnDate
		,wk.RequestType AS RequestTypeId
		,le.LateInMins
		,le.EarlyOutMins
		,le.ReasonId
		,wk.Remark
		,le.RefNo
		,CASE 
			WHEN wk.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END AS ActualLateInEarlyOut
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,le.EmpId
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
	FROM dbo.LateInEarlyOutRequest AS le WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON le.RequestId = wk.RequestId
		INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = le.EmpId
			AND ce.EmpId = @EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON le.OnDate = cl.WorkDate
			AND le.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON le.EmpId = att.EmpId
			AND le.OnDate = att.AttendanceDate
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = wk.VerifierId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON vece.UserId = ve.UserId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = wk.ApproverId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON apce.UserId = ap.UserId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.CompanyEmployee prce WITH (NOLOCK) ON prce.EmpId = wk.HRId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON pr.UserId = prce.UserId
		LEFT JOIN tmpRequestHistory AS ap_AH ON wk.RequestId = ap_AH.RequestId AND ap_AH.RowIndex = 1
	WHERE (
			@EmpId IS NULL
			OR le.EmpId = @EmpId
			)
		AND ce.CompanyId = @CompanyId
		AND le.OnDate BETWEEN @FromDate
			AND @ToDate
	ORDER BY wk.CreatedDate DESC
END
