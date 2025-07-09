/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_InsertTmpAnnualLeaveTrans]
(
    @RequestId BIGINT
    ,@EmpId INT
)
AS
/*
    Created: Quinn.Vo@20150927
    Task: insert temp al leave balance
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @GeneralLeaveType INT = 0
		,@AnnualLeaveType INT = 2
		,@LeaveWorkType TINYINT = 2
		,@LeaveTypeId INT
		,@TotalDays NUMERIC(5, 1)
		,@FromDate DATE
		,@ToDate DATE
		,@tmpDate DATE
		,@LeaveDay NUMERIC(5, 1)

	SELECT @FromDate = lr.FromDate
		,@ToDate = lr.ToDate
		,@LeaveTypeId = lr.LeaveType
		,@TotalDays = lr.TotalDays
	FROM dbo.WorkingTimeRequest rq WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest lr WITH (NOLOCK) ON rq.RequestId = lr.RequestId
	WHERE rq.RequestId = @RequestId

	IF EXISTS (
			SELECT 1
			FROM dbo.tmpLeaveBalance WITH (NOLOCK)
			WHERE RequestId = @RequestId
			)
	BEGIN
		DELETE
		FROM dbo.tmpLeaveBalance
		WHERE RequestId = @RequestId
	END

	IF (@LeaveTypeId = @GeneralLeaveType OR @TotalDays = 0.5)
	BEGIN
		SET @tmpDate = @FromDate

		WHILE (DATEDIFF(MONTH, @tmpDate, @ToDate) >= 0)
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
				AND LeaveType = @AnnualLeaveType

			IF (@LeaveDay > 0)
			BEGIN
				INSERT INTO dbo.tmpLeaveBalance (
					EmpId
					,RequestId
					,TotalDays
					,InYear
					,[Status]
					,InMonth
					)
				VALUES (
					@EmpId
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
	ELSE IF (@LeaveTypeId = @AnnualLeaveType)
	BEGIN
		SET @tmpDate = @FromDate

		WHILE (DATEDIFF(MONTH, @tmpDate, @ToDate) >= 0)
		BEGIN
			SELECT @LeaveDay = COUNT(1)
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE DATEDIFF(MM, WorkDate, @tmpDate) = 0
				AND EmpId = @EmpId
				AND IsHoliday = 0
				AND IsOffDay = 0
				AND WorkDate >= CAST(@FromDate AS DATETIME)
				AND WorkDate <= CAST(@ToDate AS DATETIME)

			IF (@LeaveDay > 0)
			BEGIN
				INSERT INTO dbo.tmpLeaveBalance (
					EmpId
					,RequestId
					,TotalDays
					,InYear
					,[Status]
					,InMonth
					)
				VALUES (
					@EmpId
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