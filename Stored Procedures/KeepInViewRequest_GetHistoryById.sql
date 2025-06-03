/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_GetHistoryById] @RequestId INT,
	@CompanyId INT = NULL
AS
/*
Created: Quinn.Vo@20190606
Task: Get Keep In View request history by RequestId.
DB: HRM
Original:

Revisions:
	- Jay.Do: 20250602: Cross company
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
		,wk.Remark
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,wk.LogDate AS InsertedDate
		,kiv.EmpId
		,e.NickName
		,e.FullName
		,g.[Name] AS Team
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
		,m.EmpId AS ModifierId
		,m.NickName
		,m.FullName
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequestHistory AS kiv WITH (NOLOCK) ON wk.HistoryId = kiv.HistoryId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON kiv.EmpId = e.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(wk.ModifiedBy,wk.CreatedBy) = m.EmpId
	WHERE kiv.RequestId = @RequestId
	ORDER BY wk.LogDate DESC
END