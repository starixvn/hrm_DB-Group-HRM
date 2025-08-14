/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

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
        20250801@Tim: fix bug pending balance = null
        20250813@Jay: change db structure [Redmine: #235678]
	Param's Explanation:
*/
AS
BEGIN
	DECLARE @CompanyId SMALLINT
        ,@LeaveBalanceDay NUMERIC(18, 2)
		,@PendingLeaveDay NUMERIC(18, 2)
		,@MaxMonth INT
		,@CurrentAnnualLeaveCanBeUse NUMERIC(18, 2)
		,@MaxCanBeUseInYear NUMERIC(18, 2)
		,@Today DATE
        ,@AnnualLeaveResetTimelineType TINYINT
        ,@AnnualLeaveResetTimelineByYear TINYINT = 1
        ,@JoinedDate DATE
        ,@serverTimeZone SMALLINT = -4
        ,@clientTimeZone FLOAT
        ,@AnnualLeaveTypeId SMALLINT = 2

    SELECT @CompanyId = CompanyId
        ,@JoinedDate = JoinedDate
    FROM dbo.CompanyEmployee ce WITH (NOLOCK)
        INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
    WHERE EmpId = @EmpId
		AND [Enabled] = 1

    SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

    SELECT @clientTimeZone = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'TimeZone'

    SET @Today = DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), GETDATE()))

	IF YEAR(@Today) = YEAR(@Date)
	BEGIN
		SET @Date = CASE 
				WHEN DATEDIFF(MM, @Date, @Today) > 0 THEN @Today
				ELSE @Date END
	END

    DECLARE @FromDate DATE
        ,@ToDate DATE

	IF @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear
    BEGIN
        SET @FromDate = DATEFROMPARTS(YEAR(@Date), 1, 1)
    END
    ELSE
    BEGIN
        SET @FromDate = DATEFROMPARTS(YEAR(@Date), MONTH(@JoinedDate), DAY(@JoinedDate))

        IF @Date < @FromDate
        BEGIN
            SET @FromDate = DATEADD(YEAR, -1, @FromDate)
        END
    END

    SET @ToDate = DATEADD(YEAR, 1, @FromDate)

    SELECT @LeaveBalanceDay = SUM(ISNULL(CreditDays, 0)) + SUM(ISNULL(ExtraDays, 0)) - SUM(ISNULL(DeductDays, 0))
	FROM dbo.LeaveTrans WITH (NOLOCK)
	WHERE EmpId = @EmpId
		AND FromDate >= @FromDate
        AND (ToDate IS NULL OR ToDate < @ToDate)
		AND ISNULL(Deleted, 0) = 0

    SELECT @PendingLeaveDay = ISNULL(SUM(lr.TotalDays), 0)
    FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
        INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
    WHERE lr.EmpId = @EmpId
        AND lr.LeaveType = @AnnualLeaveTypeId
        AND lr.FromDate >= @FromDate
        AND lr.ToDate < @ToDate
        AND (
			@RequestId IS NULL
			OR r.RequestId != @RequestId
			)
        AND r.CurrentStatus IN (1, 2) -- pending/verified

    SELECT @PendingLeaveDay = ISNULL(@PendingLeaveDay, 0) + ISNULL(SUM(CASE WHEN ldt.IsHalfDay = 1 THEN 0.5 ELSE 1 END), 0)
    FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
        INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
        INNER JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
    WHERE lr.EmpId = @EmpId
        AND lr.LeaveType = 0 -- general leave
        AND ldt.LeaveType = @AnnualLeaveTypeId
        AND lr.FromDate >= @FromDate
        AND lr.ToDate < @ToDate
        AND (
			@RequestId IS NULL
			OR r.RequestId != @RequestId
			)
        AND r.CurrentStatus IN (1, 2) -- pending/verified

	SELECT @MaxCanBeUseInYear = ISNULL(@LeaveBalanceDay, 0) - ISNULL(@PendingLeaveDay, 0)

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

	IF EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsLocal = 1
			)
        AND @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear
	BEGIN
		SELECT @MaxMonth = MAX(InMonth)
		FROM dbo.tmpLeaveBalance WITH (NOLOCK)
		WHERE EmpId = @EmpId
			AND [Status] IN (0, 1)
			AND InYear = YEAR(@Date)
			AND (
				@RequestId IS NULL
				OR RequestId != @RequestId
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
				AND ISNULL(Deleted, 0) = 0

			SELECT @PendingLeaveDay = SUM(ISNULL(tmp.TotalDays, 0))
			FROM dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
				LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON tmp.EmpId = lr.EmpId
				AND tmp.RequestID = lr.RequestId
			WHERE tmp.EmpId = @EmpId
				AND tmp.[Status] = 0
				AND tmp.InYear = YEAR(@Date)
				AND InMonth <= MONTH(@Date)
				AND (
					@RequestId IS NULL
					OR tmp.RequestId != @RequestId
					)

			SELECT @LeaveBalanceDay = ISNULL(@LeaveBalanceDay, 0) - ISNULL(@PendingLeaveDay, 0)

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

	RETURN ISNULL(@LeaveBalanceDay, 0)
END