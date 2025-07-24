/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_GetHistoryById]
(
    @RequestId BIGINT,
    @CompanyId INT = NULL
)
AS
/*
    Created: Quinn.Vo@20190626
    Task: Get late in/early out request history by RequestId.
    DB: bodb_HRM

    Revisions:
        20250602@Jay: Cross company
        20250716@Mira: remove company with nick name for employee in different company [#Redmine: 232030]
        20250724@Tim: return system in case auto approve request [Redmine: #233324]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

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
		,wk.LogDate AS InsertedDate
		,le.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN e.NickName + ' (' + c.[Name]  +')'
				ELSE e.NickName
		END NickName
		,e.FullName
		,g.[Name] AS Team
		,ve.EmpId AS VerifierId
		,ve.NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ISNULL(wk.ModifiedBy, wk.CreatedBy) AS ModifierId
		,CASE WHEN ISNULL(wk.ModifiedBy, wk.CreatedBy) = -1 THEN 'System' ELSE m.NickName END AS Nickname
		,CASE WHEN ISNULL(wk.ModifiedBy, wk.CreatedBy) = -1 THEN '' ELSE m.FullName END AS FullName
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.LateInEarlyOutRequestHistory AS le WITH (NOLOCK) ON wk.HistoryId = le.HistoryId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON le.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		INNER JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON le.OnDate = cl.WorkDate
		AND le.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON le.EmpId = att.EmpId
		AND le.OnDate = att.AttendanceDate
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(wk.ModifiedBy, wk.CreatedBy) = m.EmpId
	WHERE le.RequestId = @RequestId
	ORDER BY wk.LogDate DESC
END