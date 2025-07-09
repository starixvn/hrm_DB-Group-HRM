/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_InsertTmpHospitalizationLeaveTrans] @RequestId BIGINT
AS
/*
    Created: Tim.Trinh@2021-08-24
    Task: insert temp hospitalization leave balance
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EmpId INT
		,@GeneralLeaveTypeId INT = 0
		,@HospitalizationLeaveTypeId INT = 39
		,@LeaveWorkType TINYINT = 2
		,@LeaveTypeId INT
		,@TotalDays NUMERIC(5, 1)
		,@FromDate DATE
		,@ToDate DATE
		,@tmpDate DATE
		,@LeaveDay NUMERIC(5, 1)

	SELECT @EmpId = lr.EmpId
		,@FromDate = lr.FromDate
		,@ToDate = lr.ToDate
		,@LeaveTypeId = lr.LeaveType
		,@TotalDays = lr.TotalDays
	FROM dbo.WorkingTimeRequest AS rq WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON rq.RequestId = lr.RequestId
	WHERE rq.RequestId = @RequestId

	IF EXISTS (
			SELECT 1
			FROM dbo.tmpHospitalizationLeaveBalance WITH (NOLOCK)
			WHERE RequestId = @RequestId
			)
	BEGIN
		DELETE
		FROM dbo.tmpHospitalizationLeaveBalance WITH (ROWLOCK)
		WHERE RequestId = @RequestId
	END

	IF @LeaveTypeId = @GeneralLeaveTypeId
		OR @TotalDays = 0.5
	BEGIN
		SET @tmpDate = @FromDate

		WHILE DATEDIFF(MONTH, @tmpDate, @ToDate) >= 0
		BEGIN
			SELECT @LeaveDay = SUM(CASE 
						WHEN (DATEDIFF(MONTH, OnDate, @tmpDate) = 0) THEN CASE 
								WHEN IsHalfDay = 1 THEN 0.5
								ELSE 1
								END
						ELSE 0
						END)
			FROM dbo.LeaveRequestDetail WITH (NOLOCK)
			WHERE RequestId = @RequestId
				AND WorkType = @LeaveWorkType
				AND LeaveType = @HospitalizationLeaveTypeId

			IF @LeaveDay > 0
			BEGIN
				INSERT INTO dbo.tmpHospitalizationLeaveBalance (
					EmpId
					,Requestid
					,TotalDays
					,[Year]
					,[Status]
					,[Month]
					)
				VALUES (
					@EmpId
					,@Requestid
					,@LeaveDay
					,YEAR(@tmpDate)
					,0
					,MONTH(@tmpDate)
					)
			END

			SET @tmpDate = DATEADD(MONTH, 1, @tmpDate)
		END
	END
	ELSE
	BEGIN
		IF @LeaveTypeId = @HospitalizationLeaveTypeId
		BEGIN
			SET @tmpDate = @FromDate

			WHILE DATEDIFF(MONTH, @tmpDate, @ToDate) >= 0
			BEGIN
				SELECT @LeaveDay = COUNT(1)
				FROM dbo.EmployeeCalendar WITH (NOLOCK)
				WHERE DATEDIFF(MONTH, WorkDate, @tmpDate) = 0
					AND EmpId = @EmpId
					AND IsHoliday = 0
					AND IsOffDay = 0
					AND WorkDate >= CAST(@FromDate AS DATETIME)
					AND WorkDate <= CAST(@ToDate AS DATETIME)

				IF @LeaveDay > 0
				BEGIN
					INSERT INTO dbo.tmpHospitalizationLeaveBalance (
						EmpId
						,RequestId
						,TotalDays
						,[Year]
						,[Status]
						,[Month]
						)
					VALUES (
						@EmpID
						,@RequestId
						,@LeaveDay
						,YEAR(@tmpDate)
						,0
						,MONTH(@tmpDate)
						)
				END

				SET @tmpDate = DATEADD(MONTH, 1, @tmpDate)
			END
		END
	END
END