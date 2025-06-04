/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetVerifierAndApprover] @EmpId INT
	,@RequestType TINYINT
	,@CompanyId INT = NULL
AS
/*
Created: 20160609@Quinn.Vo
Task: Get list verifier and approver for employee when create/edit request.
DB: HRM
Original:

Revisions:
	- Jay.Do@20250602: show company with nick name for employee in different company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Verifiers TABLE (OwnerId INT)
	DECLARE @Approvers TABLE (OwnerId INT)

	INSERT INTO @Verifiers (OwnerId)
	SELECT DISTINCT OwnerId
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
	WHERE su.EmpId = @EmpId
		AND (
			@RequestType IS NULL
			OR su.RequestType = @RequestType
			)
		AND su.ActionType = 2
		AND su.IsDeleted = 0

	INSERT INTO @Verifiers (OwnerId)
	SELECT DISTINCT su.OwnerId
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.GroupId = e.GroupId
	WHERE e.EmpId = @EmpId
		AND (
			@RequestType IS NULL
			OR su.RequestType = @RequestType
			)
		AND su.ActionType = 2
		AND su.IsDeleted = 0

	INSERT INTO @Approvers (OwnerId)
	SELECT DISTINCT OwnerId
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
	WHERE su.EmpId = @EmpId
		AND (
			@RequestType IS NULL
			OR su.RequestType = @RequestType
			)
		AND su.ActionType = 3
		AND su.IsDeleted = 0

	INSERT INTO @Approvers (OwnerId)
	SELECT DISTINCT su.OwnerId
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.GroupId = e.GroupId
	WHERE e.EmpId = @EmpId
		AND (
			@RequestType IS NULL
			OR su.RequestType = @RequestType
			)
		AND su.ActionType = 3
		AND su.IsDeleted = 0

	SELECT DISTINCT OwnerId
		,ee.FullName
		 ,CASE 
		 	WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
		 		THEN ee.NickName + ' (' + c.[Name]  +')'
		 		ELSE ee.NickName
		 END NickName
		,ee.Email
	FROM @Verifiers AS su
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON su.OwnerId = ee.EmpId
		 INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId
		 INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId

	SELECT DISTINCT OwnerId
		,ee.FullName
		 ,CASE 
		 	WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
		 		THEN ee.NickName + ' (' + c.[Name]  +')'
		 		ELSE ee.NickName
		 END NickName
		,ee.Email
	FROM @Approvers AS su
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON su.OwnerId = ee.EmpId
		 INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId
		 INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
END