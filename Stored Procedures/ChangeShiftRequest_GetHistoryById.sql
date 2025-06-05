/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetHistoryById] @RequestId BIGINT,
	@CompanyId INT = NULL
AS
/*
Created: Tim.Trinh@2019-09-24
Task: view request history
DB: HRM

Revisions:
- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SELECT r.RequestId
		,r.RequestType AS RequestTypeId
		,r.LogDate AS InsertedDate
		,cs.TypeId
		,cs.FromDate
		,cs.ToDate
		,r.Remark
		,r.CurrentStatus
		,r.CreatedDate
		,emp.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN emp.NickName + ' (' + c.[Name]  +')'
				ELSE emp.NickName
		END NickName
		,emp.FullName
		,gr.[Name] AS Team
		,verifier.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN verifier.NickName + ' (' + vec.[Name]  +')'
				ELSE verifier.NickName
		END NickName
		,verifier.FullName
		,approver.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN approver.NickName + ' (' + apc.[Name]  +')'
				ELSE approver.NickName
		END NickName
		,approver.FullName
		,m.EmpId AS ModifierId
		,m.NickName
		,m.FullName
	FROM dbo.WorkingTimeRequestHistory AS r WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
		INNER JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = r.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		INNER JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = r.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = approver.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = r.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(r.ModifiedBy, r.CreatedBy) = m.EmpId
	WHERE r.RequestId = @RequestId
	ORDER BY r.LogDate DESC
END