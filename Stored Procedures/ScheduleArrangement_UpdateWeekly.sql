/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ScheduleArrangement_UpdateWeekly]
(
    @CompanyId SMALLINT
    ,@ActorId INT
    ,@FromDate DATE
    ,@ToDate DATE
    ,@WeeklyScheduleXml VARCHAR(MAX) = ''
    ,@DefaultShiftXml VARCHAR(MAX) = ''
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tim.Trinh@2019-04-16
    Task: Update weekly schedule
    DB: bodb_HRM

    Revisions:
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
        @WeeklyScheduleXml=N'<ROOT><Row EmployeeId="1" WorkDate="2013-01-01" ShiftId="1" IsHoliday="1" IsOffDay="1" IsFixedOffDay="1" IsPublic="1" /></ROOT>
        @DefaultShiftXml=N'<ROOT><Row EmployeeId="1" FromDate="2013-01-01" ShiftId="1" /></ROOT>
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @Today DATE = GETDATE()
		,@ModifiedDate DATETIME = GETDATE()
		,@DocHandler INT
		-- change shift type
		,@ChangeShiftTypeId TINYINT = 1
		,@MoveOfDayTypeId TINYINT = 2
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7
		,@serverTimeZone SMALLINT = -4
		,@clientTimeZone REAL


	SELECT @clientTimeZone = config.[Value]
	FROM dbo.SystemConfigs AS config WITH (NOLOCK)
	WHERE config.CompanyId = @CompanyId
		AND config.[Key] = 'TimeZone'

	SET @clientTimeZone = ISNULL(@clientTimeZone, @serverTimeZone)

	SET @Today = DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), GETDATE()))

	CREATE TABLE #tblWeeklySchedule (
		EmployeeId INT
		,WorkDate DATE
		,ShiftId INT NULL
		,IsHoliday BIT
		,IsOffDay BIT
		,IsFixedOffDay BIT
		,IsPublic BIT
		)

	CREATE TABLE #tblDefaultShift (
		EmployeeId INT
		,FromDate DATE
		,ShiftId INT NULL
		)

	CREATE TABLE #OTMonthlyRequest (
		RequestId BIGINT
		,NormalHours DECIMAL(18, 2)
		,OffHours DECIMAL(18, 2)
		,PublicHours DECIMAL(18, 2)
		,SpecialHours DECIMAL(18, 2)
		)

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@WeeklyScheduleXml

		INSERT INTO #tblWeeklySchedule (
			EmployeeId
			,WorkDate
			,ShiftId
			,IsHoliday
			,IsOffDay
			,IsFixedOffDay
			,IsPublic
			)
		SELECT EmployeeId
			,WorkDate
			,CASE 
				WHEN ShiftId = '' THEN NULL
				ELSE CONVERT(INT, ShiftId)
				END
			,IsHoliday
			,IsOffDay
			,IsFixedOffDay
			,IsPublic
		FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (EmployeeId INT, WorkDate DATE, ShiftId VARCHAR(100), IsHoliday BIT, IsOffDay BIT, IsFixedOffDay BIT, IsPublic BIT) AS Data

		EXEC sp_xml_removedocument @DocHandler

		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@DefaultShiftXml

		INSERT INTO #tblDefaultShift (
			EmployeeId
			,FromDate
			,ShiftId
			)
		SELECT EmployeeId
			,FromDate
			,CASE 
				WHEN ShiftId = '' THEN NULL
				ELSE CONVERT(INT, ShiftId)
				END
		FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (EmployeeId INT, FromDate DATE, ShiftId VARCHAR(100)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	DECLARE @EmployeeIds VARCHAR(MAX)

	SELECT @EmployeeIds = COALESCE(@EmployeeIds + ',', '') + CAST(EmployeeId AS VARCHAR(10))
	FROM (
		SELECT DISTINCT EmployeeId
		FROM #tblWeeklySchedule
		) AS tbl

	DELETE tblweekly
	FROM #tblWeeklySchedule AS tblweekly WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON tblweekly.EmployeeId = ce.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
	WHERE e.JoinedDate > tblweekly.WorkDate
		OR e.ResignedDate <= tblweekly.WorkDate

	DELETE tblweekly
	FROM #tblWeeklySchedule AS tblweekly WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON tblweekly.WorkDate = empca.WorkDate
		AND tblweekly.EmployeeId = empca.EmpId
	WHERE (
			empca.IsLeaveDay = 1
			AND empca.LeaveDay = 1
			)
		OR empca.ChangeShiftTypeId = @ChangeShiftTypeId
		OR (
			empca.ChangeShiftTypeId = @MoveOfDayTypeId
			AND empca.MoveOffFromDate IS NOT NULL
			)
		OR (
			empca.IsKeepInView = 1
			AND tblweekly.ShiftId IS NULL
			)
		OR (
			tblweekly.WorkDate <= @Today
			AND empca.IsOvertime = 1
			)

	INSERT INTO #OTMonthlyRequest (
		RequestId
		,NormalHours
		,OffHours
		,PublicHours
		,SpecialHours
		)
	SELECT ot.RequestId
		,SUM(ISNULL(ot.NormalHours, 0))
		,SUM(ISNULL(ot.OffHours, 0))
		,SUM(ISNULL(ot.PublicHours, 0))
		,SUM(ISNULL(ot.SpecialHours, 0))
	FROM dbo.OTDailyRequest AS ot WITH (NOLOCK)
		INNER JOIN #tblWeeklySchedule AS tblweekly WITH (NOLOCK) ON ot.EmpId = tblweekly.EmployeeId
		AND ot.OvertimeDate = tblweekly.WorkDate
	GROUP BY ot.RequestId

	DELETE ot
	FROM dbo.OTDailyRequest AS ot WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblWeeklySchedule AS tblweekly WITH (NOLOCK) ON ot.EmpId = tblweekly.EmployeeId
		AND ot.OvertimeDate = tblweekly.WorkDate

	UPDATE otm
	SET otm.NormalHours = ISNULL(otm.NormalHours, 0) - ot.NormalHours
		,otm.OffHours = ISNULL(otm.OffHours, 0) - ot.OffHours
		,otm.PublicHours = ISNULL(otm.PublicHours, 0) - ot.PublicHours
		,otm.SpecialHours = ISNULL(otm.SpecialHours, 0) - ot.SpecialHours
	FROM dbo.OTMonthlyRequest AS otm WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #OTMonthlyRequest AS ot WITH (NOLOCK) ON otm.RequestId = ot.RequestId

	INSERT INTO dbo.tmpEmployeeAttendace (
		EmpId
		,WorkDate
		,InsertedDate
		)
	SELECT tblweekly.EmployeeId
		,tblweekly.WorkDate
		,@ModifiedDate
	FROM #tblWeeklySchedule AS tblweekly WITH (NOLOCK)
		LEFT JOIN dbo.tmpEmployeeAttendace AS att WITH (NOLOCK) ON tblweekly.EmployeeId = att.EmpId
		AND tblweekly.WorkDate = att.WorkDate
	WHERE att.EmpId IS NULL

	UPDATE empca
	SET empca.ShiftId = tblweekly.ShiftId
		,empca.IsOffDay = tblweekly.IsOffDay
		,empca.IsFixedOffDay = tblweekly.IsFixedOffDay
		,empca.IsHoliday = tblweekly.IsHoliday
		,empca.IsPublic = tblweekly.IsPublic
		,empca.ModifiedBy = @ActorId
		,empca.ModifiedDate = @ModifiedDate
	FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblWeeklySchedule AS tblweekly WITH (NOLOCK) ON tblweekly.WorkDate = empca.WorkDate
		AND tblweekly.EmployeeId = empca.EmpId

	UPDATE empca
	SET empca.IsFixedOffDay = 0
	FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
	WHERE empca.IsOffDay = 0
		AND empca.IsFixedOffDay = 1

	INSERT INTO dbo.EmployeeCalendar (
		WorkDate
		,EmpId
		,ShiftId
		,IsOffDay
		,IsFixedOffDay
		,IsHoliday
		,IsPublic
		,ModifiedBy
		,ModifiedDate
		)
	SELECT WorkDate
		,EmployeeId
		,ShiftId
		,IsOffDay
		,IsFixedOffDay
		,IsHoliday
		,IsPublic
		,@ActorId
		,@ModifiedDate
	FROM #tblWeeklySchedule AS tbl WITH (NOLOCK)
	WHERE NOT EXISTS (
		SELECT 1
		FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
		WHERE tbl.EmployeeId = ec.EmpId
			AND tbl.WorkDate = ec.WorkDate
		)

	MERGE dbo.ScheduleArrangementDefaultShift AS [target]
	USING #tblDefaultShift AS [source] ON (
				[target].EmployeeId = [source].EmployeeId
				AND [target].FromDate = [source].FromDate
				)
	WHEN MATCHED
		AND ISNULL([target].ShiftId, 0) <> ISNULL([source].ShiftId, 0) THEN
			UPDATE
			SET [target].ShiftId = [source].ShiftId
				,[target].ModifiedBy = @ActorId
				,[target].ModifiedDate = @ModifiedDate
	WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				EmployeeId
				,FromDate
				,ShiftId
				,ModifiedBy
				,ModifiedDate
				)
			VALUES (
				[source].EmployeeId
				,[source].FromDate
				,[source].ShiftId
				,@ActorId
				,@ModifiedDate
				);

	EXEC dbo.ScheduleArrangement_UpdateOffDayReplacement @CompanyId = @CompanyId
        ,@ActorId = @ActorId
		,@EmployeeIds = @EmployeeIds
		,@FromDate = @FromDate
		,@ToDate = @ToDate
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	EXEC dbo.Log_WriteLog @LogActionId = 1002
		,@LogDate = @ModifiedDate
		,@Description = 'Update employee calendar'
		,@TrackingValue = @WeeklyScheduleXml
		,@UserId = @ActorId

	DROP TABLE #tblWeeklySchedule

	DROP TABLE #tblDefaultShift

	DROP TABLE #OTMonthlyRequest
END