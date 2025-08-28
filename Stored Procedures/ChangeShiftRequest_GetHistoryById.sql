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
        20250813@Jay: change db structure [Redmine: #235678]
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
		,ce.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN ce.NickName + ' (' + c.[Name]  +')'
				ELSE ce.NickName
		END NickName
		,e.FullName
		,gr.[Name] AS Team
		,vece.EmpId AS VerifierId
		,vece.NickName
		,ve.FullName
		,apce.EmpId AS ApproverId
		,apce.NickName
		,ap.FullName
		,ISNULL(r.ModifiedBy, r.CreatedBy) AS ModifierId
		,CASE WHEN ISNULL(r.ModifiedBy, r.CreatedBy) = -1 THEN 'System' ELSE mce.NickName END AS Nickname
		,CASE WHEN ISNULL(r.ModifiedBy, r.CreatedBy) = -1 THEN '' ELSE m.FullName END AS FullName
	FROM dbo.WorkingTimeRequestHistory AS r WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = r.EmpId
        --AND ce.CompanyId = @CompanyId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = r.VerifierId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON vece.UserId = ve.UserId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = r.ApproverId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON ap.UserId = apce.UserId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS mce WITH (NOLOCK) ON mce.EmpId = ISNULL(r.ModifiedBy, r.CreatedBy)
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON mce.UserId = m.UserId
	WHERE r.RequestId = @RequestId
	ORDER BY r.LogDate DESC
END