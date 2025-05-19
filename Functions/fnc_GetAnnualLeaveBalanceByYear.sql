/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[fnc_GetAnnualLeaveBalanceByYear] (
	@EmpID INT
	,@Year INT
	,@RequestId BIGINT = NULL
	)
RETURNS NUMERIC(18, 2)
/*
	Created:
	Task: get AL balance
	DB: bodb_HRM

	Revisions:
*/
AS
BEGIN
    DECLARE @LeaveBalanceDay NUMERIC(18, 2)
        ,@PendingLeaveDay NUMERIC(18, 2)
        ,@CompanyId SMALLINT
        ,@JoinedDate DATE
        ,@AnnualLeaveResetTimelineType TINYINT
        ,@AnnualLeaveResetTimelineByYear TINYINT = 1
        ,@FromDate DATE
        ,@ToDate DATE
        ,@AnnualLeaveTypeId SMALLINT = 2

    SELECT @CompanyId = ce.CompanyId
        ,@JoinedDate = e.JoinedDate
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

    SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

    IF @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear
    BEGIN
        SET @FromDate = DATEFROMPARTS(@Year, 1, 1)
    END
    ELSE
    BEGIN
        SET @FromDate = DATEFROMPARTS(@Year, MONTH(@JoinedDate), DAY(@JoinedDate))
    END

    SET @ToDate = DATEADD(YEAR, 1, @FromDate)

	SELECT @PendingLeaveDay = SUM(lr.TotalDays)
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

    SELECT @PendingLeaveDay = ISNULL(@PendingLeaveDay, 0) + SUM(CASE WHEN ldt.IsHalfDay = 1 THEN 0.5 ELSE 1 END)
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

	SELECT @LeaveBalanceDay = SUM(ISNULL(CreditDays, 0)) + SUM(ISNULL(ExtraDays, 0)) - SUM(ISNULL(DeductDays, 0))
	FROM dbo.LeaveTrans WITH (NOLOCK)
	WHERE EmpId = @EmpId
		AND FromDate >= @FromDate
        AND (ToDate IS NULL OR ToDate < @ToDate)
		AND ISNULL(Deleted, 0) = 0

	SELECT @LeaveBalanceDay = ISNULL(@LeaveBalanceDay, 0) - ISNULL(@PendingLeaveDay, 0)

	RETURN ISNULL(@LeaveBalanceDay, 0)
END