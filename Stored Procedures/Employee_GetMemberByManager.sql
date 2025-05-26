/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetMemberByManager]
(
    @CompanyId SMALLINT
    ,@supervisorId INT
    ,@excludedManager BIT
    ,@query NVARCHAR(100)
)
AS
/*
	Created: Quinn.Vo@20160129
	Task: Get list of employees by manager
	DB: bodb_HRM

	Revisions:
		2025-04-24@Henry: Merge action type 2, 3, 4, 5
        20250523@Tim: call func get member
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SET @query = @query + '%'

	CREATE TABLE #tblEmployeeIds (EmpId INT)

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT EmpId
	FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 1, @CompanyId)

	SELECT e.EmpId
		,e.NickName
		,e.FullName
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON e.EmpId = tblemp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) ON c.EmpId = e.EmpId
	WHERE (
			e.NickName LIKE @query
			OR e.FullName LIKE @query
			)
		AND c.CompanyId = @CompanyId

	DROP TABLE #tblEmployeeIds
END