/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ScheduleArrangement_SyncWorkingShift] @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@EmployeeIds NVARCHAR(MAX) = ''
	,@WorkingShiftXml NVARCHAR(MAX) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20220106@Tim.Trinh
Task: sync working shift from OWP
DB: HRM

Revisions:
Param's Explanation:
- @WorkingShiftXml: "<Root>
		<Row EmployeeID={1} ShiftCode={2} ShiftDate={3} IsOffDay={4} IsPublicHoliday={5} ModifiedDate={6} />
	</Root>"
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SyncDate DATETIME = GETDATE()
		,@Today DATE = GETDATE()
		,@EmpId INT
		,@WorkDate DATE
		,@DocHandler INT

	CREATE TABLE #tmpWorkingShift (
		EmployeeID VARCHAR(20)
		,ShiftCode VARCHAR(20)
		,ShiftDate DATE
		,IsOffDay BIT
		,IsHoliday BIT
		,ModifiedDate DATETIME
		)

	CREATE TABLE #tmpEmployeeIds (EmpId INT PRIMARY KEY)

	CREATE TABLE #tmpEmployeeCalendar (
		EmpId INT
		,WorkDate DATE
		,ShiftId INT
		,IsOffDay BIT
		,IsHoliday BIT
		)

	IF ISNULL(@EmployeeIds, '') <> ''
	BEGIN
		INSERT INTO #tmpEmployeeIds (EmpId)
		SELECT DISTINCT val
		FROM dbo.fnc_strSplit(@EmployeeIds, ',')
		WHERE ISNUMERIC(val) = 1
	END

	BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@WorkingShiftXml

	INSERT INTO #tmpWorkingShift (
		EmployeeID
		,ShiftCode
		,ShiftDate
		,IsOffDay
		,IsHoliday
		,ModifiedDate
		)
	SELECT EmployeeID
		,ShiftCode
		,ShiftDate
		,IsOffDay
		,IsPublicHoliday
		,ModifiedDate
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (EmployeeID VARCHAR(20), ShiftCode VARCHAR(20), ShiftDate DATE, IsOffDay BIT, IsPublicHoliday BIT, ModifiedDate DATETIME) AS Data

	EXEC sp_xml_removedocument @DocHandler

	UPDATE ec
	SET ec.ShiftId = s.ShiftID
		,ec.IsOffDay = CASE 
			WHEN tmpca.IsLeaveDay = 0
				AND tmpca.IsKeepInView = 0
				AND tmpca.ChangeShiftTypeId IS NULL THEN
					CASE
						WHEN tmpws.IsOffDay = 0 AND s.ShiftID IS NULL AND ISNULL(tmpws.ShiftCode, '') != '' THEN ec.IsOffDay
						ELSE tmpws.IsOffDay END
			ELSE ec.IsOffDay
			END
		,ec.IsHoliday = CASE 
			WHEN tmpws.IsHoliday = 1
				AND h.Id IS NOT NULL THEN 1
			ELSE 0
			END
		,ec.ModifiedBy = @ActorId
		,ec.ModifiedDate = @SyncDate
		,ec.OWPSyncDate = @SyncDate
	OUTPUT INSERTED.EmpId
		,INSERTED.WorkDate
		,INSERTED.ShiftId
		,INSERTED.IsOffDay
		,INSERTED.IsHoliday
	INTO #tmpEmployeeCalendar(EmpId, WorkDate, ShiftId, IsOffDay, IsHoliday)
	FROM dbo.EmployeeCalendar AS ec WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ec.EmpId = e.EmpId
		INNER JOIN #tmpEmployeeIds AS tmpemp WITH (NOLOCK) ON e.EmpId = tmpemp.EmpId
		INNER JOIN #tmpWorkingShift AS tmpws WITH (NOLOCK) ON e.Code = tmpws.EmployeeID
		INNER JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON ec.EmpId = tmpca.EmpId
		AND ec.WorkDate = tmpca.WorkDate
		AND CAST(ec.WorkDate AS DATE) = CAST(tmpws.ShiftDate AS DATE)
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.CompanyId = @CompanyId
        AND s.Code = tmpws.ShiftCode
		LEFT JOIN dbo.Holiday AS h WITH (NOLOCK) ON h.CompanyId = @CompanyId
        AND tmpws.ShiftDate BETWEEN h.FromDate
			AND h.ToDate
	WHERE tmpca.ChangeShiftTypeId IS NULL
		AND tmpca.IsLeaveDay = 0
		AND tmpca.IsKeepInView = 0
		AND (
			(
				s.ShiftID IS NULL
				AND (
					(
						tmpws.IsOffDay = 1
						AND tmpca.IsOffDay = 0
						)
					OR (
						tmpws.IsOffDay = 0
						AND tmpca.IsOffDay = 1
						)
					OR (
						tmpws.IsHoliday = 1
						AND tmpca.IsHoliday = 0
						AND h.Id IS NOT NULL
						)
					OR (
						tmpws.IsHoliday = 0
						AND tmpca.IsHoliday = 1
						)
					)
				)
			OR (
				s.ShiftID IS NOT NULL
				AND (
					tmpca.ShiftId IS NULL
					OR tmpca.ShiftId != s.ShiftID
					)
				)
			)

	INSERT INTO dbo.EmployeeCalendar (
		WorkDate
		,EmpId
		,ShiftId
		,IsOffDay
		,IsHoliday
		,ModifiedBy
		,ModifiedDate
		,OWPSyncDate
		)
	OUTPUT INSERTED.EmpId
		,INSERTED.WorkDate
		,INSERTED.ShiftId
		,INSERTED.IsOffDay
		,INSERTED.IsHoliday
	INTO #tmpEmployeeCalendar(EmpId, WorkDate, ShiftId, IsOffDay, IsHoliday)
	SELECT DISTINCT tmpws.ShiftDate
		,e.EmpId
		,s.ShiftID
		,CASE 
			WHEN tmpca.EmpId IS NULL
				OR (
					tmpca.EmpId IS NOT NULL
					AND tmpca.IsLeaveDay = 0
					AND tmpca.IsKeepInView = 0
					AND tmpca.ChangeShiftTypeId IS NULL
					) THEN tmpws.IsOffDay
			ELSE 0
			END
		,CASE 
			WHEN tmpws.IsHoliday = 1
				AND h.Id IS NOT NULL THEN 1
			ELSE 0
			END
		,@ActorId
		,@SyncDate
		,@SyncDate
	FROM #tmpWorkingShift AS tmpws WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.Code = tmpws.EmployeeID
		INNER JOIN #tmpEmployeeIds AS tmpemp WITH (NOLOCK) ON e.EmpId = tmpemp.EmpId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.CompanyId = @CompanyId
        AND s.Code = tmpws.ShiftCode
		LEFT JOIN dbo.Holiday AS h WITH (NOLOCK) ON h.CompanyId = @CompanyId
        AND tmpws.ShiftDate BETWEEN h.FromDate
			AND h.ToDate
		LEFT JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON e.EmpId = tmpca.EmpId
		AND CAST(tmpws.ShiftDate AS DATE) = CAST(tmpca.WorkDate AS DATE)
	WHERE (
			(
				s.ShiftID IS NULL
				AND (
					tmpws.IsOffDay = 1
					OR (
						tmpws.IsHoliday = 1
						AND h.Id IS NOT NULL
						)
					)
				)
			OR s.ShiftID IS NOT NULL
			)
		AND NOT EXISTS (
			SELECT ec.EmpId
			FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
			WHERE ec.EmpId = e.EmpId
				AND CAST(tmpws.ShiftDate AS DATE) = CAST(ec.WorkDate AS DATE)
			)

	IF EXISTS (
			SELECT 1
			FROM #tmpEmployeeCalendar WITH (NOLOCK)
			)
	BEGIN
		EXEC dbo.ScheduleArrangement_UpdateOffDayReplacement @CompanyId = @CompanyId
            ,@ActorId = @ActorId
			,@EmployeeIds = @EmployeeIds
			,@FromDate = @FromDate
			,@ToDate = @ToDate
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT

		DECLARE @xml NVARCHAR(MAX)

		SET @xml = CAST((
					SELECT EmpId AS '@EmpId'
						,WorkDate AS '@WorkDate'
						,ShiftId AS '@ShiftId'
						,IsOffDay AS '@IsOffDay'
						,IsHoliday AS '@IsHoliday'
					FROM #tmpEmployeeCalendar WITH (NOLOCK)
					FOR XML PATH('Row')
						,ROOT('Root')
					) AS NVARCHAR(MAX))

		EXEC dbo.Log_WriteLog @LogActionId = 1004
			,@LogDate = @SyncDate
			,@Description = 'Sync working shift from OWP'
			,@TrackingValue = @xml
			,@UserId = @ActorId
	END

	DELETE
	FROM #tmpEmployeeCalendar WITH (ROWLOCK, UPDLOCK)
	WHERE WorkDate > @Today

	WHILE EXISTS (
			SELECT 1
			FROM #tmpEmployeeCalendar WITH (NOLOCK)
			)
	BEGIN
		SELECT TOP 1 @EmpId = EmpId
			,@WorkDate = WorkDate
		FROM #tmpEmployeeCalendar WITH (NOLOCK)

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
			,@WorkDate
			,@WorkDate
			,1

		DELETE
		FROM #tmpEmployeeCalendar WITH (ROWLOCK, UPDLOCK)
		WHERE EmpId = @EmpId
			AND WorkDate = @WorkDate
	END
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = ERROR_MESSAGE()
	END CATCH

	DROP TABLE #tmpEmployeeIds

	DROP TABLE #tmpWorkingShift

	DROP TABLE #tmpEmployeeCalendar
END