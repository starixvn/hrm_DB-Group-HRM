/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_GetWeekendLeaveSummary]
(
    @CompanyId SMALLINT
    ,@FromDate DATE
    ,@ToDate DATE
    ,@TeamId VARCHAR(MAX) = ''
    ,@EmployeeId INT = NULL
    ,@IsLocal BIT = NULL
    ,@MinTotalLeave INT = NULL
    ,@SupervisorId INT = NULL
)
AS
/*
    Created: 20251013@Tim.Trinh
    Task: get weekend leave summary
    DB: bodb_HRM

    Revisions:
        20251013@Tim: initial
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (GroupId INT)

	IF ISNULL(@TeamId, '') <> ''
	BEGIN
		INSERT INTO #tmpGroup (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamId, ',')
	END

	CREATE TABLE #tmpEmployee (EmpId INT)

	IF @EmployeeId IS NULL
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		SELECT DISTINCT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 0, @CompanyId)
	END
	ELSE
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		VALUES (@EmployeeId)
	END

	CREATE TABLE #tmpWeekendLeaveSummary (EmpId INT, TotalWeekendLeaveDays FLOAT)

	INSERT INTO #tmpWeekendLeaveSummary (EmpId, TotalWeekendLeaveDays)
	SELECT c.EmpId, SUM(c.LeaveDay)
	FROM dbo.EmployeeCalendar as c WITH (NOLOCK)
	INNER JOIN #tmpEmployee AS emp ON c.EmpId = emp.EmpId
	WHERE (DATENAME(DW, c.WorkDate) = 'Saturday' OR DATENAME(DW, c.WorkDate) = 'Sunday')
		and c.IsLeaveDay != 0
		and (c.LeaveTypeId =2 or c.LeaveTypeId = 25 or c.LeaveTypeId2 = 2 or c.LeaveTypeId2 = 25)
		and c.WorkDate between @FromDate and @ToDate
	GROUP BY c.EmpId

	SELECT 
		ce.EmpId AS EmployeeId
		,ce.Nickname
		,emp.FullName
		,ce.Code
		,es.IsLocal
		,wl.TotalWeekendLeaveDays as TotalWeekendLeave
		,gr.GroupId AS TeamId
		,gr.[Name] AS TeamName
		,gr.Code AS TeamCode
	FROM dbo.Employee AS emp WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.UserId = ce.UserId
		INNER JOIN #tmpWeekendLeaveSummary AS wl WITH (NOLOCK) ON wl.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON es.EmpId = ce.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
	WHERE ce.[Enabled] = 1
		AND wl.TotalWeekendLeaveDays >= @MinTotalLeave
		AND ce.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tmpGroup AS tbl WITH (NOLOCK)
			WHERE ce.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR ce.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR es.IsLocal = @IsLocal)
	ORDER BY gr.[Name] ASC
		,ce.Code ASC

	DROP TABLE #tmpWeekendLeaveSummary

	DROP TABLE #tmpGroup

    DROP TABLE #tmpEmployee
END