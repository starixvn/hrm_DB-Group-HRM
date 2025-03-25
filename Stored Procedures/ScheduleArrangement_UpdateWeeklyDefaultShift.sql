/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ScheduleArrangement_UpdateWeeklyDefaultShift] @CompanyId SMALLINT
    ,@ActorId INT
	,@EmployeeId INT
	,@FromDate DATE
	,@MonShiftId INT = NULL
	,@TueShiftId INT = NULL
	,@WedShiftId INT = NULL
	,@ThuShiftId INT = NULL
	,@FriShiftId INT = NULL
	,@SatShiftId INT = NULL
	,@SunShiftId INT = NULL
	,@IsUsedWeeklyDefaultShift BIT = 0
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim.Trinh@2019-05-07
Task: update weekly default shift
DB: HRM

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE()
		,@ToDate1 DATE = DATEADD(DAY, 6, @FromDate)
		-- work type
		,@OffDay TINYINT = 1
		,@LeaveDay TINYINT = 2
		-- request status
		,@VerifiedStatusId TINYINT = 2
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6

	UPDATE dbo.EmployeeDefaultShift WITH (ROWLOCK, UPDLOCK)
	SET MonShift = @MonShiftId
		,TueShift = @TueShiftId
		,WedShift = @WedShiftId
		,ThuShift = @ThuShiftId
		,FriShift = @FriShiftId
		,SatShift = @SatShiftId
		,SunShift = @SunShiftId
	WHERE EmpID = @EmployeeId

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK, UPDLOCK)
	SET IsDefaultSchedule = @IsUsedWeeklyDefaultShift
	WHERE EmpId = @EmployeeId

	IF @IsUsedWeeklyDefaultShift = 1
	BEGIN
		UPDATE empca
		SET empca.ShiftId = CASE 
				WHEN empsum.IsLocal = 0
					OR (
						empsum.IsLocal = 1
						AND holiday.Id IS NULL
						) THEN CASE 
						WHEN DATEPART(dw, empca.WorkDate) = 1 THEN SunShift
						WHEN DATEPART(dw, empca.WorkDate) = 2 THEN MonShift
						WHEN DATEPART(dw, empca.WorkDate) = 3 THEN TueShift
						WHEN DATEPART(dw, empca.WorkDate) = 4 THEN WedShift
						WHEN DATEPART(dw, empca.WorkDate) = 5 THEN ThuShift
						WHEN DATEPART(dw, empca.WorkDate) = 6 THEN FriShift
						WHEN DATEPART(dw, empca.WorkDate) = 7 THEN SatShift
						END
				ELSE empca.ShiftId
				END
			,empca.IsOffDay = CASE 
				WHEN (
						empsum.IsLocal = 1
						OR empsum.IsExpatUseHoliday = 1
						)
					AND holiday.Id IS NOT NULL THEN 0
				WHEN DATEPART(dw, empca.WorkDate) = 1
					AND SunShift IS NULL THEN 1
				WHEN DATEPART(dw, empca.WorkDate) = 2
					AND MonShift IS NULL THEN 1
				WHEN DATEPART(dw, empca.WorkDate) = 3
					AND TueShift IS NULL THEN 1
				WHEN DATEPART(dw, empca.WorkDate) = 4
					AND WedShift IS NULL THEN 1
				WHEN DATEPART(dw, empca.WorkDate) = 5
					AND ThuShift IS NULL THEN 1
				WHEN DATEPART(dw, empca.WorkDate) = 6
					AND FriShift IS NULL THEN 1
				WHEN DATEPART(dw, empca.WorkDate) = 7
					AND SatShift IS NULL THEN 1
				ELSE 0
				END
			,empca.IsHoliday = CASE 
				WHEN (
						empsum.IsLocal = 1
						OR empsum.IsExpatUseHoliday = 1
						)
					AND holiday.Id IS NOT NULL THEN 1
				ELSE 0
				END
			,empca.ModifiedBy = @ActorId
			,empca.ModifiedDate = @ModifiedDate
		FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empca.EmpId = empsum.EmpId
			AND empsum.IsDefaultSchedule = 1
			LEFT JOIN dbo.EmployeeDefaultShift AS shift WITH (NOLOCK) ON empca.EmpId = shift.EmpID
			LEFT JOIN dbo.Holiday AS holiday WITH (NOLOCK) ON holiday.CompanyId = @CompanyId
            AND empca.WorkDate BETWEEN holiday.FromDate
				AND holiday.ToDate
		WHERE empca.EmpId = @EmployeeId
			AND empca.WorkDate >= @FromDate
			AND empca.IsLeaveDay = 0
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.ChangeShiftRequest AS csr WITH (NOLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csrdt WITH (NOLOCK) ON csr.RequestId = csrdt.RequestId
					AND csrdt.OnDate = empca.WorkDate
					INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON csr.RequestId = wkr.RequestId
					AND wkr.CurrentStatus IN (@VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
				WHERE empca.EmpId = csr.EmpId
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.WorkingTimeRequest AS wkr WITH (NOLOCK)
					INNER JOIN dbo.LeaveRequestDetail AS lrd WITH (NOLOCK) ON wkr.RequestId = lrd.RequestId
					AND empca.EmpId = lrd.EmpId
					AND empca.WorkDate = lrd.OnDate
					AND lrd.WorkType = @OffDay
				WHERE wkr.CurrentStatus IN (@VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
				)

		UPDATE empca
		SET empca.IsFixedOffDay = 0
		FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		WHERE empca.IsOffDay = 0
			AND empca.IsFixedOffDay = 1
	END
	ELSE
	BEGIN
		UPDATE empca
		SET empca.ShiftId = (CASE 
				WHEN (
						empsum.IsLocal = 1
						OR empsum.IsExpatUseHoliday = 1
						)
					AND holiday.Id IS NOT NULL THEN NULL
				ELSE shift.ShiftId END
				)
			,empca.IsOffDay = 0
			,empca.IsFixedOffDay = 0
			,empca.IsHoliday = CASE 
				WHEN (
						empsum.IsLocal = 1
						OR empsum.IsExpatUseHoliday = 1
						)
					AND holiday.Id IS NOT NULL THEN 1
				ELSE 0
				END
			,empca.ModifiedBy = @ActorId
			,empca.ModifiedDate = @ModifiedDate
		FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empca.EmpId = empsum.EmpId
			AND empca.EmpId = @EmployeeId
			AND empca.WorkDate >= @FromDate
			AND empca.IsLeaveDay = 0
			AND empsum.IsDefaultSchedule = 0
			CROSS APPLY (
			SELECT TOP 1 shift.ShiftId
			FROM dbo.ScheduleArrangementDefaultShift AS shift WITH (NOLOCK)
			WHERE shift.EmployeeId = empca.EmpId
				AND shift.ShiftId > 0
				AND shift.FromDate <= empca.WorkDate
			ORDER BY shift.FromDate DESC
			) AS shift
			LEFT JOIN dbo.Holiday AS holiday WITH (NOLOCK) ON holiday.CompanyId = @CompanyId
            AND empca.WorkDate BETWEEN holiday.FromDate
				AND holiday.ToDate
		WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.ChangeShiftRequest AS csr WITH (NOLOCK)
					INNER JOIN dbo.ChangeShiftRequestDetail AS csrdt WITH (NOLOCK) ON csr.RequestId = csrdt.RequestId
					AND csrdt.OnDate = empca.WorkDate
					INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON csr.RequestId = wkr.RequestId
					AND wkr.CurrentStatus IN (@VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
				WHERE empca.EmpId = csr.EmpId
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.WorkingTimeRequest AS wkr WITH (NOLOCK)
					INNER JOIN dbo.LeaveRequestDetail AS lrd WITH (NOLOCK) ON wkr.RequestId = lrd.RequestId
					AND empca.EmpId = lrd.EmpId
					AND empca.WorkDate = lrd.OnDate
					AND lrd.WorkType = @OffDay
				WHERE wkr.CurrentStatus IN (@VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
				)
	END

	EXEC dbo.ScheduleArrangement_UpdateOffDayReplacement @CompanyId = @CompanyId
        ,@ActorId = - 1
		,@EmployeeIds = @EmployeeId
		,@FromDate = @FromDate
		,@ToDate = @ToDate1
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END