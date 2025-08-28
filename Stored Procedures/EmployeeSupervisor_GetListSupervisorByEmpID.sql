/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeSupervisor_GetListSupervisorByEmpID] @EmpId INT
	,@Role TINYINT = NULL
	,@RequestType TINYINT = NULL
AS
/*
Created: TOM.VO@2013/10/25
Task: Get list supervisor for Employee by EmpId.
DB: HRM_SMS
Original: 

Revisions:    
	20250730@Jay: Add company name for personal setting page [Redmine: #233324]
	20250812@Mira: tranfer employee [Redmine: #235678]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	IF @RequestType IS NULL
		SELECT DISTINCT OwnerId AS Id
			,e.FullName
			,ce.NickName
			,ce.Email
			,0 OrderNo
			,isnull(g.GroupID, - 1) AS [TeamId]
			,isnull(g.[Name], '') AS [Team]
			,su.ActionType
			,c.[Name] AS CompanyName
			,c.CompanyId
		FROM [dbo].[EmployeeSupervisor] su WITH (NOLOCK)
			LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = su.OwnerId
			LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId
			LEFT JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
			LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId

		WHERE su.EmpId = @EmpId
			AND (
				@Role IS NULL
				OR su.ActionType = @Role
				)
			AND ISNULL(su.IsDeleted, 0) = 0
			--ORDER BY su.OrderNo
	ELSE
		SELECT DISTINCT OwnerId
			,ee.FullName
			,ce.NickName
			,ce.Email
			,su.OrderNo
			,isnull(g.GroupID, - 1) AS [TeamID]
			,isnull(g.[Name], '') AS [Team]
			,su.ActionType
			,c.[Name] AS CompanyName
			,c.CompanyId
		FROM [dbo].[EmployeeSupervisor] su WITH (NOLOCK)
			LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = su.OwnerId
			LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId
			LEFT JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
			INNER JOIN [dbo].Employee ee WITH (NOLOCK) ON su.OwnerId = ee.UserId
		WHERE su.EmpId = @EmpId
			AND (su.RequestType = @RequestType)
			AND (
				@Role IS NULL
				OR su.ActionType = @Role
				)
			AND ISNULL(su.IsDeleted, 0) = 0
		ORDER BY su.OrderNo
END
