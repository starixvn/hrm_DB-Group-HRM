/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeSupervisor_GetByQuery] @CompanyId SMALLINT
    ,@EmpId INT
	,@Role TINYINT = NULL
	,@RequestType TINYINT = NULL
	,@query NVARCHAR(256) = ''
	,@includeLoginUser BIT = 1
AS
/*
Created: Quinn.Vo@2013/11/11
Task: Get list supervisor
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ShiftManagerRoleId TINYINT = 4
		,@OnBehalfRequestRoleId TINYINT = 5
	DECLARE @q NVARCHAR(258) = '%' + ISNULL(@query, '') + '%'

	CREATE TABLE #tblSupervisors (OwnerId INT)

	INSERT INTO #tblSupervisors (OwnerId)
	SELECT EmpId
	FROM dbo.Employee WITH (NOLOCK)
	WHERE @includeLoginUser = 1
		AND EmpId = @EmpId

	INSERT INTO #tblSupervisors (OwnerId)
	SELECT DISTINCT OwnerId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON es.OwnerId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
	WHERE es.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId
        AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND ISNULL(es.IsDeleted, 0) = 0
		AND es.ActionType IN (@ShiftManagerRoleId, @OnBehalfRequestRoleId)
		AND (
			@Role IS NULL
			OR es.ActionType = @Role
			)
		AND (
			@RequestType IS NULL
			OR es.RequestType = @RequestType
			)
		AND (
			emp.NickName LIKE @q
			OR emp.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblSupervisors AS tbl WITH (NOLOCK)
			WHERE emp.EmpId = tbl.OwnerId
			)

	INSERT INTO #tblSupervisors (OwnerId)
	SELECT DISTINCT emp.EmpId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON es.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
	WHERE es.OwnerId = @EmpId
        AND ce.CompanyId = @CompanyId
		AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND ISNULL(es.IsDeleted, 0) = 0
		AND es.ActionType NOT IN (@ShiftManagerRoleId, @OnBehalfRequestRoleId)
		AND (
			@Role IS NULL
			OR es.ActionType = @Role
			)
		AND (
			@RequestType IS NULL
			OR es.RequestType = @RequestType
			)
		AND (
			emp.NickName LIKE @q
			OR emp.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblSupervisors AS tbl WITH (NOLOCK)
			WHERE emp.EmpId = tbl.OwnerId
			)

	INSERT INTO #tblSupervisors (OwnerId)
	SELECT DISTINCT emp.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
        INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
	WHERE gs.OwnerId = @EmpId
        AND ce.CompanyId = @CompanyId
		AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND ISNULL(gs.IsDeleted, 0) = 0
		AND (
			@Role IS NULL
			OR gs.ActionType = @Role
			)
		AND (
			@RequestType IS NULL
			OR gs.RequestType = @RequestType
			)
		AND (
			emp.NickName LIKE @q
			OR emp.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblSupervisors AS tbl WITH (NOLOCK)
			WHERE emp.EmpId = tbl.OwnerId
			)

	SELECT OwnerId
		,emp.Nickname
		,emp.FullName
		,empsum.IsTopManager
	FROM #tblSupervisors AS tbl
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tbl.OwnerId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
	ORDER BY Nickname

	DROP TABLE #tblSupervisors
END