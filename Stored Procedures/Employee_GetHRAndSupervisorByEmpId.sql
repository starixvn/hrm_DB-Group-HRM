/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetHRAndSupervisorByEmpId] @EmpId INT
AS
/*
    Created: 20221212@Otis
    Task: Get list supervisor and all HR by employee id
    DB: bodb_HRM

    Revisions:
        20250528@Tim: fix bug get HR
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @CompanyId SMALLINT

	CREATE TABLE #tmpSupervisor (OwnerId INT)

    SELECT @CompanyId = CompanyId
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId

	INSERT INTO #tmpSupervisor (OwnerId)
	SELECT DISTINCT es.OwnerId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
	WHERE es.EmpId = @EmpId
		AND es.OwnerId != @EmpId
		AND es.ActionType IN (2, 3) -- verifier, approver
		AND es.IsDeleted = 0

	INSERT INTO #tmpSupervisor (OwnerId)
	SELECT DISTINCT gs.OwnerId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
	WHERE emp.EmpId = @EmpId
		AND gs.OwnerId != @EmpId
		AND gs.ActionType IN (2, 3) -- verifier, approver
		AND gs.IsDeleted = 0
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			WHERE es.OwnerId = gs.OwnerId
				AND es.EmpId = @EmpId
				AND es.ActionType = gs.ActionType
				AND es.IsDeleted = 0
			)

	INSERT INTO #tmpSupervisor (OwnerId)
	SELECT emp.EmpId
	FROM dbo.EmployeeRole AS er WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON er.EmployeeId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
	WHERE ce.CompanyId = @CompanyId
        AND er.RoleId = 6 -- HR
		AND NOT EXISTS (
			SELECT 1
			FROM #tmpSupervisor AS tmp
			WHERE emp.EmpId = tmp.OwnerId
			)

	SELECT OwnerId
		,emp.FullName
		,emp.NickName
		,emp.Email
	FROM #tmpSupervisor AS tmp
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tmp.OwnerId = emp.EmpId
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0

	DROP TABLE #tmpSupervisor
END