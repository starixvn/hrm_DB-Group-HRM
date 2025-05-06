/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[fnc_GetAnnualLeaveBalanceByDate] (
	@EmpId INT
	,@Date DATETIME
	,@RequestId BIGINT = NULL
)
RETURNS NUMERIC(18, 2)
/*
	Created:
	Task: get AL balance
	DB: bodb_HRM

	Revisions:
        20250429@Tim: get RefResource by CompanyId
	Param's Explanation:
*/
AS
BEGIN
	DECLARE @CompanyId SMALLINT
        ,@LeaveBalanceDay NUMERIC(18, 2)
		,@OutstandingLeaveDay NUMERIC(18, 2)
		,@MaxMonth INT
		,@CurrentAnnualLeaveCanBeUse NUMERIC(18, 2)
		,@MaxCanBeUseInYear NUMERIC(18, 2)
		,@IsUserHave6DaysAL BIT
		,@Today DATE = GETDATE()

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

	SELECT @IsUserHave6DaysAL = CASE 
			WHEN WorkingDays = 15 THEN 1
			ELSE 0
			END
	FROM dbo.EmployeeSummary WITH (NOLOCK)
	WHERE EmpId = @EmpID

	IF YEAR(@Today) = YEAR(@Date)
	BEGIN
		SET @Date = CASE 
				WHEN DATEDIFF(MM, @Date, @Today) > 0 THEN @Today
				ELSE @Date END
	END

	SELECT @LeaveBalanceDay = SUM(ISNULL(CreditDays, 0)) - SUM(ISNULL(DeductDays, 0))
	FROM dbo.LeaveTrans WITH (NOLOCK)
	WHERE EmpId = @EmpId
		AND YEAR(FromDate) = YEAR(@Date)
		AND ISNULL(Deleted, 0) <> 1

	SELECT @OutstandingLeaveDay = SUM(ISNULL(tmp.TOTALDAYS, 0))
	FROM dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON tmp.EmpId = lr.EmpId
		AND tmp.RequestId = lr.RequestId
	WHERE tmp.EmpId = @EmpId
		AND tmp.[Status] = 0
		AND tmp.InYear = YEAR(@Date)
		AND (
			@RequestId IS NULL
			OR tmp.RequestID <> @RequestId
			)

	SELECT @MaxCanBeUseInYear = ISNULL(@LeaveBalanceDay, 0) - ISNULL(@OutstandingLeaveDay, 0)

	IF EXISTS (
			SELECT 1
			FROM dbo.RefResource WITH (NOLOCK)
			WHERE CompanyId = @CompanyId
                AND RefName = 'LimitUseAnnualLeaveBalance'
				AND Value = '0'
				AND IsActive = 1
			)
	BEGIN
		RETURN ISNULL(@MaxCanBeUseInYear, 0)
	END

	IF @IsUserHave6DaysAL = 1
	BEGIN
		SELECT @MaxCanBeUseInYear = @MaxCanBeUseInYear * 2
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsLocal = 1
			)
	BEGIN
		SELECT @MaxMonth = MAX(InMonth)
		FROM dbo.tmpLeaveBalance WITH (NOLOCK)
		WHERE EmpId = @EmpId
			AND [Status] IN (0, 1)
			AND InYear = YEAR(@Date)
			AND (
				@RequestId IS NULL
				OR RequestID <> @RequestId
				)

		SELECT @MaxMonth = CASE 
				WHEN @MaxMonth > MONTH(@Date) THEN @MaxMonth
				ELSE MONTH(@Date)
				END

		SELECT @CurrentAnnualLeaveCanBeUse = @MaxCanBeUseInYear - 7 + (CASE 
				WHEN @MaxMonth > 7 THEN 7
				ELSE @MaxMonth END
				)

		IF @CurrentAnnualLeaveCanBeUse <= 0
		BEGIN
			SET @LeaveBalanceDay = 0
		END
		ELSE
		BEGIN
			SELECT @LeaveBalanceDay = SUM(ISNULL(CreditDays, 0)) - SUM(ISNULL(DeductDays, 0))
			FROM dbo.LeaveTrans WITH (NOLOCK)
			WHERE EmpID = @EmpID
				AND YEAR(FromDate) = YEAR(@Date)
				AND MONTH(FromDate) <= MONTH(@Date)
				AND ISNULL(Deleted, 0) <> 1

			SELECT @OutstandingLeaveDay = SUM(ISNULL(tmp.TOTALDAYS, 0))
			FROM dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
				LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON tmp.EmpId = lr.EmpId
				AND tmp.RequestID = lr.RequestId
			WHERE tmp.EmpId = @EmpId
				AND tmp.[Status] = 0
				AND tmp.InYear = YEAR(@Date)
				AND InMonth <= MONTH(@Date)
				AND (
					@RequestId IS NULL
					OR tmp.RequestID <> @RequestId
					)

			SELECT @LeaveBalanceDay = ISNULL(@LeaveBalanceDay, 0) - ISNULL(@OutstandingLeaveDay, 0)

			IF @IsUserHave6DaysAL = 1
			BEGIN
				SELECT @LeaveBalanceDay = @LeaveBalanceDay * 2
			END

			SELECT @CurrentAnnualLeaveCanBeUse = @LeaveBalanceDay - 7 + (CASE 
					WHEN MONTH(@Date) > 7 THEN 7
					ELSE MONTH(@Date) END
					)

			IF @CurrentAnnualLeaveCanBeUse <= 0
			BEGIN
				SET @LeaveBalanceDay = 0
			END
			ELSE IF @CurrentAnnualLeaveCanBeUse > @MaxCanBeUseInYear
			BEGIN
				SET @LeaveBalanceDay = @MaxCanBeUseInYear
			END
			ELSE
			BEGIN
				SET @LeaveBalanceDay = @CurrentAnnualLeaveCanBeUse
			END
		END
	END
	ELSE
	BEGIN
		SET @LeaveBalanceDay = @MaxCanBeUseInYear
	END

	IF @IsUserHave6DaysAL = 1
	BEGIN
		SELECT @LeaveBalanceDay = @LeaveBalanceDay / 2.0
	END

	RETURN ISNULL(@LeaveBalanceDay, 0)
END