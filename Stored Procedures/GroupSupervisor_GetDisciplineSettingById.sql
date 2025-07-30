/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT su.OwnerId
		,e.NickName
		,e.FullName
		,CASE 
			WHEN @CompanyId IS NOT NULL AND @CompanyId = c.CompanyId THEN 1
			WHEN @CompanyId IS NULL THEN 1 -- group
			ELSE 0
		END AS CanRemove
		,c.CompanyId
		,c.[Name] AS CompanyName
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.OwnerId = e.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE su.GroupId = @TeamId
		AND su.ActionType = 8 -- edit discipline
		AND su.RequestType = 0
		AND ISNULL(su.IsDeleted, 0) = 0
	ORDER BY ISNULL(su.DisplayOrder, 0)
		,e.NickName
END