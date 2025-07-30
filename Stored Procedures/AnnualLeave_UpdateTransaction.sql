/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_UpdateTransaction] @LeaveTransId INT
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATETIME
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@ModifiedDate DATETIME
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013.10.22
Task: update leave transaction and calculate annual leave balance for employee
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @OldDeductDays NUMERIC(18, 1)
		,@OldCreditDays NUMERIC(18, 1)
		,@EmpId INT
		,@CompanyId SMALLINT
        ,@JoinedDate DATE
		,@AnnualLeaveResetTimelineType TINYINT
		,@AnnualLeaveResetTimelineByYear TINYINT = 1
		,@toDateRange DATETIME
		,@fromDateRange DATETIME

	SELECT @EmpId = EmpId
		,@OldDeductDays = ISNULL(DeductDays, 0)
		,@OldCreditDays = ISNULL(CreditDays, 0)
	FROM dbo.LeaveTrans WITH (NOLOCK)
	WHERE LeaveTransId = @LeaveTransId

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
        SET @fromdateRange = DATEFROMPARTS(YEAR(@FromDate), 1, 1)
    END
    ELSE
    BEGIN
        SET @fromDateRange = DATEFROMPARTS(YEAR(@FromDate), MONTH(@JoinedDate), DAY(@JoinedDate))
		
        IF @FromDate < @fromDateRange
        BEGIN
            SET @fromDateRange = DATEADD(YEAR, -1, @fromDateRange)
        END
    END

	SET @toDateRange = DATEADD(DAY, -1, DATEADD(YEAR, 1, @fromDateRange))

	UPDATE dbo.LeaveTrans WITH (ROWLOCK, UPDLOCK)
	SET [Description] = @Description
		,FromDate = @FromDate
		,ToDate = @toDateRange
		,DeductDays = @DeductDays
		,CreditDays = @CreditDays
		,ModifiedDate = @ModifiedDate
		,ModifiedBy = @ModifiedBy
	WHERE LeaveTransId = @LeaveTransId

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK, UPDLOCK)
	SET AnnualLeaveBalance = ISNULL(AnnualLeaveBalance, 0) + @OldDeductDays - @OldCreditDays + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EmpId = @EmpId
END



