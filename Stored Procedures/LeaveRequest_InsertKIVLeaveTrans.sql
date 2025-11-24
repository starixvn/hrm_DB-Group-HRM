/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_InsertKIVLeaveTrans] @RequestId BIGINT
AS
/*
Created: Quinn.Vo@20150927
Task: insert kiv temp leave balance.
DB: HRM
Original:

Revisions:
	20150927@Quinn.Vo: insert kiv temp leave balance
	20251120@Mira: insert kiv temp leave balance [Redmine: #244781]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @KIVLeaveDay NUMERIC(18, 2)
		,@KIVLeaveHour INT
		,@KeepInViewByDayLeaveType INT = 10
		,@KeepInViewByHourLeaveType INT = 48
		,@startTime DATETIME = GETDATE()
		,@deductMinutes INT
		,@minutesBalance INT
		,@empId INT
		,@onDate DATE
		,@RequestTransId BIGINT

	IF EXISTS (
			SELECT 1
			FROM dbo.KeepInViewByDayTrans WITH (NOLOCK)
			WHERE Requestid = @RequestId
			)
	BEGIN
		DELETE
		FROM dbo.KeepInViewByDayTrans WITH (ROWLOCK, UPDLOCK)
		WHERE Requestid = @RequestId
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.KeepInViewByHourTrans WITH (NOLOCK)
			WHERE Requestid = @RequestId
			)
	BEGIN
		SELECT @empId = EmpId
			,@onDate = WorkDate
			,@deductMinutes = DeductMinutes
		FROM dbo.KeepInViewByHourTrans WITH (NOLOCK)
		WHERE RequestId = @RequestId

		WHILE @deductMinutes > 0
		BEGIN
			SELECT TOP 1 @deductMinutes = @deductMinutes - CreditMinutes
				,@RequestTransId = RequestId
			FROM dbo.KeepInViewByHourTrans WITH (NOLOCK)
			WHERE EmpId = @empId
				AND WorkDate > DATEADD(DAY, - 1, DATEADD(MONTH, - 1, @onDate))
				AND CreditMinutes > 0
				AND CreditMinutes > MinutesBalance
			ORDER BY WorkDate ASC

			IF @deductMinutes >= 0
			BEGIN
				UPDATE dbo.KeepInViewByHourTrans WITH (ROWLOCK, UPDLOCK)
				SET MinutesBalance = CreditMinutes
				WHERE RequestId = @RequestTransId
			END
			ELSE
			BEGIN
				UPDATE dbo.KeepInViewByHourTrans WITH (ROWLOCK, UPDLOCK)
				SET MinutesBalance = MinutesBalance + CreditMinutes + @deductMinutes
				WHERE RequestId = @RequestTransId
			END
		END

		DELETE
		FROM dbo.KeepInViewByHourTrans WITH (ROWLOCK, UPDLOCK)
		WHERE RequestId = @RequestId
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.LeaveRequestDetail WITH (NOLOCK)
			WHERE RequestId = @RequestId
			)
	BEGIN
		SELECT @KIVLeaveDay = SUM(CASE 
					WHEN LeaveType = @KeepInViewByDayLeaveType THEN CASE 
							WHEN IsHalfDay = 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@KIVLeaveHour = SUM(CASE 
					WHEN LeaveType = @KeepInViewByHourLeaveType THEN DATEDIFF(MI, FromTime, ToTime)
					ELSE 0
					END)
		FROM dbo.LeaveRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
	END
	ELSE IF EXISTS (
			SELECT 1
			FROM dbo.LeaveRequest WITH (NOLOCK)
			WHERE RequestId = @RequestId
				AND LeaveType = @KeepInViewByDayLeaveType
			)
	BEGIN
		SELECT @KIVLeaveDay = TotalDays
		FROM dbo.LeaveRequest WITH (NOLOCK)
		WHERE RequestId = @RequestId
			AND LeaveType = @KeepInViewByDayLeaveType
	END

	IF ISNULL(@KIVLeaveDay, 0) > 0
	BEGIN
		SELECT @onDate = lr.ToDate,
			@empId = lr.EmpId
		FROM dbo.LeaveRequest lr WITH (NOLOCK)
		WHERE Requestid = @RequestId

		DECLARE @KIVBalanceLastYear NUMERIC(18, 2) = dbo.fnc_GetKIVByDayBalance(@empId, DATEADD(YEAR, -1, @onDate), @RequestId, 0);
		INSERT INTO dbo.KeepInViewByDayTrans (
			[EmpId]
			,[RequestId]
			,[CreditDays]
			,[DeductDays]
			,[InYear]
			,[InsertedDate]
			)
		SELECT @empId
			,@RequestId
			,0
			,ISNULL(@KIVLeaveDay, 0)
			,CASE 
				WHEN @KIVBalanceLastYear > 0 
					THEN YEAR(@onDate) - 1 -- Priority deduction of last year's balance
				ELSE YEAR(@onDate)
			END
			,@startTime		
	END

	IF ISNULL(@KIVLeaveHour, 0) > 0
	BEGIN
		INSERT INTO dbo.KeepInViewByHourTrans (
			EmpId
			,WorkDate
			,RequestId
			,CreditMinutes
			,DeductMinutes
			,InsertedDate
			,MinutesBalance
			)
		SELECT EmpId
			,ldt.OnDate
			,@RequestId
			,0
			,DATEDIFF(MI, ldt.FromTime, ldt.ToTime)
			,@startTime
			,0
		FROM dbo.LeaveRequestDetail ldt WITH (NOLOCK)
		WHERE Requestid = @RequestId

		SELECT @empId = EmpId
			,@onDate = WorkDate
			,@deductMinutes = DeductMinutes
		FROM dbo.KeepInViewByHourTrans WITH (NOLOCK)
		WHERE RequestId = @RequestId

		WHILE @deductMinutes > 0
		BEGIN
			SELECT TOP 1 @deductMinutes = @deductMinutes - MinutesBalance
				,@RequestTransId = RequestId
			FROM dbo.KeepInViewByHourTrans WITH (NOLOCK)
			WHERE EmpId = @empId
				AND WorkDate > DATEADD(DAY, - 1, DATEADD(MONTH, - 1, @onDate))
				AND MinutesBalance > 0
			ORDER BY WorkDate ASC

			IF @deductMinutes >= 0
			BEGIN
				UPDATE dbo.KeepInViewByHourTrans WITH (ROWLOCK, UPDLOCK)
				SET MinutesBalance = 0
				WHERE RequestId = @RequestTransId
			END
			ELSE
			BEGIN
				UPDATE dbo.KeepInViewByHourTrans WITH (ROWLOCK, UPDLOCK)
				SET MinutesBalance = ABS(@deductMinutes)
				WHERE RequestId = @RequestTransId
			END
		END
	END
END
