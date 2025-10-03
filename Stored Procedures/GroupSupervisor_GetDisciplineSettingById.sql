/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GroupSupervisor_GetDisciplineSettingById] @TeamId INT,	
	@CompanyId INT = NULL
AS
/*
Created: 20160620@Tim.Trinh
Task: Get list supervisors by group id
DB: SMSHRM
Original:

Revisions:
	- 20250730@Jay: Add company name for personal setting page [Redmine: #233324]
	- 20250812@Mira: tranfer employee [Redmine: #235678]
	- 20241003@Lilac: add nickname (company name)
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT su.OwnerId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND @CompanyId = c.CompanyId THEN ce.NickName
			ELSE ce.NickName + ' (' + ISNULL(c.Name, '') + ')'
		END AS NickName
		,e.FullName
		,CASE 
			WHEN @CompanyId IS NOT NULL AND @CompanyId = c.CompanyId THEN 1
			WHEN @CompanyId IS NULL THEN 1 -- group
			ELSE 0
		END AS CanRemove
		,c.CompanyId
		,c.[Name] AS CompanyName
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON su.OwnerId = ce.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE su.GroupId = @TeamId
		AND su.ActionType = 8 -- edit discipline
		AND su.RequestType = 0
		AND ISNULL(su.IsDeleted, 0) = 0
	ORDER BY ISNULL(su.DisplayOrder, 0)
		,ce.NickName
END