/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GroupSupervisor_GetLeaderTakeoverByTeamId] @TeamId INT,	
	@CompanyId INT = NULL
AS
/*
Created: 20251001@Lilac.Nguyen
Task: Get list leader takeover by group id
DB: bodb_HRM
Original:

Revisions:
	20241003@Lilac: Get list leader takeover [Redmine: #240215]
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
		AND su.ActionType = 14 -- edit discipline
		AND su.RequestType = 0
		AND ISNULL(su.IsDeleted, 0) = 0
	ORDER BY ISNULL(su.DisplayOrder, 0) ASC
		,ce.NickName ASC
END
