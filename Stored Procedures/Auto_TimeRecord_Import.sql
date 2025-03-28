/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Auto_TimeRecord_Import] @CompanyId SMALLINT
	,@FromDate DATE
    ,@ToDate DATE
    ,@TimeRecordXml NVARCHAR(MAX) = ''
    ,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20250318@Tim
Task: import check in/out
DB: HRM

Revisions:
Param's Explanation:
- @TimeRecordXml: "<Root>
		<Row EmpNo={0} InOutType={1} RecordTime={2} />
	</Root>"
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SyncDate DATETIME = GETDATE()
		,@DocHandler INT

	CREATE TABLE #tmpTimeRecord (
		EmpNo VARCHAR(20)
		,InOutType TINYINT
		,RecordTime DATETIME
		)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@TimeRecordXml

	INSERT INTO #tmpTimeRecord (
		EmpNo
		,InOutType
		,RecordTime
		)
	SELECT EmpNo
        ,InOutType
        ,RecordTime
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (EmpNo VARCHAR(20), InOutType TINYINT, RecordTime DATETIME) AS d

	EXEC sp_xml_removedocument @DocHandler

    INSERT INTO dbo.TimeRecord (
		EmpId
		,InOutType
		,RecordTime
		,InsertDate
		)
    SELECT emp.EmpId
        ,tmp.InOutType
        ,tmp.RecordTime
        ,@SyncDate
    FROM #tmpTimeRecord AS tmp WITH (NOLOCK)
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tmp.EmpNo = emp.Code
            OR ISNULL(TRY_PARSE(emp.Code AS INT), 0) = ISNULL(TRY_PARSE(tmp.EmpNo AS INT), -1)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
    WHERE ce.CompanyId = @CompanyId
        AND NOT EXISTS (
			SELECT 1
			FROM dbo.TimeRecord AS t WITH (NOLOCK)
			WHERE t.EmpId = emp.EmpId
				AND DATEDIFF(SECOND, t.RecordTime, tmp.RecordTime) = 0
			)

    INSERT INTO dbo.tmpEmployeeAttendace (
		EmpId
		,WorkDate
		,InsertedDate
		)
	SELECT emp.EmpId
		,CAST(DATEADD(DD, -1, tmp.RecordTime) AS DATE)
		,@SyncDate
	FROM #tmpTimeRecord AS tmp WITH (NOLOCK)
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tmp.EmpNo = emp.Code
            OR ISNULL(TRY_PARSE(emp.Code AS INT), 0) = ISNULL(TRY_PARSE(tmp.EmpNo AS INT), -1)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
	WHERE ce.CompanyId = @CompanyId
        AND NOT EXISTS (
		SELECT 1 
		FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK) 
		WHERE att.EmpId = emp.EmpId
			AND att.WorkDate = CAST(DATEADD(DD, -1, tmp.RecordTime) AS DATE)
		)

	UNION
	SELECT emp.EmpId
		,CAST(tmp.RecordTime AS DATE)
		,@SyncDate
	FROM #tmpTimeRecord AS tmp WITH (NOLOCK)
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tmp.EmpNo = emp.Code
            OR ISNULL(TRY_PARSE(emp.Code AS INT), 0) = ISNULL(TRY_PARSE(tmp.EmpNo AS INT), -1)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
	WHERE ce.CompanyId = @CompanyId
        AND NOT EXISTS (
		SELECT 1 
		FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK) 
		WHERE att.EmpId = emp.EmpId 
			AND att.WorkDate = CAST(tmp.RecordTime AS DATE)
		)

    EXEC [dbo].[EmployeeAttendance_ForWaitingCase] @CompanyId = @CompanyId

	SELECT EmpId
	INTO #tmpEmployee
	FROM dbo.EmployeeCalendar WITH (NOLOCK)
	WHERE DATEDIFF(DD, WorkDate, @ToDate) = 0
		AND (
			ShiftId IS NOT NULL
			OR IsOffDay = 1
			OR IsHoliday = 1
			OR IsLeaveDay = 1
			)

	IF EXISTS (
			SELECT 1
			FROM dbo.Employee AS e WITH (NOLOCK)
				INNER JOIN #tmpEmployee AS tmp ON e.EmpId = tmp.EmpId
			WHERE e.[Enabled] = 1
				AND DATEDIFF(DD, e.JoinedDate, @todate) > 0
				AND (
					e.ResignedDate IS NULL
					OR DATEDIFF(DD, @todate, e.ResignedDate) > 0
					)
				AND e.EmpId NOT IN (
					SELECT EmpId
					FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
					WHERE DATEDIFF(DD, att.AttendanceDate, @todate) = 0
						AND att.EmpId = e.EmpId
					)
			)
	BEGIN
		INSERT INTO dbo.tmpEmployeeAttendace (
			EmpId
			,WorkDate
			,InsertedDate
			)
		SELECT e.EmpId
			,@todate
			,@SyncDate
		FROM dbo.Employee AS e WITH (NOLOCK)
			INNER JOIN #tmpEmployee AS ec ON e.EmpId = ec.EmpId
		WHERE e.[Enabled] = 1
			AND DATEDIFF(DD, e.JoinedDate, @todate) > 0
			AND (
				e.ResignedDate IS NULL
				OR DATEDIFF(DD, @todate, e.ResignedDate) > 0
				)
			AND e.EmpId NOT IN (
				SELECT EmpId
				FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
				WHERE DATEDIFF(DD, att.AttendanceDate, @todate) = 0
					AND att.EmpId = e.EmpId
				)
	END

	INSERT INTO dbo.tmpEmployeeAttendace (
		EmpId
		,WorkDate
		,InsertedDate
		)
	SELECT att.EmpId
		,att.AttendanceDate
		,@SyncDate
	FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
		INNER JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON att.EmpId = empca.EmpId
		AND att.AttendanceDate = empca.WorkDate
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON att.EmpId = e.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON e.GroupId = rul.GroupId
		AND es.IsLocal = rul.IsLocal
		AND rul.DisciplineTypeId = 2
	WHERE att.AttendanceDate BETWEEN @FromDate
				AND @ToDate
		AND ISNULL(att.ShiftId, '') <> ''
		AND empca.LeaveDay <> 1
		AND (
			(
				ISNULL(att.InFixed, '') = ''
				AND ISNULL(att.OutFixed, '') <> ''
				AND @SyncDate > att.ExpectedInTime
				AND DATEDIFF(MI, att.ExpectedInTime, @SyncDate) < 480
				)
			OR (
				ISNULL(att.InFixed, '') <> ''
				AND ISNULL(att.OutFixed, '') = ''
				AND @SyncDate > att.ExpectedOutTime
				AND DATEDIFF(MI, att.ExpectedOutTime, @SyncDate) < 480
				)
			)
		AND ISNULL(rul.[Value], 0) = 1
	
	UNION
	SELECT att.EmpId
		,att.AttendanceDate
		,@SyncDate
	FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON att.EmpId = e.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON e.GroupId = rul.GroupId
		AND es.IsLocal = rul.IsLocal
		AND rul.DisciplineTypeId = 5
	WHERE att.AttendanceDate BETWEEN @FromDate
				AND @ToDate
		AND ISNULL(att.ShiftId, '') <> ''
		AND ISNULL(att.InFixed, '') = ''
		AND ISNULL(att.OutFixed, '') = ''
		AND @SyncDate > att.ExpectedOutTime
		AND DATEDIFF(MI, att.ExpectedOutTime, @SyncDate) < 480
		AND ISNULL(att.LeaveDay, 0) <> 1
		AND ISNULL(rul.[Value], 0) = 1

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpTimeRecord
END