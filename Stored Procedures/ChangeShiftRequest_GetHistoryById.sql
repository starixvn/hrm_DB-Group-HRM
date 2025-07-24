/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetHistoryById]
(
    @RequestId BIGINT,
    @CompanyId INT = NULL
)
AS
/*
    Created: Tim.Trinh@2019-09-24
    Task: view request history
    DB: bodb_HRM

    Revisions:
        20250602@Jay: Cross company
        20250716@Mira: remove company with nick name for employee in different company [#Redmine: 232030]
        20250724@Tim: return system in case auto approve request [Redmine: #233324]
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
		,verifier.NickName
		,verifier.FullName
		,approver.EmpId AS ApproverId
		,approver.NickName
		,approver.FullName
		,ISNULL(r.ModifiedBy, r.CreatedBy) AS ModifierId
		,CASE WHEN ISNULL(r.ModifiedBy, r.CreatedBy) = -1 THEN 'System' ELSE m.NickName END AS Nickname
		,CASE WHEN ISNULL(r.ModifiedBy, r.CreatedBy) = -1 THEN '' ELSE m.FullName END AS FullName
	FROM dbo.WorkingTimeRequestHistory AS r WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = r.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
        AND ce.CompanyId = @CompanyId
		INNER JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = r.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = r.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = approver.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(r.ModifiedBy, r.CreatedBy) = m.EmpId
	WHERE r.RequestId = @RequestId
	ORDER BY r.LogDate DESC
END