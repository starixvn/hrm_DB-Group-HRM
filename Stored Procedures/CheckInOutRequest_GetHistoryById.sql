/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_GetHistoryById] @RequestId BIGINT,
	@CompanyId INT = NULL
AS
/*
Created: Quinn.Vo@20190624
Task: Get Check In/Out request history by RequestId.
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
		,wk.LogDate AS InsertedDate
		,mis.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN e.NickName + ' (' + c.[Name]  +')'
				ELSE e.NickName
		END NickName
		,e.FullName
		,g.GroupId AS TeamId
		,g.Code
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
		,m.EmpId AS ModifierId
		,m.NickName
		,m.FullName
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequestHistory AS mis WITH (NOLOCK) ON wk.HistoryId = mis.HistoryId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON mis.OnDate = cl.WorkDate
		AND mis.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON mis.EmpId = e.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(wk.ModifiedBy,wk.CreatedBy) = m.EmpId
	WHERE mis.RequestId = @RequestId
	ORDER BY wk.LogDate DESC
END