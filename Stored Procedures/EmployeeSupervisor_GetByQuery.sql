/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeSupervisor_GetByQuery]
(
    @CompanyId SMALLINT
    ,@EmpId INT
    ,@Role TINYINT = NULL
    ,@RequestType TINYINT = NULL
    ,@query NVARCHAR(256) = ''
    ,@includeLoginUser BIT = 1
)
AS
/*
    Created: Quinn.Vo@2013/11/11
    Task: Get list supervisor
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
        20250813@Jay: change db structure [Redmine: #235678]
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
	FROM dbo.CompanyEmployee WITH (NOLOCK)
	WHERE @includeLoginUser = 1
		AND EmpId = @EmpId

	INSERT INTO #tblSupervisors (OwnerId)
	SELECT DISTINCT OwnerId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = es.OwnerId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
	WHERE es.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId
        AND ce.[Enabled] = 1
		AND ce.isDeleted = 0
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
			ce.NickName LIKE @q
			OR emp.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblSupervisors AS tbl WITH (NOLOCK)
			WHERE ce.EmpId = tbl.OwnerId
			)

	INSERT INTO #tblSupervisors (OwnerId)
	SELECT DISTINCT ce.EmpId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
	WHERE es.OwnerId = @EmpId
        AND ce.CompanyId = @CompanyId
		AND ce.[Enabled] = 1
		AND ce.isDeleted = 0
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
			ce.NickName LIKE @q
			OR emp.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblSupervisors AS tbl WITH (NOLOCK)
			WHERE ce.EmpId = tbl.OwnerId
			)

	INSERT INTO #tblSupervisors (OwnerId)
	SELECT DISTINCT ce.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON gs.GroupId = ce.GroupId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
	WHERE gs.OwnerId = @EmpId
        AND ce.CompanyId = @CompanyId
		AND ce.[Enabled] = 1
		AND ce.isDeleted = 0
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
			ce.NickName LIKE @q
			OR emp.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblSupervisors AS tbl WITH (NOLOCK)
			WHERE ce.EmpId = tbl.OwnerId
			)

	SELECT OwnerId
		,ce.Nickname
		,emp.FullName
		,ce.AutoApproveRequest
	FROM #tblSupervisors AS tbl
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON tbl.OwnerId = ce.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
        AND ce.CompanyId = @CompanyId
	ORDER BY Nickname

	DROP TABLE #tblSupervisors
END
