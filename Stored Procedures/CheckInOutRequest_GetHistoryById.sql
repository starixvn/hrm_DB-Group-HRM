/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_GetHistoryById]
(
    @RequestId BIGINT,
    @CompanyId INT = NULL
)
AS
/*
    Created: Quinn.Vo@20190624
    Task: Get Check In/Out request history by RequestId.
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
		,wk.LogDate AS InsertedDate
		,mis.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN ce.NickName + ' (' + c.[Name]  +')'
				ELSE ce.NickName
		END NickName
		,e.FullName
		,g.GroupId AS TeamId
		,g.Code
		,g.[Name] AS Team
		,vece.EmpId AS VerifierId
		,vece.NickName
		,Ve.FullName
		,apce.EmpId AS ApproverId
		,apce.NickName
		,ap.FullName
		,prce.EmpId AS HRId
		,prce.NickName
		,pr.FullName
		,ISNULL(wk.ModifiedBy, wk.CreatedBy) AS ModifierId
		,CASE WHEN ISNULL(wk.ModifiedBy, wk.CreatedBy) = -1 THEN 'System' ELSE mce.NickName END AS Nickname
		,CASE WHEN ISNULL(wk.ModifiedBy, wk.CreatedBy) = -1 THEN '' ELSE m.FullName END AS FullName
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequestHistory AS mis WITH (NOLOCK) ON wk.HistoryId = mis.HistoryId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = mis.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
        --AND ce.CompanyId = @CompanyId
		INNER JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON mis.OnDate = cl.WorkDate
		AND mis.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = wk.VerifierId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON vece.UserId = ve.UserId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = wk.ApproverId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON apce.UserId = ap.UserId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS prce WITH (NOLOCK) ON prce.EmpId = wk.HRId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON prce.UserId = pr.UserId
		LEFT JOIN dbo.CompanyEmployee AS mce WITH (NOLOCK) ON mce.EmpId = ISNULL(wk.ModifiedBy, wk.CreatedBy)
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON mce.UserId = m.UserId
	WHERE mis.RequestId = @RequestId
	ORDER BY wk.LogDate DESC
END