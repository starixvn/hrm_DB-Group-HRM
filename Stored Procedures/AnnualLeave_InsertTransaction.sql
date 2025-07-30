/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_InsertTransaction]
(
    @EmpId INT
	,@RequestId INT = NULL
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATETIME
	,@ToDate DATETIME = NULL
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@CreatedDate DATETIME
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-10-29
    Task: record leave transaction and calculate annual leave balance for employee
    DB: bodb_HRM

    Revisions:
        20250429@Tim: get RefResource by CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @CompanyId SMALLINT
        ,@maximumBalanceForLocal SMALLINT
		,@maximumBalanceForExpat SMALLINT
		,@AnnualLeaveResetTimelineType TINYINT
		,@AnnualLeaveResetTimelineByYear TINYINT = 1
		,@JoinedDate DATE

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

	SELECT @JoinedDate = e.JoinedDate
	FROM dbo.Employee AS e WITH (NOLOCK)
	WHERE e.EmpId = @EmpId

	SELECT @maximumBalanceForLocal = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'AnnualLeaveBalanceForLocal'

	SELECT @maximumBalanceForExpat = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'AnnualLeaveBalanceForExpat'

	SET @maximumBalanceForLocal = ISNULL(@maximumBalanceForLocal, 0)
	SET @maximumBalanceForExpat = ISNULL(@maximumBalanceForExpat, 0)

	IF @maximumBalanceForLocal > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsLocal = 1
				AND @CreditDays > @maximumBalanceForLocal
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Local: ' + CAST(@maximumBalanceForLocal AS VARCHAR(2))

		RETURN
	END

	IF @maximumBalanceForExpat > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsLocal = 0
				AND @CreditDays > @maximumBalanceForExpat
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Expat: no rules (only ' + + CAST(@maximumBalanceForExpat AS VARCHAR(2)) + ' ALs a day).'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.Employee WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND ISNULL(ConfirmedDate, GETDATE() - 365) > @FromDate
				AND @CreditDays > 0
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Probation: no annual days.'

		RETURN
	END

	SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

	DECLARE @ToDateValue DATETIME = @ToDate

	IF @ToDate IS NULL
	BEGIN
		-- Try to get ToDate from existing LeaveTrans record
		SELECT @ToDateValue = CASE 
			WHEN @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear THEN DATEFROMPARTS(YEAR(@FromDate), 12, 31)
			ELSE RangeEndDate
		END
		FROM (
			SELECT 
				FromDate,
				ToDate AS RangeEndDate,
				ROW_NUMBER() OVER (ORDER BY FromDate ASC) AS rn
			FROM dbo.LeaveTrans WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND FromDate <= @FromDate
				AND ToDate > @FromDate
				AND CreditDays > 0
				AND RequestId IS NULL
				AND ISNULL(Deleted, 0) = 0
		) AS t
		WHERE rn = 1
	END

	-- Set default ToDate if not found in LeaveTrans
	IF @ToDateValue IS NULL
	BEGIN
		DECLARE @YearEndDate DATE = DATEFROMPARTS(YEAR(@FromDate), 12, 31)
		DECLARE @fromdateRange DATE = DATEFROMPARTS(YEAR(@FromDate), MONTH(@JoinedDate), DAY(@JoinedDate))

		IF @FromDate < @fromdateRange
		BEGIN
			SET @fromdateRange = DATEADD(YEAR, -1, @fromdateRange)
		END

		SET @ToDateValue = CASE 
			WHEN @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear THEN @YearEndDate
			ELSE DATEADD(DAY, -1, DATEADD(YEAR, 1, @fromdateRange))
		END
	END

	INSERT INTO dbo.LeaveTrans (
		EmpId
		,RequestId
		,[Description]
		,FromDate
		,ToDate
		,DeductDays
		,CreditDays
		,Deleted
		,CreatedDate
		,CreatedBy
		)
	VALUES (
		@EmpId
		,@RequestId
		,@Description
		,@FromDate
		,@ToDateValue
		,@DeductDays
		,@CreditDays
		,0
		,@CreatedDate
		,@CreatedBy
		)

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK)
	SET AnnualLeaveBalance = ISNULL(AnnualLeaveBalance, 0) + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EmpId = @EmpId
END