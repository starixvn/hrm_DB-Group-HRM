/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_GetWeekendLeaveDetail]
(
    @CompanyId SMALLINT
    ,@FromDate DATE
	,@ToDate DATE
	,@TeamId VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@IsLocal BIT = NULL
	,@LeaveTypeId INT = NULL
	,@SupervisorId INT = NULL
)
AS
/*
    Created: 20251013@Tim.Trinh
    Task: get weekend leave detail
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
		FROM [dbo].[fnc_GetEmployeeByActorId](@SupervisorId, 1, 0, @CompanyId)
	END
	ELSE
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		VALUES (@EmployeeId)
	END

	-- half day
	SELECT EmployeeId
		,Nickname
		,FullName
		,Code
		,IsLocal
		,GroupId AS TeamId
		,GroupName AS TeamName
		,GroupCode AS TeamCode
		,LeaveDate
		,LeaveTypeId
		,LeaveType
		,LeaveDay
		,Remark
		,ApproverComment
	FROM (
		SELECT ce.EmpId AS EmployeeId
			,ce.Nickname
			,emp.FullName
			,ce.Code
			,empSum.IsLocal
			,gr.GroupId
			,gr.[Name] AS GroupName
			,gr.Code AS GroupCode
			,empC.WorkDate AS LeaveDate
			,ISNULL(empC.LeaveTypeId, empC.LeaveTypeId2) AS LeaveTypeId
			,lt.[Name] AS LeaveType
			,empC.LeaveDay
			,STUFF((
					SELECT ', ' + rq.Remark
					FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
						INNER JOIN [dbo].[WorkingTimeRequest] AS rq WITH (NOLOCK) ON ldt.[RequestId] = rq.[RequestId]
					WHERE ldt.EmpId = ce.EmpId
						AND ldt.OnDate = empC.WorkDate
						AND rq.CurrentStatus IN (4, 6)
					FOR XML PATH('')
					), 1, 1, '') AS Remark
			,STUFF((
					SELECT ', ' + rq.ApproverComment
					FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
						INNER JOIN [dbo].[WorkingTimeRequest] AS rq WITH (NOLOCK) ON ldt.[RequestId] = rq.[RequestId]
					WHERE ldt.EmpId = ce.EmpId
						AND ldt.OnDate = empC.WorkDate
						AND rq.CurrentStatus IN (4, 6)
					FOR XML PATH('')
					), 1, 1, '') AS ApproverComment
		FROM dbo.Employee AS emp WITH (NOLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.UserId = ce.UserId
			INNER JOIN #tmpEmployee AS em ON ce.EmpId = em.EmpId
			INNER JOIN dbo.EmployeeCalendar AS empC WITH (NOLOCK) ON empC.EmpId = ce.EmpId
			INNER JOIN dbo.EmployeeSummary AS empSum WITH (NOLOCK) ON empSum.EmpId = ce.EmpId
			INNER JOIN dbo.LeaveType AS lt WITH (NOLOCK) ON ISNULL(empC.LeaveTypeId, empC.LeaveTypeId2) = lt.LeaveTypeId
            AND lt.CompanyId = @CompanyId
			INNER JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON ldt.EmpId = ce.EmpId
			AND ldt.OnDate = empC.WorkDate
			AND ldt.IsHalfDay = 1
			INNER JOIN [dbo].[WorkingTimeRequest] AS rq WITH (NOLOCK) ON ldt.[RequestId] = rq.[RequestId]
			AND rq.CurrentStatus IN (4, 6)
			INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		WHERE ce.[Enabled] = 1
			AND ce.IsDeleted = 0
			AND EXISTS (
			SELECT 1
			FROM #tmpGroup AS tbl
			WHERE ce.GroupId = tbl.GroupId
			)
			AND ISNULL(@EmployeeId, ce.EmpId) = ce.EmpId
			AND ISNULL(@IsLocal, empSum.IsLocal) = empSum.IsLocal
			AND (
				DATENAME(DW, empC.WorkDate) = 'Saturday'
				OR DATENAME(DW, empC.WorkDate) = 'Sunday'
				)
			AND empC.IsLeaveDay != 0
			AND (
				empC.LeaveTypeId = 2
				OR empC.LeaveTypeId = 25
				OR empC.LeaveTypeId2 = 2
				OR empC.LeaveTypeId2 = 25
				)
			AND empC.WorkDate BETWEEN @FromDate
				AND @ToDate
			AND (
				@LeaveTypeId = - 1
				OR empC.LeaveTypeId = @LeaveTypeId
				OR empC.LeaveTypeId2 = @LeaveTypeId
				)
		
		UNION
		-- general leave # half day
		SELECT ce.EmpId AS EmployeeId
			,ce.Nickname
			,emp.FullName
			,ce.Code
			,empSum.IsLocal
			,gr.GroupId AS TeamId
			,gr.[Name] AS TeamName
			,gr.Code AS TeamCode
			,empC.WorkDate AS LeaveDate
			,ISNULL(empC.LeaveTypeId, empC.LeaveTypeId2) AS LeaveTypeId
			,lt.NAME AS LeaveType
			,empC.LeaveDay
			,rq.Remark
			,rq.ApproverComment
		FROM dbo.Employee AS emp WITH (NOLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.UserId = ce.UserId
			INNER JOIN #tmpEmployee AS em ON ce.EmpId = em.EmpId
			INNER JOIN dbo.EmployeeCalendar AS empC WITH (NOLOCK) ON empC.EmpId = ce.EmpId
			INNER JOIN dbo.EmployeeSummary AS empSum WITH (NOLOCK) ON empSum.EmpId = ce.EmpId
			INNER JOIN dbo.LeaveType AS lt WITH (NOLOCK) ON ISNULL(empC.LeaveTypeId, empC.LeaveTypeId2) = lt.LeaveTypeId
            AND lt.CompanyId = @CompanyId
			INNER JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON ldt.EmpId = ce.EmpId
			AND ldt.OnDate = empC.WorkDate
			AND ldt.IsHalfDay = 0
			INNER JOIN dbo.LeaveRequest AS le WITH (NOLOCK) ON ldt.RequestId = le.RequestId
			AND le.LeaveType = 0
			INNER JOIN [dbo].[WorkingTimeRequest] AS rq WITH (NOLOCK) ON ldt.[RequestId] = rq.[RequestId]
			AND rq.CurrentStatus IN (4, 6)
			INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		WHERE ce.[Enabled] = 1
			AND ce.IsDeleted = 0
			AND EXISTS (
			    SELECT 1
			    FROM #tmpGroup AS tbl
			    WHERE ce.GroupId = tbl.GroupId
			)
			AND ISNULL(@EmployeeId, ce.EmpId) = ce.EmpId
			AND ISNULL(@IsLocal, empSum.IsLocal) = empSum.IsLocal
			AND (
				DATENAME(DW, empC.WorkDate) = 'Saturday'
				OR DATENAME(DW, empC.WorkDate) = 'Sunday'
				)
			AND empC.IsLeaveDay != 0
			AND (
				empC.LeaveTypeId = 2
				OR empC.LeaveTypeId = 25
				OR empC.LeaveTypeId2 = 2
				OR empC.LeaveTypeId2 = 25
				)
			AND empC.WorkDate BETWEEN @FromDate
				AND @ToDate
			AND (
				@LeaveTypeId = - 1
				OR empC.LeaveTypeId = @LeaveTypeId
				OR empC.LeaveTypeId2 = @LeaveTypeId
				)
		
		UNION
		-- #general day & # half day
		SELECT ce.EmpId AS EmployeeId
			,ce.Nickname
			,emp.FullName
			,ce.Code
			,empSum.IsLocal
			,gr.GroupId AS TeamId
			,gr.[Name] AS TeamName
			,gr.Code AS TeamCode
			,empC.WorkDate AS LeaveDate
			,ISNULL(empC.LeaveTypeId, empC.LeaveTypeId2) AS LeaveTypeId
			,lt.NAME AS LeaveType
			,empC.LeaveDay
			,rq.Remark
			,rq.ApproverComment
		FROM dbo.Employee AS emp WITH (NOLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.UserId = ce.UserId
			INNER JOIN #tmpEmployee AS em ON ce.EmpId = em.EmpId
			INNER JOIN (
			SELECT EmpId, WorkDate, IsLeaveDay, LeaveTypeId, LeaveTypeId2, LeaveDay
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE (
					@EmployeeId = EmpId
					OR @EmployeeId IS NULL
					)
				AND (
					DATENAME(DW, WorkDate) = 'Saturday'
					OR DATENAME(DW, WorkDate) = 'Sunday'
					)
				AND IsLeaveDay <> 0
				AND LeaveDay <> 0.5
				AND (
					LeaveTypeId = 2
					OR LeaveTypeId = 25
					OR LeaveTypeId2 = 2
					OR LeaveTypeId2 = 25
					)
				AND WorkDate BETWEEN @FromDate
					AND @ToDate
			) AS empC ON empC.EmpId = ce.EmpId
			INNER JOIN dbo.EmployeeSummary AS empSum WITH (NOLOCK) ON empSum.EmpId = ce.EmpId
			INNER JOIN dbo.LeaveType AS lt WITH (NOLOCK) ON ISNULL(empC.LeaveTypeId, empC.LeaveTypeId2) = lt.LeaveTypeId
            AND lt.CompanyId = @CompanyId
			INNER JOIN dbo.LeaveRequest AS le WITH (NOLOCK) ON le.EmpId = empC.EmpId
			AND empC.WorkDate BETWEEN le.FromDate
				AND le.ToDate
			AND le.LeaveType <> 0
			INNER JOIN [dbo].[WorkingTimeRequest] AS rq WITH (NOLOCK) ON le.[RequestId] = rq.[RequestId]
			AND rq.CurrentStatus IN (4, 6)
			INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		WHERE ce.[Enabled] = 1
			AND ce.IsDeleted = 0
			AND EXISTS (
			    SELECT 1
			    FROM #tmpGroup AS tbl
			    WHERE ce.GroupId = tbl.GroupId
			)
			AND ISNULL(@EmployeeId, ce.EmpId) = ce.EmpId
			AND ISNULL(@IsLocal, empSum.IsLocal) = empSum.IsLocal
			AND (
				DATENAME(DW, empC.WorkDate) = 'Saturday'
				OR DATENAME(DW, empC.WorkDate) = 'Sunday'
				)
			AND empC.IsLeaveDay <> 0
			AND empC.LeaveDay <> 0.5
			AND (
				empC.LeaveTypeId = 2
				OR empC.LeaveTypeId = 25
				OR empC.LeaveTypeId2 = 2
				OR empC.LeaveTypeId2 = 25
				)
			AND empC.WorkDate BETWEEN @FromDate
				AND @ToDate
			AND (
				@LeaveTypeId = - 1
				OR empC.LeaveTypeId = @LeaveTypeId
				OR empC.LeaveTypeId2 = @LeaveTypeId
				)
		) a
	ORDER BY LeaveDate DESC

	DROP TABLE #tmpGroup

    DROP TABLE #tmpEmployee
END