/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeSupervisor_GetDisciplineSettingById] @EmpId INT,
	@CompanyId INT = NULL
AS
/*
Created: 20160621@Tim.Trinh
Task: Get list supervisor for Employee by EmpId.
DB: HRM_SMS
Original:

Revisions:
	- 20250730@Jay: Add company name for group filter [Redmine: #233324]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT su.OwnerId
		,emp.FullName
		,CASE 
			WHEN @CompanyId IS NOT NULL AND @CompanyId = c.CompanyId THEN emp.NickName
				ELSE emp.NickName + ' (' + ISNULL(c.Name, '') + ')'
			END AS NickName
		,emp.Email
		,c.[Name] AS CompanyName
		,c.CompanyId
		,ISNULL(su.OrderNo, 0) AS OrderNo
		,CASE 
			WHEN @CompanyId IS NOT NULL AND @CompanyId = c.CompanyId THEN 1
			WHEN @CompanyId IS NULL THEN 1 -- group
			ELSE 0
		END AS CanRemove
	FROM [dbo].[EmployeeSupervisor] AS su WITH (NOLOCK)
		INNER JOIN [dbo].Employee AS emp WITH (NOLOCK) ON su.OwnerId = emp.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = su.OwnerId
		LEFT JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE su.EmpId = @EmpId
		AND su.ActionType = 8 -- edit discipline
		AND su.RequestType = 0
		AND ISNULL(su.IsDeleted, 0) = 0
	ORDER BY ISNULL(su.OrderNo, 0)
END
