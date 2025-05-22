
ALTER TABLE bodb_HRM.dbo.LeaveTrans  
ADD ExtraDays numberic(18,1) NULL
GO

ALTER PROCEDURE [dbo].[AnnualLeave_GetTransByEmp] @EmpId INT
	,@fromDate DATETIME
	,@excludedRequestTrans BIT
AS
/*
Created: Tom.Vo@2013.10.22
Task: show annual leave tranasaction by employee
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromdateRange DATETIME
		,@todateRange DATETIME
		,@CompanyId SMALLINT
        ,@JoinedDate DATE
		,@AnnualLeaveResetTimelineType TINYINT
		,@AnnualLeaveResetTimelineByYear TINYINT = 1

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
        SET @fromdateRange = DATEFROMPARTS(YEAR(@fromDate), 1, 1)
    END
    ELSE
    BEGIN
        SET @fromdateRange = DATEFROMPARTS(YEAR(@fromDate), MONTH(@JoinedDate), DAY(@JoinedDate))
		
        IF @fromDate < @fromdateRange
        BEGIN
            SET @fromdateRange = DATEADD(YEAR, -1, @fromdateRange)
        END
    END

	SET @todateRange = DATEADD(YEAR, 1, @fromdateRange)
	

	SELECT t.LeaveTransId
		,RequestId
		,FromDate AS AffectedFrom
		,ISNULL(CreditDays, 0) - ISNULL(DeductDays, 0) AS [ToTalDays]
		,[Description]
		,ISNULL(t.ModifiedDate, t.CreatedDate) AS ModifiedDate
	FROM dbo.LeaveTrans t WITH (NOLOCK)
		INNER JOIN dbo.Employee e WITH (NOLOCK) ON e.EmpID = t.EmpId
	WHERE FromDate >= @fromdateRange
		AND FromDate < @todateRange
		AND (ISNULL(ExtraDays, 0) = 0 OR (ExtraDays > 0 AND CreditDays > 0))
		AND t.EmpId = @EmpId
		AND ISNULL(Deleted, 0) = 0
		AND (
			@excludedRequestTrans = 0
			OR RequestId IS NULL
			)
END

GO


ALTER PROCEDURE [dbo].[AnnualLeave_InsertMultipleTransactions]
(
    @CompanyId SMALLINT
    ,@EmployeeIds VARCHAR(MAX)
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATE
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013.10.29
    Task: record multiple annual leave transaction and calculate annual leave balance for employee
    DB: bodb_HRM

    Revisions:
        20250429@Tim: add param @CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @maximumBalanceForLocal SMALLINT
		,@maximumBalanceForExpat SMALLINT
		,@AnnualLeaveResetTimelineType TINYINT
		,@AnnualLeaveResetTimelineByYear TINYINT = 1

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

	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT value
	FROM STRING_SPLIT(@EmployeeIds, ',')

	IF @maximumBalanceForLocal > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS empsum WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON empsum.EmpId = empid.EmployeeId
			WHERE empsum.IsLocal = 1
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
			FROM dbo.EmployeeSummary AS empsum WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON empsum.EmpId = empid.EmployeeId
			WHERE empsum.IsLocal = 0
				AND @CreditDays > @maximumBalanceForExpat
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Expat: no rules (only ' + + CAST(@maximumBalanceForExpat AS VARCHAR(2)) + ' ALs a day).'

		RETURN
	END
	
	IF EXISTS (
			SELECT 1
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
			WHERE ISNULL(emp.ConfirmedDate, GETDATE() - 365) > @FromDate
				AND @CreditDays > 0
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Probation: no annual days.'

		RETURN
	END


	CREATE TABLE #tmpLeaveRange (
		EmpId INT PRIMARY KEY,
		RangeStartDate DATETIME,
		RangeEndDate DATETIME
	)

	SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

	INSERT INTO #tmpLeaveRange (EmpId, RangeStartDate, RangeEndDate)
	SELECT 
		EmpId,
		ISNULL(FromDate, @FromDate) AS RangeStartDate,
		CASE 
			WHEN @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear THEN DATEFROMPARTS(YEAR(@FromDate), 12, 31)
			ELSE ToDate
		END AS RangeEndDate
	FROM (
		SELECT 
			emp.EmpId,
			lt.FromDate,
			lt.ToDate,
			ROW_NUMBER() OVER (PARTITION BY emp.EmpId ORDER BY lt.FromDate ASC) AS rn
		FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
		LEFT JOIN dbo.LeaveTrans AS lt WITH (NOLOCK) ON emp.EmpId = lt.EmpId
			AND lt.FromDate <= @FromDate
			AND lt.ToDate > @FromDate
			AND lt.CreditDays > 0
			AND lt.RequestId IS NULL
			AND ISNULL(lt.Deleted, 0) = 0
	) AS t
	WHERE rn = 1


	UPDATE #tmpLeaveRange
	SET RangeEndDate = DATEADD(DAY, -1, DATEADD(YEAR, 1, RangeStartDate))
	WHERE RangeEndDate IS NULL;


	INSERT INTO dbo.LeaveTrans (
		EmpId
		,[Description]
		,FromDate
		,ToDate
		,DeductDays
		,CreditDays
		,CreatedDate
		,CreatedBy
		)
	SELECT emp.EmpId
		,@Description
		,@FromDate
		,lr.RangeEndDate
		,@DeductDays
		,@CreditDays
		,GETDATE()
		,@ActorId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
		INNER JOIN #tmpLeaveRange AS lr ON emp.EmpId = lr.EmpId
	WHERE ISNULL(emp.isDeleted, 0) = 0


	UPDATE dbo.EmployeeSummary WITH (ROWLOCK)
	SET AnnualLeaveBalance = ISNULL(AnnualLeaveBalance, 0) + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EXISTS (
			SELECT 1
			FROM #tblEmployeeIds
			WHERE EmpId = EmployeeId
			)
	
	DROP TABLE #tblEmployeeIds
	DROP TABLE #tmpLeaveRange
END

GO


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

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
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

	IF @ToDateValue IS NULL
	BEGIN
		SET @ToDateValue = DATEADD(DAY, -1, DATEADD(YEAR, 1, @FromDate))
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

GO



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

GO


CREATE PROCEDURE [dbo].[Report_LeaveSummaryForJoinedDate] 
(
    @CompanyId INT
    ,@empId INT = NULL
	,@TeamIds VARCHAR(max) = ''
	,@fromDate DATETIME
	,@isLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@role VARCHAR(max) = ''
)
AS
/*
	Created: Hank.Nguyen@2025-05-15
	Task: Separate AL and Extra leave
	DB: bodb_HRM

	Revisions:
	    20250515@Hank: Separate AL and Extra leave
	    20250516@Hank: Modified to get active range (ToDate > @fromDate)
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpTeam (GroupId INT)

	CREATE TABLE #tmpEmployee (EmpId INT PRIMARY KEY)

	-- Create temp table for storing employee leave ranges
	CREATE TABLE #tmpLeaveRange (
		EmpId INT PRIMARY KEY,
		RangeStartDate DATETIME,
		RangeEndDate DATETIME
	)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empId IS NULL
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		SELECT DISTINCT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 0, @CompanyId)
	END
	ELSE
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		VALUES (@empId)
	END

	-- Get leave ranges for each employee
	INSERT INTO #tmpLeaveRange (EmpId, RangeStartDate, RangeEndDate)
	SELECT 
		e.EmpId,
		CASE 
			WHEN DATEFROMPARTS(YEAR(@fromDate), MONTH(e.JoinedDate), DAY(e.JoinedDate)) < @fromDate
			THEN DATEFROMPARTS(YEAR(@fromDate), MONTH(e.JoinedDate), DAY(e.JoinedDate))
			ELSE DATEFROMPARTS(YEAR(@fromDate) - 1, MONTH(e.JoinedDate), DAY(e.JoinedDate))
		END AS RangeStartDate,
		DATEADD(yy, 1, 
			CASE 
				WHEN DATEFROMPARTS(YEAR(@fromDate), MONTH(e.JoinedDate), DAY(e.JoinedDate)) < @fromDate
				THEN DATEFROMPARTS(YEAR(@fromDate), MONTH(e.JoinedDate), DAY(e.JoinedDate))
				ELSE DATEFROMPARTS(YEAR(@fromDate) - 1, MONTH(e.JoinedDate), DAY(e.JoinedDate))
			END
		) AS RangeEndDate
	FROM dbo.Employee e WITH (NOLOCK)
	WHERE e.EmpId IN (SELECT EmpId FROM #tmpEmployee)


	-- calculate the balance for the current range
	SELECT e.EmpId
		,ISNULL(CreditDays, 0) AS CreditDays
		,ISNULL(ExtraDays, 0) AS ExtraDays
		,SUM(ISNULL(DeductDays, 0)) AS DeductDays
		,MIN(cred.FromDate) AS FromDate
	INTO #tmpCurrenBalace
	FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN #tmpEmployee AS tmpe WITH (NOLOCK) ON tmpe.EmpId = e.EmpId
        INNER JOIN #tmpTeam AS t WITH (NOLOCK) ON e.GroupId = t.GroupId
		LEFT JOIN (
		SELECT ltrans.EmpId
			,ltrans.DeductDays
			,ltrans.FromDate
		FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
            INNER JOIN #tmpEmployee AS tmpe WITH (NOLOCK) ON tmpe.EmpId = ltrans.EmpId
		WHERE ltrans.FromDate >= (SELECT RangeStartDate FROM #tmpLeaveRange WHERE EmpId = ltrans.EmpId)
			AND ltrans.ToDate <= (SELECT RangeEndDate FROM #tmpLeaveRange WHERE EmpId = ltrans.EmpId)
			AND ISNULL(ltrans.Deleted, 0) = 0
		) AS ded ON e.EmpId = ded.EmpId
		LEFT JOIN (
		SELECT ltrans.EmpId
			,SUM(ltrans.CreditDays) AS CreditDays
			,MIN(ltrans.FromDate) AS FromDate
		FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
            INNER JOIN #tmpEmployee AS tmpe WITH (NOLOCK) ON tmpe.EmpId = ltrans.EmpId
		WHERE ltrans.FromDate >= (SELECT RangeStartDate FROM #tmpLeaveRange WHERE EmpId = ltrans.EmpId)
			AND ltrans.ToDate <= (SELECT RangeEndDate FROM #tmpLeaveRange WHERE EmpId = ltrans.EmpId)
			AND ISNULL(ltrans.Deleted, 0) <> 1
			AND ltrans.CreditDays > 0
		GROUP BY ltrans.EmpId
		) cred ON e.EmpId = cred.Empid
		LEFT JOIN (
		SELECT ltrans.EmpId
			,SUM(ltrans.ExtraDays) AS ExtraDays
			,MIN(ltrans.FromDate) AS FromDate
		FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
            INNER JOIN #tmpEmployee AS tmpe WITH (NOLOCK) ON tmpe.EmpId = ltrans.EmpId
		WHERE ltrans.FromDate >= (SELECT RangeStartDate FROM #tmpLeaveRange WHERE EmpId = ltrans.EmpId)
			AND ltrans.ToDate <= (SELECT RangeEndDate FROM #tmpLeaveRange WHERE EmpId = ltrans.EmpId)
			AND ISNULL(ltrans.Deleted, 0) <> 1
			AND ltrans.ExtraDays > 0
		GROUP BY ltrans.EmpId
		) extra ON e.EmpId = extra.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			ISNULL(e.isDeleted, 0) = 0
			OR YEAR(e.ResignedDate) >= YEAR(@fromDate)
			)
	GROUP BY e.EmpId
		,ISNULL(CreditDays, 0)
		,ISNULL(ExtraDays, 0)

	
	-- show the report
	SELECT ISNULL(CreditDays, 0) AS [AnnualLeaveCurrentYear]
		,ISNULL(ExtraDays, 0) AS ExtraLeave
		,ISNULL(DeductDays, 0) AS DeductDays
		,ISNULL(CreditDays, 0) + ISNULL(ExtraDays, 0) - ISNULL(cb.DeductDays, 0) AS LeaveBalance
		,e.JoinedDate as FromDate
		,'' AS Remark
		,cb.EmpId
		,e.Code
		,FullName
		,Email
		,NickName
		,g.[Rank]
		,g.GroupId AS TeamId
		,g.[Name] AS Team
		,dep.[Name] AS Department
	FROM #tmpCurrenBalace AS cb
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = cb.Empid
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId

	WHERE ISNULL(e.[Enabled], 0) = 1
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
	ORDER BY g.[Name]
		,e.[Code]
	

    DROP TABLE #tmpEmployee
	DROP TABLE #tmpCurrenBalace
	DROP TABLE #tmpTeam
	DROP TABLE #tmpLeaveRange
END

GO


CREATE OR ALTER FUNCTION [dbo].[fnc_GetAnnualLeaveBalance]
(
    @EmpId INT
    ,@Date DATE
    ,@RequestId BIGINT = NULL
)
RETURNS NUMERIC(18, 2)
/*
	Created: 20250520@Tim
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
GO

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

    SELECT @CompanyId = ce.CompanyId
        ,@JoinedDate = e.JoinedDate
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

    SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

    SELECT @clientTimeZone = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'TimeZone'

    SET @AnnualLeaveResetTimelineType = ISNULL(@AnnualLeaveResetTimelineType, @AnnualLeaveResetTimelineByYear)
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

GO



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

GO


ALTER PROCEDURE [dbo].[Employee_GetEmployeeByID] @EmpId INT
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get employee by id
    DB: bodb_HRM

    Revisions:
        03062023@Otis: get field ResignedReason
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @KIVLeaveBalance NUMERIC(18, 2)
		,@AnnualLeaveBalance NUMERIC(18, 2)
		,@Today DATE = GETDATE()

	SELECT @KIVLeaveBalance = dbo.fnc_GetKIVByDayBalance(@EmpID, @Today, NULL)
		,@AnnualLeaveBalance = dbo.fnc_GetAnnualLeaveBalance(@EmpId, @Today, NULL)

	SELECT e.EmpId
		,e.UserId
		,e.Code
		,e.DomainUsername
		,e.FullName
		,e.NickName
		,e.EmployeeCard
		,e.DOB AS DateOfBirth
		,e.Email
		,e.[Enabled]
		,e.Phone
		,e.Gender
		,e.TeamDate
		,e.PromotionDate
		,e.JoinedDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.ResignedReason
		,empsum.CompanyDate
		,empsum.WorkingDays
		,empsum.WorkingHours
		,empsum.MilitaryFromDate
		,empsum.MilitaryToDate
		,empsum.WorkingHoursByWeek
		,e.Skype
		,e.LetsTalk
		,e.Marriage
		,e.LastLogin
		,@AnnualLeaveBalance AS AnnualLeaveBalance
		,@KIVLeaveBalance AS KeepInViewBalance
		,empsum.CountryCode
		,ct.CountryName
		,empsum.CanOT
		,empsum.SpecialOT
		,empsum.IsLocal
		,empsum.IsExpatUseHoliday
		,e.CreatedDate
		,e.CreatedBy
		,e.ModifiedDate
		,e.ModifiedBy
		,e.isDeleted
		,e.PermanentAddress AS [Address]
		,e.CurrentAddress
		,e.IdCardNumber AS CardNo
		,e.PassportNo
		,e.PassportExp
		,e.[Password]
		,e.ChineseName
		,empsum.IsDefaultSchedule
		,empsum.IsTopManager
		,empsum.OffDaysbyWeek
		,empsum.Unit
		,e.PlaceOfbirth
		,e.Ethnic
		,e.[Native]
		,e.Religion
		,e.DateOfIDCard
		,e.PlaceOfIDCard
		,e.HomePhone
		,e.Qualification
		,e.Major
		,e_cs.[BankAccount]
		,e_cs.[TaxCode]
		,e_cs.[SocialInsuranceNo]
		,e_cs.[RegisteredHospital]
		,e_cs.[Contract1]
		,e_cs.[FromDate1]
		,e_cs.[ToDate1]
		,e_cs.[Contract2]
		,e_cs.[FromDate2]
		,e_cs.[ToDate2]
		,e_cs.[Contract3]
		,e_cs.[FromDate3]
		,e_cs.[ToDate3]
		,e_cs.[Contract4]
		,e_cs.[FromDate4]
		,e_cs.[ToDate4]
		,e_cs.[Contract5]
		,e_cs.[FromDate5]
		,e_cs.[ToDate5]
		,e_cs.History
		,e.PasswordReset
		,e.PickupRemark
		,e.JobTitleId
		,e.ExpertGradeId
		,e.JobLevelId
		,lk.[Name] AS JobTitle
		,ISNULL(e.GroupId, - 1) AS [TeamId]
		,g.Code
		,g.[Name]
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = e.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.EmployeeContract AS e_cs WITH (NOLOCK) ON e_cs.EmpId = e.EmpId
		LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON empsum.CountryCode = ct.CountryCode
		LEFT JOIN dbo.LookupData AS lk WITH (NOLOCK) ON e.JobTitleId = lk.Id
		AND lk.LookupId = 1
	WHERE e.EmpId = @EmpId
END
GO

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsert]
(
    @empId INT = NULL
	,@fromTime DATETIME
	,@toTime DATETIME
	,@onlyUpdate BIT = 0
    ,@CompanyId SMALLINT = NULL
)
AS
/*
    Created:
    Task:
    DB: bodb_HRM

    Revisions:
        20250519@Tim: remove check JoinedDate

*/
BEGIN
	SET XACT_ABORT ON;

	DECLARE @i INT
		,@TempEmpId INT
		,@tempFromDate DATE = @fromTime
		,@tempToDate DATE = @toTime
		,@today DATE = GETDATE()
        ,@serverTimeZone SMALLINT = -4
	DECLARE @tblDateRange TABLE (WorkDate DATE)
	CREATE TABLE #tmpEmployee (Id INT PRIMARY KEY IDENTITY(1, 1), EmpId INT)

	IF @tempToDate > @today
	BEGIN
		SET @tempToDate = @today
	END

	WHILE @tempFromDate <= @tempToDate
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM @tblDateRange
				WHERE WorkDate = @tempFromDate
				)
		BEGIN
			INSERT INTO @tblDateRange (WorkDate)
			VALUES (@tempFromDate)
		END

		SET @tempFromDate = DATEADD(DAY, 1, @tempFromDate)
	END

	IF EXISTS (
			SELECT EmpId
			FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
				LEFT JOIN @tblDateRange AS tbldate ON empca.WorkDate = tbldate.WorkDate
			WHERE (
					@empId IS NULL
					OR EmpId = @empId
					)
				AND tbldate.WorkDate IS NULL
			)
	BEGIN
		DECLARE @ErrCode INT = 0
			,@ErrMsg VARCHAR(200) = ''

		EXEC dbo.EmployeeCalendar_Insert @EmpId = @empId
			,@fromdate = @fromTime
			,@todate = @tempToDate
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END

	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpTimeRecord'
			)
	BEGIN
		DROP TABLE #tmpTimeRecord
	END

	CREATE TABLE #tmpTimeRecord (
		Id INT
		,EmpId INT
		,RecordTime DATETIME
		,InOutType TINYINT
		)

	-- Get all in/out data into temp table to calculate
	INSERT INTO #tmpTimeRecord (
		Id
		,EmpId
		,RecordTime
		,InOutType
		)
	SELECT tr.Id
		,tr.EmpId
		,tr.RecordTime
		,tr.InOutType
	FROM dbo.TimeRecord AS tr WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tr.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND DATEADD(MINUTE, CAST(ISNULL(config.Value, @serverTimeZone) AS REAL) * 60, DATEADD(HOUR, ABS(@serverTimeZone), tr.RecordTime))
            BETWEEN DATEADD(HH, - 2, CONVERT(VARCHAR(10), @fromTime, 111)) AND DATEADD(d, 2, CONVERT(VARCHAR(10), @toTime, 111))
		--AND emp.JoinedDate <= CAST(tr.RecordTime AS DATE)
		AND (
			@empId IS NULL
			OR tr.EmpId = @empId
			)

	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpLeaveRequestHalfDay'
			)
	BEGIN
		DROP TABLE #tmpLeaveRequestHalfDay
	END

	CREATE TABLE #tmpLeaveRequestHalfDay (
		EmpId INT
		,OnDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		)

	-- Get all leave request half day
	INSERT INTO #tmpLeaveRequestHalfDay (
		EmpId
		,OnDate
		,FromTime
		,ToTime
		)
	SELECT lv.EmpId
		,lv.OnDate
		,FromTime
		,ToTime
	FROM dbo.LeaveRequestDetail AS lv WITH (NOLOCK)
		INNER JOIN (
		SELECT ldt.empId
			,OnDate
		FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			INNER JOIN dbo.WorkingTimeRequest AS wrq WITH (NOLOCK) ON ldt.RequestId = wrq.RequestId
		WHERE WorkType = 2
			AND IsHalfDay = 1 -- 2: leave, 1: Half day
			AND OnDate BETWEEN CONVERT(VARCHAR(10), @fromTime, 111)
				AND CONVERT(VARCHAR(10), DATEADD(d, 2, @toTime), 111)
			AND (
				@empId IS NULL
				OR ldt.EmpId = @empId
				)
			AND wrq.CurrentStatus IN (4, 6)
		GROUP BY ldt.empId
			,OnDate
		HAVING COUNT(*) = 1
		) a ON a.EmpId = lv.EmpId
			AND a.OnDate = lv.OnDate
		INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON lv.RequestId = rq.RequestId
	WHERE lv.IsHalfDay = 1
		AND (
			@empId IS NULL
			OR lv.EmpId = @empId
			)
		AND rq.CurrentStatus IN (4, 6)

	-- Get all calendars of employees into temp table
	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpEmpCalendar'
			)
	BEGIN
		DROP TABLE #tmpEmpCalendar
	END

	CREATE TABLE #tmpEmpCalendar (
		Id INT PRIMARY KEY IDENTITY(1, 1)
		,EmpId INT
		,WorkDate DATETIME
		,ShiftId INT
		,IsHoliday BIT
		,IsOffDay BIT
		,IsLeaveDay BIT
		,LeaveTypeId INT NULL
		,IsKeepInView BIT
		,LateIn INT
		,EarlyOut INT
		,RequestedCheckInTime DATETIME
		,RequestedCheckOutTime DATETIME
		,BeginCheckInTime DATETIME
		,EndCheckInTime DATETIME
		,BeginCheckOutTime DATETIME
		,EndCheckOutTime DATETIME
		,BreakTimeMins INT
		,LeaveDay DECIMAL(18, 1)
		)

	INSERT INTO #tmpEmpCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsHoliday
		,IsOffDay
		,IsLeaveDay
		,LeaveTypeId
		,IsKeepInView
		,LateIn
		,EarlyOut
		,RequestedCheckInTime
		,RequestedCheckOutTime
		,BeginCheckInTime
		,EndCheckInTime
		,BeginCheckOutTime
		,EndCheckOutTime
		,BreakTimeMins
		,LeaveDay
		)
	SELECT ec.EmpId
		,ec.WorkDate
		,ec.ShiftId
		,ec.IsHoliday
		,ec.IsOffDay
		,ec.IsLeaveDay
		,ec.LeaveTypeId
		,ec.IsKeepInView
		,ec.LateIn
		,ec.EarlyOut
		,ec.RequestedCheckinTime
		,ec.RequestedCheckoutTime
		,CASE 
			WHEN IsInAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS BeginCheckInTime
		,CASE 
			WHEN IsInAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS EndCheckInTime
		,CASE 
			WHEN IsOutAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.BeginCheckOutTime)
			ELSE CAST(WorkDate + ' ' + s.BeginCheckOutTime AS DATETIME)
			END AS BeginCheckOutTime
		,CASE 
			WHEN IsOutAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckOutTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckOutTime AS DATETIME)
			END AS EndCheckOutTime
		,BreakTimeMins
		,LeaveDay
	FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ec.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ec.ShiftId
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
        AND (
			@EmpId IS NULL
			OR emp.EmpId = @EmpId
			)
        AND (
			@CompanyId IS NULL
			OR ce.CompanyId = @CompanyId
			)
		AND ec.WorkDate BETWEEN @FromTime
			AND @ToTime
	ORDER BY ec.EmpId
		,ec.WorkDate

    -- convert to server time zone
    UPDATE empca
    SET empca.BeginCheckInTime = CASE WHEN empca.BeginCheckInTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.BeginCheckInTime) END
        ,empca.EndCheckInTime = CASE WHEN empca.EndCheckInTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.EndCheckInTime) END
        ,empca.BeginCheckOutTime = CASE WHEN empca.BeginCheckOutTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.BeginCheckOutTime) END
        ,empca.EndCheckOutTime = CASE WHEN empca.EndCheckOutTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.EndCheckOutTime) END
    FROM #tmpEmpCalendar AS empca WITH (ROWLOCK)
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'

	IF @empId IS NULL
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		SELECT e.EmpId
		FROM dbo.Employee AS e WITH (NOLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
		WHERE e.[Enabled] = 1
		    AND e.isDeleted = 0
            AND (
			    @CompanyId IS NULL
			    OR ce.CompanyId = @CompanyId
			)
			AND EXISTS (
				SELECT 1
				FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
				WHERE DATEDIFF(DD, @fromTime, cl.WorkDate) >= 0
					AND DATEDIFF(DD, WorkDate, @toTime) >= 0
					AND e.EmpId = cl.EmpId
				)

		SET @i = 1

		WHILE EXISTS (
				SELECT 1
				FROM #tmpEmployee WITH (NOLOCK)
				WHERE Id = @i
				)
		BEGIN
			SELECT @TempEmpId = EmpId
			FROM #tmpEmployee WITH (NOLOCK)
			WHERE Id = @i

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForEmpId @TempEmpId
				,@fromTime
				,@toTime
				,@onlyUpdate

			SET @i = @i + 1
		END

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForWorkDay @empId
			,@fromTime
			,@toTime
	END
	ELSE
	BEGIN
		EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForEmpId @EmpId
			,@fromTime
			,@toTime
			,@onlyUpdate
	END

	EXEC dbo.Discipline_Insert @FromDate = @fromTime
		,@ToDate = @toTime
		,@EmpId = @EmpId

	DROP TABLE #tmpEmployee
    
    DROP TABLE #tmpTimeRecord

	DROP TABLE #tmpEmpCalendar

	DROP TABLE #tmpLeaveRequestHalfDay
END

GO


ALTER PROCEDURE [dbo].[LeaveRequest_GetLeaveBalance]
(
    @EmpId INT
    ,@RequestId BIGINT = NULL
    ,@EffectedDay DATE = NULL
)
AS
/*
    Created: Quinn.Vo@20190417
    Task: Get Avaible Balance Leave From RequestId
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @EffectedDay IS NULL
	BEGIN
		SELECT @EffectedDay = CONVERT(DATETIME, CONVERT(NVARCHAR(10), YEAR(GETDATE())) + '/01/01')
	END

	DECLARE @KIVBalance NUMERIC(18, 2)
		,@KIVByHourBalance NUMERIC(18, 2)
		,@LeaveBalanceDay NUMERIC(18, 2)
		,@CurrenLeaveDay NUMERIC(18, 2)
		,@WeekedLeaveDayTaken NUMERIC(18, 2)
		,@HospitalizationLeaveBalance NUMERIC(18, 2)
		,@SickLeaveBalance NUMERIC(18, 2)

	SELECT @KIVBalance = dbo.fnc_GetKIVByDayBalance(@EmpId, @EffectedDay, @RequestId)
		,@KIVByHourBalance = dbo.fnc_GetKIVByHourBalance(@EmpId, @EffectedDay, @RequestId)
		,@LeaveBalanceDay = dbo.fnc_GetAnnualLeaveBalance(@EmpId, @EffectedDay, @RequestId)
		,@CurrenLeaveDay = dbo.fnc_GetAnnualLeaveBalanceByDate(@EmpId, @EffectedDay, @RequestId)
		,@WeekedLeaveDayTaken = dbo.fnc_GetWeekendLeaveTaken(@EmpId, @EffectedDay, @RequestId)
		,@HospitalizationLeaveBalance = dbo.fnc_GetHospitalizationLeaveBalance(@EmpId, YEAR(@EffectedDay), @RequestId)
		,@SickLeaveBalance = dbo.fnc_GetSickLeaveBalance(@EmpId, YEAR(@EffectedDay), @RequestId)

	SELECT @EmpId AS EmployeeId
		,@LeaveBalanceDay AS AnnualBalance
		,@KIVBalance AS KeepInViewBalance
		,@KIVByHourBalance AS KeepInViewByHourBalance
		,@CurrenLeaveDay AS CurrentLeaveBalanceDay
		,@WeekedLeaveDayTaken AS WeekedLeaveDayTaken
		,@HospitalizationLeaveBalance AS HospitalizationLeaveBalance
		,@SickLeaveBalance AS SickLeaveBalance
END
GO


ALTER PROCEDURE [dbo].[LeaveRequest_Insert]
(
    @EmpId INT
    ,@CompanyId SMALLINT
	,@FromDate DATETIME
	,@ToDate DATETIME
	,@LeaveTypeId INT
	,@TotalDays NUMERIC(5, 1) = NULL
	,@Remark NVARCHAR(2000) = NULL
	,@CreatedBy INT
	,@VerifierId INT = NULL
	,@ApproverId INT = NULL
	,@RefNo NVARCHAR(200) = ''
	,@IsHospitalApplication BIT	= NULL
	,@ListDetail VARCHAR(MAX)
	,@RequestId BIGINT = 0 OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-11-11
    Task: insert a Leave mutilple request form
    DB: bodb_HRM

    Revisions:
        20250423@Tim: fix bug validate request in the same range
    Param's Explanation:
	    - @ListDetail: '<Root><Row OnDate='' ShiftId='' LeaveType='' IsHalfDay='' WorkType='' FromTime='' ToTime='' /></Root>'
	    - @WorkType:
			    1. off
			    2. leave
			    3. work
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @RequestType TINYINT = 6
        ,@AnnualLeaveType TINYINT = 2
        ,@KIVByDayLeaveType TINYINT = 10
        ,@KIVByHourLeaveType TINYINT = 48
        ,@PublicHolidayLeaveType TINYINT = 13
        ,@PaternityLeaveType TINYINT = 14
        ,@UnpaidLeaveType TINYINT = 25
        ,@UnpaidLeaveInsuranceType TINYINT = 41
        ,@MaternityLeaveType INT = 12
        ,@BusinessTripLeaveType TINYINT = 9
        ,@BusinessDuringWorkingLeaveType TINYINT = 26
        ,@SickLeaveTypeId TINYINT = 29
        ,@HospitalizationLeaveTypeId TINYINT = 39
        ,@OnbehalfActionType TINYINT = 5
        ,@VerifyActionType TINYINT = 2
        ,@ApproveActionType TINYINT = 3
        ,@LeaveWorkType TINYINT = 2
        ,@IsTopManager BIT
        ,@IsLocal BIT
        ,@AnnualLeaveDay DECIMAL(18, 2)
        ,@SickLeaveDay DECIMAL(18, 2)
        ,@HospitalizationLeaveDay DECIMAL(18, 2)
        ,@KIVLeaveDay DECIMAL(18, 2)
        ,@KIVLeaveMinutes INT
        ,@TotalDays_tmp NUMERIC(5, 1)
        ,@IsHalfDay BIT
        ,@CreatedDate DATETIME = GETDATE()
        ,@TmpFromDate DATE
        ,@TmpToDate DATE
        ,@DocHandler INT
        ,@TotalDaysPaternity INT
        ,@BalanceDaysPaternity INT
        ,@JoinedDate DATE
        ,@AnnualLeaveResetTimelineType TINYINT
        ,@AnnualLeaveResetTimelineByYear TINYINT = 1

	CREATE TABLE #tblLeaveRequestDetail (
		OnDate DATE
		,ShiftId INT
		,LeaveType INT
		,WorkType TINYINT
		,IsHalfDay BIT
		,FromTime DATETIME
		,ToTime DATETIME
		)

    SELECT @JoinedDate = JoinedDate
	FROM dbo.Employee AS e WITH (NOLOCK)
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
	WHERE e.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId

    SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

	SELECT @isHalfDay = CASE 
			WHEN @TotalDays = 0.5 THEN 1
			ELSE 0
			END
		,@TotalDays_tmp = @TotalDays
		,@TmpFromDate = CAST(@FromDate AS DATE)
		,@TmpToDate = CAST(@ToDate AS DATE)

	IF @FromDate IS NULL
		OR @ToDate IS NULL
		OR @LeaveTypeID IS NULL
		OR ISNULL(@TotalDays, 0) < 0
	BEGIN
		SET @ErrCode = 104
		SET @ErrMsg = 'Invalid parameter'

		RETURN;
	END

	IF CAST(@FromDate AS DATE) < @JoinedDate
	BEGIN
		SET @ErrCode = 120
		SET @ErrMsg = 'You can not request leave earlier than your joined date.'

		RETURN
	END

	IF @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear
        AND YEAR(@FromDate) != YEAR(@ToDate)
	BEGIN
		SET @ErrCode = 103
		SET @ErrMsg = 'You cannot submit a cross-year leave request. Please split it into 2 separate requests.'

		RETURN;
	END

    IF @AnnualLeaveResetTimelineType != @AnnualLeaveResetTimelineByYear
        AND DATEFROMPARTS(YEAR(@FromDate), MONTH(@JoinedDate), DAY(@JoinedDate)) >= @FromDate
        AND DATEFROMPARTS(YEAR(@ToDate), MONTH(@JoinedDate), DAY(@JoinedDate)) < @ToDate
	BEGIN
		SET @ErrCode = 103
		SET @ErrMsg = 'You cannot submit a cross-leave request based on your Group Date. Please split it into 2 separate requests.'

		RETURN;
	END

	IF @EmpId <> @CreatedBy
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSupervisor WITH (NOLOCK)
			WHERE OwnerId = @EmpId
				AND EmpId = @CreatedBy
				AND ActionType = @OnbehalfActionType
				AND RequestType = @RequestType
				AND ISNULL(IsDeleted, 0) = 0
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
				INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
			WHERE e.EmpId = @EmpId
				AND g.OwnerId = @CreatedBy
				AND g.RequestType = @RequestType
				AND g.ActionType = @OnbehalfActionType
				AND ISNULL(g.IsDeleted, 0) = 0
			)
	BEGIN
		SET @ErrCode = 106
		SET @ErrMsg = 'You have not on behalf permision on this employee.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsTopManager = 1
			)
	BEGIN
		SET @IsTopManager = 1
	END
	ELSE
	BEGIN
		IF @VerifierId IS NULL
			OR (
				NOT EXISTS (
					SELECT 1
					FROM dbo.EmployeeSupervisor WITH (NOLOCK)
					WHERE OwnerId = @VerifierId
						AND EmpId = @EmpId
						AND ActionType = @VerifyActionType
						AND RequestType = @RequestType
						AND ISNULL(IsDeleted, 0) = 0
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
					WHERE e.EmpId = @EmpId
						AND g.OwnerId = @VerifierId
						AND g.RequestType = @RequestType
						AND g.ActionType = @VerifyActionType
						AND ISNULL(g.IsDeleted, 0) = 0
					)
				)
		BEGIN
			SET @ErrCode = 108
			SET @ErrMsg = 'Invalid Verifier.'

			RETURN;
		END

		IF @ApproverId IS NULL
			OR (
				NOT EXISTS (
					SELECT 1
					FROM dbo.EmployeeSupervisor WITH (NOLOCK)
					WHERE OwnerId = @ApproverId
						AND EmpId = @EmpId
						AND ActionType = @ApproveActionType
						AND RequestType = @RequestType
						AND ISNULL(IsDeleted, 0) = 0
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
					WHERE e.EmpId = @EmpId
						AND g.OwnerId = @ApproverId
						AND g.RequestType = @RequestType
						AND g.ActionType = @ApproveActionType
						AND ISNULL(g.IsDeleted, 0) = 0
					)
				)
		BEGIN
			SET @ErrCode = 109
			SET @ErrMsg = 'Invalid Approver.'

			RETURN;
		END
	END

	IF @LeaveTypeId <> @PublicHolidayLeaveType
		AND @TotalDays = 0.5
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE EmpID = @EmpId
				AND WorkDate = @FromDate
				AND (
					IsHoliday = 1
					OR IsOffDay = 1
					)
			)
	BEGIN
		SET @ErrCode = 105
		SET @ErrMsg = 'Your can not request on off day or holiday.'

		RETURN;
	END

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@ListDetail

		IF DATEDIFF(DD, @FromDate, @ToDate) + 1 <> (
				SELECT COUNT(1)
				FROM dbo.EmployeeCalendar WITH (NOLOCK)
				WHERE EmpID = @EmpID
					AND WorkDate BETWEEN @TmpFromDate
						AND @TmpToDate
				)
		BEGIN
			EXEC dbo.EmployeeCalendar_Insert @EmpId = @EmpId
				,@fromdate = @TmpFromDate
				,@todate = @TmpToDate
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END

		INSERT INTO #tblLeaveRequestDetail (
			OnDate
			,ShiftId
			,LeaveType
			,WorkType
			,IsHalfDay
			,FromTime
			,ToTime
			)
		SELECT d.OnDate
			,ISNULL(d.ShiftId, ec.ShiftId) AS ShiftId
			,d.LeaveType
			,d.WorkType
			,d.IsHalfDay
			,d.FromTime
			,d.ToTime
		FROM OPENXML(@DocHandler, '/ROOT/Row', 1) WITH (OnDate DATETIME, ShiftId INT, LeaveType INT, IsHalfDay BIT, WorkType TINYINT, FromTime DATETIME, ToTime DATETIME) AS d
			LEFT JOIN dbo.EmployeeCalendar ec WITH (NOLOCK) ON ec.WorkDate = d.OnDate
			AND ec.EmpId = @EmpId

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH;

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
			GROUP BY OnDate
			HAVING COUNT(DISTINCT LeaveType) = 1
				AND COUNT(OnDate) > 1
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Please check Leave Type on this request.'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			)
	BEGIN
		SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay
					WHEN 1 THEN 0.5
					ELSE 1
					END)
		FROM dbo.EmployeeCalendar cl WITH (NOLOCK)
			INNER JOIN #tblLeaveRequestDetail lrd WITH (NOLOCK) ON cl.WorkDate = lrd.OnDate
		WHERE EmpID = @EmpID
			AND WorkDate BETWEEN @TmpFromDate
				AND @TmpToDate
			AND IsHoliday = 0
			AND IsOffDay = 0
			AND IsLeaveDay = 0
			AND lrd.WorkType = @LeaveWorkType

		IF @TotalDays_tmp IS NULL
		BEGIN
			SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay
						WHEN 1 THEN 0.5
						ELSE 1
						END)
			FROM #tblLeaveRequestDetail lrd WITH (NOLOCK)
			WHERE lrd.WorkType = @LeaveWorkType
		END

		SELECT @AnnualLeaveDay = SUM(CASE 
					WHEN LeaveType = @AnnualLeaveType THEN CASE 
							WHEN IsHalfDay = 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@SickLeaveDay = SUM(CASE 
					WHEN LeaveType = @SickLeaveTypeId THEN CASE 
							WHEN IsHalfDay = 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@HospitalizationLeaveDay = SUM(CASE 
					WHEN LeaveType = @HospitalizationLeaveTypeId THEN CASE 
							WHEN IsHalfDay = 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@KIVLeaveDay = SUM(CASE 
					WHEN LeaveType = @KIVByDayLeaveType THEN CASE IsHalfDay
							WHEN 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@KIVLeaveMinutes = SUM(CASE 
					WHEN LeaveType = @KIVByHourLeaveType THEN DATEDIFF(MI, FromTime, ToTime)
					ELSE 0
					END)
		FROM #tblLeaveRequestDetail WITH (NOLOCK)
	END
	ELSE
	BEGIN
		IF @isHalfDay = 1
			AND ISNULL(@TotalDays_tmp, 1) = 1
		BEGIN
			SET @TotalDays_tmp = 0.5
		END

		IF @LeaveTypeId = @AnnualLeaveType
		BEGIN
			SELECT @AnnualLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @SickLeaveTypeId
		BEGIN
			SELECT @SickLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @HospitalizationLeaveTypeId
		BEGIN
			SELECT @HospitalizationLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @KIVByDayLeaveType
		BEGIN
			SELECT @KIVLeaveDay = @TotalDays
		END
	END

	IF ISNULL(@TotalDays_tmp, 0) <= 0
		AND @LeaveTypeID <> @PublicHolidayLeaveType
	BEGIN
		SET @ErrCode = 105
		SET @ErrMsg = 'Invalid leave days.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.LeaveRequest AS l WITH (NOLOCK) ON r.RequestId = l.RequestId
			WHERE r.empid = @empid
				AND r.RequestType = @RequestType
				AND r.CurrentStatus IN (1, 2, 4, 6)
				AND (
					(
						NOT EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							WHERE r.RequestId = ldt.RequestId
							)
						AND NOT EXISTS (
							SELECT 1
							FROM #tblLeaveRequestDetail WITH (NOLOCK)
							)
						AND (
							CAST(l.FromDate AS DATE) BETWEEN @TmpFromDate AND @TmpToDate
							OR CAST(l.ToDate AS DATE) BETWEEN @TmpFromDate AND @TmpToDate
							OR @TmpFromDate BETWEEN CAST(l.FromDate AS DATE) AND CAST(l.ToDate AS DATE)
							OR @TmpToDate BETWEEN CAST(l.FromDate AS DATE) AND CAST(l.ToDate AS DATE)
							)
						)
                    OR (
					    NOT EXISTS (
						    SELECT 1
						    FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
                            WHERE r.RequestId = ldt.RequestId
						    )
					    AND EXISTS (
						    SELECT 1
						    FROM #tblLeaveRequestDetail AS ldt WITH (NOLOCK)
						    WHERE ldt.OnDate BETWEEN l.FromDate AND l.ToDate
						    )
					    )
					OR (
						NOT EXISTS (
							SELECT 1
							FROM #tblLeaveRequestDetail WITH (NOLOCK)
							)
						AND EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							WHERE r.RequestId = ldt.RequestId
								AND ldt.OnDate BETWEEN @TmpFromDate AND @TmpToDate
							)
						)
					OR (
						EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
								INNER JOIN #tblLeaveRequestDetail AS ldtt WITH (NOLOCK) ON ldtt.OnDate = ldt.OnDate
							WHERE r.RequestId = ldt.RequestId
								AND (
									(
										ldt.IsHalfDay = 0
										AND ldtt.IsHalfDay = 0
										)
									OR (
										ldt.IsHalfDay = 0
										AND ldtt.IsHalfDay = 1
										AND (
											ldtt.FromTime BETWEEN ldt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldt.ToTime) + 1)
											OR ldtt.ToTime BETWEEN ldt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldt.ToTime) + 1)
											)
										)
									OR (
										ldt.IsHalfDay = 1
										AND ldtt.IsHalfDay = 0
										AND (
											ldt.FromTime BETWEEN ldtt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldtt.ToTime) + 1)
											OR ldt.ToTime BETWEEN ldtt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldtt.ToTime) + 1)
											)
										)
									OR (
										ldt.IsHalfDay = 1
										AND ldtt.IsHalfDay = 1
										AND (
											ldt.FromTime BETWEEN ldtt.FromTime AND ldtt.ToTime
											OR ldt.ToTime BETWEEN ldtt.FromTime AND ldtt.ToTime
											OR ldtt.FromTime BETWEEN ldt.FromTime AND ldt.ToTime
											OR ldtt.ToTime BETWEEN ldt.FromTime AND ldt.ToTime
											)
										)
										AND ldt.FromTime != ldtt.ToTime
										AND ldt.ToTime != ldtt.FromTime
									)
							)
						)
					)
			)
	BEGIN
		SET @ErrCode = 107
		SET @ErrMsg = 'There is another request in the same range.'

		RETURN;
	END

	SELECT @AnnualLeaveDay = ISNULL(@AnnualLeaveDay, 0)

	IF @AnnualLeaveDay > 0
	BEGIN
		IF @AnnualLeaveDay > dbo.fnc_GetAnnualLeaveBalanceByDate(@EmpId, @ToDate, NULL)
		BEGIN
			SET @ErrCode = 108
			SET @ErrMsg = 'Not enough annual leave days to request.'

			RETURN;
		END
	END

	DECLARE @Year INT = YEAR(@ToDate)

	EXEC dbo.LeaveRequest_CheckSickLeaveBalance @EmpId = @EmpId
		,@LeaveDays = @SickLeaveDay
		,@Year = @Year
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT

	IF @ErrCode > 0 RETURN;

	EXEC dbo.LeaveRequest_CheckHospitalizationLeaveBalance @EmpId = @EmpId
		,@LeaveDays = @HospitalizationLeaveDay
		,@Year = @Year
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT

	IF @ErrCode > 0 RETURN;

	SELECT @KIVLeaveDay = ISNULL(@KIVLeaveDay, 0)

	IF @KIVLeaveDay > 0
	BEGIN
		IF @KIVLeaveDay > dbo.fnc_GetKIVByDayBalance(@EmpId, @ToDate, NULL)
		BEGIN
			SET @ErrCode = 111
			SET @ErrMsg = 'Not enough Compensation Leave days to request.'

			RETURN;
		END
	END

	IF @KIVLeaveMinutes > 0
	BEGIN
		IF @KIVLeaveMinutes > dbo.fnc_GetKIVByHourBalance(@EmpId, @FromDate, NULL)
		BEGIN
			SET @ErrCode = 111
			SET @ErrMsg = 'Not enough Compensation Leave hours to request.'

			RETURN;
		END
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
				AND LeaveType IN (@UnpaidLeaveInsuranceType)
			)
	BEGIN
		SET @ErrCode = 112
		SET @ErrMsg = 'This leave type does not support half day.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
				AND LeaveType IN (@AnnualLeaveType, @UnpaidLeaveType, @KIVByDayLeaveType)
				AND DATEDIFF(MINUTE, FromTime, ToTime) > 300
			)
	BEGIN
		SET @ErrCode = 113
		SET @ErrMsg = 'You can not request leave half day over 5 hours.'

		RETURN;
	END

	-- check rule for leave during working hours
	IF @LeaveTypeId = @BusinessDuringWorkingLeaveType
		AND EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
			)
	BEGIN
		IF EXISTS (
				SELECT 1
				FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
					INNER JOIN dbo.LeaveRequest AS lv WITH (NOLOCK) ON lv.RequestId = ldt.RequestId
					AND lv.EmpId = @EmpId
					AND lv.LeaveType = @BusinessDuringWorkingLeaveType
					AND DATEDIFF(MONTH, lv.FromDate, @FromDate) = 0
					INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON wk.RequestId = ldt.RequestId
					AND wk.CurrentStatus IN (1, 2, 4, 6)
				WHERE ldt.IsHalfDay = 1
				)
		BEGIN
			SET @ErrCode = 114
			SET @ErrMsg = 'You had been reached maximum leave during working hours in month.'

			RETURN
		END

		IF EXISTS (
				SELECT 1
				FROM #tblLeaveRequestDetail WITH (NOLOCK)
				WHERE IsHalfDay = 1
					AND LeaveType = @BusinessDuringWorkingLeaveType
					AND DATEDIFF(MI, FromTime, ToTime) > 120
				)
		BEGIN
			SET @ErrCode = 115
			SET @ErrMsg = 'You can not request leave during working hours > 120 minutes.'

			RETURN
		END

		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
			,@fromDate = @FromDate
			,@toDate = @FromDate
			,@empIds = @EmpId

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.tmpEmployeeCalendar WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND DATEDIFF(DD, @FromDate, WorkDate) = 0
					AND ISNULL(ShiftId, 0) > 0
				)
		BEGIN
			SET @ErrCode = 116
			SET @ErrMsg = 'You can not request because this date has not arranged shift yet.'

			RETURN
		END

		IF EXISTS (
				SELECT 1
				FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
					INNER JOIN dbo.Shift AS shift WITH (NOLOCK) ON empca.ShiftId = shift.ShiftId
					INNER JOIN #tblLeaveRequestDetail AS detail WITH (NOLOCK) ON DATEDIFF(DD, detail.OnDate, empca.WorkDate) = 0
					AND CONVERT(VARCHAR(5), detail.FromTime, 108) = shift.BeginCheckInTime
				WHERE empca.EmpId = @EmpId
					AND DATEDIFF(DD, @FromDate, empca.WorkDate) = 0
				)
		BEGIN
			SET @ErrCode = 117
			SET @ErrMsg = 'You can not request at the beginning of the shift.'

			RETURN
		END
	END

	-- check paternity leave
	IF @LeaveTypeId = @PaternityLeaveType
		OR EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE LeaveType = @PaternityLeaveType
			)
	BEGIN
		IF @LeaveTypeId = @PaternityLeaveType
		BEGIN
			SELECT @TotalDaysPaternity = @TotalDays
				,@TmpFromDate = @FromDate
				,@TmpToDate = @ToDate
		END
		ELSE
		BEGIN
			SELECT @TotalDaysPaternity = COUNT(1)
				,@TmpFromDate = MIN(OnDate)
				,@TmpToDate = MAX(OnDate)
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE LeaveType = @PaternityLeaveType
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeePaternity WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND @TmpFromDate >= ChildBornDate
					AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
				)
		BEGIN
			SET @ErrCode = 118
			SET @ErrMsg = 'You can not request because request within 1 month from child born date.'

			RETURN
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeePaternity WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND @TmpFromDate >= ChildBornDate
					AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
					AND BalanceDay >= @TotalDaysPaternity
				)
		BEGIN
			SET @ErrCode = 119
			SET @ErrMsg = 'You have not enough paternity leave days to request.'

			RETURN
		END

		UPDATE dbo.EmployeePaternity WITH (ROWLOCK, UPDLOCK)
		SET BalanceDay = BalanceDay - @TotalDaysPaternity
		WHERE EmpId = @EmpId
			AND @TmpFromDate >= ChildBornDate
			AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
	END

	EXEC [dbo].WorkingTimeRequest_GetNewRefNoByRequestType @RefNo = @RefNo OUTPUT
		,@RequestType = @RequestType

	BEGIN TRY
		INSERT INTO dbo.WorkingTimeRequest (
			[EmpId]
			,[RequestType]
			,[Remark]
			,[CurrentStatus]
			,[VerifierId]
			,[ApproverId]
			,[VerifiedStatus]
			,[ApprovedStatus]
			,[HRStatus]
			,[CreatedDate]
			,[CreatedBy]
			)
		VALUES (
			@EmpId
			,@RequestType
			,@Remark
			,CASE 
				WHEN @IsTopManager = 1
					AND @VerifierId IS NOT NULL THEN 1
				WHEN @IsTopManager = 1
					AND @ApproverId IS NOT NULL THEN 2
				WHEN @IsTopManager = 1
					AND @ApproverId IS NULL THEN 4
				ELSE 1
				END
			,@VerifierId
			,@ApproverId
			,CASE 
				WHEN @IsTopManager = 1
					AND @VerifierId IS NULL THEN 2
				ELSE 1
				END
			,CASE 
				WHEN @IsTopManager = 1
					AND @ApproverId IS NULL THEN 1
				ELSE 1
				END
			,1
			,@CreatedDate
			,@CreatedBy
			)

		SELECT @RequestId = CAST(SCOPE_IDENTITY() AS BIGINT)

		INSERT INTO [dbo].[LeaveRequest] (
			[RequestId]
			,[EmpId]
			,[FromDate]
			,[ToDate]
			,[LeaveType]
			,[TotalDays]
			,[RefNo]
			)
		VALUES (
			@RequestId
			,@EmpId
			,@FromDate
			,@ToDate
			,@LeaveTypeID
			,@TotalDays
			,@RefNo
			)

		INSERT INTO [dbo].[LeaveRequestDetail] (
			[RequestId]
			,[EmpId]
			,[OnDate]
			,[ShiftId]
			,[LeaveType]
			,[IsHalfDay]
			,[FromTime]
			,[ToTime]
			,WorkType
			)
		SELECT @RequestId
			,@EmpId
			,OnDate
			,ShiftId
			,LeaveType
			,IsHalfDay
			,FromTime
			,ToTime
			,WorkType
		FROM #tblLeaveRequestDetail WITH (NOLOCK)

		EXEC dbo.LeaveRequest_EmployeeCalendar_UpdateOffDay @RequestId

		EXEC dbo.LeaveRequest_InsertTmpAnnualLeaveTrans @RequestId = @RequestId
			,@EmpId = @EmpId

		EXEC dbo.LeaveRequest_InsertTmpHospitalizationLeaveTrans @RequestId = @RequestId

		EXEC dbo.HospitalLeave_Insert @RequestId = @RequestId, @IsHospitalApplication = @IsHospitalApplication

		EXEC dbo.LeaveRequest_InsertTmpSickLeaveTrans @RequestId = @RequestId

		EXEC dbo.LeaveRequest_InsertKIVLeaveTrans @RequestId = @RequestId

		EXEC dbo.LeaveRequest_InsertWeekendLeaveTrans @RequestId = @RequestId

		IF @ApproverId IS NULL
			AND @VerifierId IS NULL
			AND @IsTopManager = 1
		BEGIN
			EXEC dbo.LeaveRequest_Approve @RequestId = @RequestId
				,@ActorId = @EmpId
				,@RoleId = 3
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END

		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
			,@fromDate = @FromDate
			,@toDate = @ToDate
			,@empIds = @EmpId
			,@isUpdateRequestData = 1

		EXEC dbo.LeaveRequest_WriteLog @RequestId
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH

	DROP TABLE #tblLeaveRequestDetail
END
GO

ALTER PROCEDURE [dbo].[LeaveRequest_Update]
(
    @RequestId BIGINT
	,@EmpId INT
	,@CompanyId SMALLINT
	,@Remark NVARCHAR(2000) = NULL
	,@FromDate DATETIME = NULL
	,@ToDate DATETIME = NULL
	,@LeaveTypeId INT = NULL
	,@TotalDays NUMERIC(5, 1) = NULL
	,@ModifiedBy INT = NULL
	,@VerifierId INT = NULL
	,@ApproverId INT = NULL
	,@HRId INT = NULL
	,@RefNo NVARCHAR(200) = ''
	,@IsHospitalApplication BIT	= NULL
	,@ListDetail VARCHAR(MAX) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-11-11
    Task: update leave request
    DB: bodb_HRM

    Revisions:
        20250423@Tim: fix bug validate request in the same range
    Param's Explanation:
	    - @ListDetail: '<ROOT><Row OnDate='' ShiftID='' LeaveType='' IsHalfDay='' WorkType='' FromTime='' ToTime='' /></ROOT>'
	    - @WorkType :
			    1. off
			    2. leave
			    3. work
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @RequestType TINYINT = 6
        ,@AnnualLeaveType TINYINT = 2
        ,@KIVLeaveType TINYINT = 10
        ,@KIVByHourLeaveType TINYINT = 48
        ,@PublicHolidayLeaveType TINYINT = 13
        ,@PaternityLeaveType TINYINT = 14
        ,@MaternityLeaveType INT = 12
        ,@UnpaidLeaveType TINYINT = 25
        ,@UnpaidLeaveInsuranceType TINYINT = 41
        ,@BusinessTripLeaveType TINYINT = 9
        ,@BusinessDuringWorkingLeaveType TINYINT = 26
        ,@SickLeaveTypeId TINYINT = 29
        ,@HospitalizationLeaveTypeId TINYINT = 39
        ,@OnbehalfActionType TINYINT = 5
        ,@VerifyActionType TINYINT = 2
        ,@ApproveActionType TINYINT = 3
        ,@LeaveWorkType TINYINT = 2
        ,@TotalDays_tmp NUMERIC(5, 1)
        ,@AnnualLeaveDay DECIMAL(18, 2)
        ,@SickLeaveDay DECIMAL(18, 2)
        ,@HospitalizationLeaveDay DECIMAL(18, 2)
        ,@KIVLeaveDay DECIMAL(18, 2)
        ,@KIVLeaveMinutes INT
        ,@isHalfDay BIT
        ,@ModifiedDate DATETIME
        ,@IsTopManager BIT
        ,@TmpFromDate DATE
        ,@TmpToDate DATE
        ,@DocHandler INT
        ,@OldTotalDays INT
        ,@TotalDaysPaternity INT
        ,@BalanceDaysPaternity INT
        ,@OldFromDate DATE
        ,@OldToDate DATE
        ,@JoinedDate DATE
        ,@AnnualLeaveResetTimelineType TINYINT
        ,@AnnualLeaveResetTimelineByYear TINYINT = 1

	CREATE TABLE #tblLeaveRequestDetail (
		OnDate DATETIME
		,ShiftId INT
		,LeaveType INT
		,WorkType TINYINT
		,IsHalfDay BIT
		,FromTime DATETIME
		,ToTime DATETIME
		)

    SELECT @JoinedDate = JoinedDate
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
    WHERE e.EmpId = @EmpId
        AND ce.CompanyId = @CompanyId

    SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

	SELECT @IsHalfDay = CASE 
			WHEN @TotalDays = 0.5 THEN 1
			ELSE 0
			END
		,@TotalDays_tmp = @TotalDays
		,@ModifiedDate = GETDATE()
		,@TmpFromDate = CAST(@FromDate AS DATE)
		,@TmpToDate = CAST(@ToDate AS DATE)

	IF CAST(@FromDate AS DATE) < @JoinedDate
	BEGIN
		SET @ErrCode = 120
		SET @ErrMsg = 'You can not request leave earlier than your joined date.'

		RETURN
	END

	IF NOT EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest WITH (NOLOCK)
			WHERE RequestId = @RequestId
				AND CurrentStatus = 1
			)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'You can not change this request beacause current status is not pending.'

		RETURN;
	END

	IF @FromDate IS NULL
		OR @ToDate IS NULL
		OR @LeaveTypeId IS NULL
		OR ISNULL(@TotalDays, 0) < 0
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Invalid parameter'

		RETURN;
	END

	IF ISNULL(@RefNo, '') NOT LIKE 'REF-%'
	BEGIN
		SET @ErrCode = 101
		SET @ErrMsg = 'Ref No incorrect format'

		RETURN;
	END

	IF @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear
        AND YEAR(@FromDate) != YEAR(@ToDate)
	BEGIN
		SET @ErrCode = 102
		SET @ErrMsg = 'You cannot submit a cross-year leave request. Please split it into 2 separate requests.'

		RETURN;
	END

    IF @AnnualLeaveResetTimelineType != @AnnualLeaveResetTimelineByYear
        AND DATEFROMPARTS(YEAR(@FromDate), MONTH(@JoinedDate), DAY(@JoinedDate)) >= @FromDate
        AND DATEFROMPARTS(YEAR(@ToDate), MONTH(@JoinedDate), DAY(@JoinedDate)) < @ToDate
    BEGIN
        SET @ErrCode = 103
        SET @ErrMsg = 'You cannot submit a cross-leave request based on your Group Date. Please split it into 2 separate requests.'

		RETURN;
    END

	IF @EmpId <> @ModifiedBy
		AND NOT EXISTS (
			SELECT 1
			FROM [dbo].[EmployeeSupervisor] sp WITH (NOLOCK)
			WHERE sp.OwnerId = @EmpId
				AND sp.EmpId = @ModifiedBy
				AND sp.ActionType = @OnbehalfActionType
				AND sp.RequestType = @RequestType
				AND ISNULL(sp.IsDeleted, 0) = 0
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
				INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
			WHERE e.EmpId = @EmpId
				AND g.OwnerId = @ModifiedBy
				AND g.RequestType = @RequestType
				AND g.ActionType = @OnbehalfActionType
				AND ISNULL(g.IsDeleted, 0) = 0
			)
	BEGIN
		SET @ErrCode = 106
		SET @ErrMsg = 'You have not on behalf permision on this employee.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsTopManager = 1
			)
	BEGIN
		SET @IsTopManager = 1
	END
	ELSE
	BEGIN
		IF @VerifierId IS NULL
			OR (
				NOT EXISTS (
					SELECT 1
					FROM [dbo].[EmployeeSupervisor] sp WITH (NOLOCK)
					WHERE sp.OwnerId = @VerifierId
						AND sp.EmpId = @EmpId
						AND sp.ActionType = @VerifyActionType
						AND sp.RequestType = @RequestType
						AND ISNULL(sp.IsDeleted, 0) = 0
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
					WHERE e.EmpId = @EmpId
						AND g.OwnerId = @VerifierId
						AND g.RequestType = @RequestType
						AND g.ActionType = @VerifyActionType
						AND ISNULL(g.IsDeleted, 0) = 0
					)
				)
		BEGIN
			SET @ErrCode = 108
			SET @ErrMsg = 'Invalid Verifier.'

			RETURN;
		END

		IF @ApproverId IS NULL
			OR (
				NOT EXISTS (
					SELECT 1
					FROM [dbo].[EmployeeSupervisor] sp WITH (NOLOCK)
					WHERE sp.OwnerId = @ApproverId
						AND sp.EmpId = @EmpId
						AND sp.ActionType = @ApproveActionType
						AND sp.RequestType = @RequestType
						AND ISNULL(sp.IsDeleted, 0) = 0
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.GroupSupervisor AS g WITH (NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON g.GroupId = e.GroupId
					WHERE e.EmpId = @EmpId
						AND g.OwnerId = @ApproverId
						AND g.RequestType = @RequestType
						AND g.ActionType = @ApproveActionType
						AND ISNULL(g.IsDeleted, 0) = 0
					)
				)
		BEGIN
			SET @ErrCode = 109
			SET @ErrMsg = 'Invalid Approver.'

			RETURN;
		END
	END

	IF @LeaveTypeID <> @PublicHolidayLeaveType
		AND @TotalDays = 0.5
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar WITH (NOLOCK)
			WHERE EmpID = @EmpId
				AND WorkDate = @FromDate
				AND (
					IsHoliday = 1
					OR IsOffDay = 1
					)
			)
	BEGIN
		SET @ErrCode = 105
		SET @ErrMsg = 'Your can not request on off day or holiday.'

		RETURN;
	END

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@ListDetail

		IF DATEDIFF(DD, @TmpFromDate, @TmpToDate) + 1 <> (
				SELECT COUNT(1)
				FROM dbo.EmployeeCalendar WITH (NOLOCK)
				WHERE EmpID = @EmpID
					AND WorkDate BETWEEN @TmpFromDate
						AND @TmpToDate
				)
		BEGIN
			EXEC dbo.EmployeeCalendar_Insert @EmpId = @EmpId
				,@fromdate = @TmpFromDate
				,@todate = @TmpToDate
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END

		INSERT INTO #tblLeaveRequestDetail (
			OnDate
			,ShiftID
			,LeaveType
			,WorkType
			,IsHalfDay
			,FromTime
			,ToTime
			)
		SELECT Data.OnDate
			,ISNULL(Data.ShiftID, ec.ShiftId)
			,Data.LeaveType
			,Data.WorkType
			,Data.IsHalfDay
			,Data.FromTime
			,Data.ToTime
		FROM OPENXML(@DocHandler, '/ROOT/Row', 1) WITH (OnDate DATETIME, ShiftID INT, LeaveType INT, IsHalfDay BIT, WorkType TINYINT, FromTime DATETIME, ToTime DATETIME) AS Data
			LEFT JOIN dbo.EmployeeCalendar ec WITH (NOLOCK) ON ec.WorkDate = data.OnDate
			AND ec.EmpId = @EmpId

		IF @@ROWCOUNT <> 0
		BEGIN
			SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay
						WHEN 1 THEN 0.5
						ELSE 1
						END)
			FROM dbo.EmployeeCalendar cl WITH (NOLOCK)
				INNER JOIN #tblLeaveRequestDetail lrd WITH (NOLOCK) ON cl.WorkDate = lrd.OnDate
			WHERE EmpID = @EmpID
				AND WorkDate BETWEEN @TmpFromDate
					AND @TmpToDate
				AND IsHoliday = 0
				AND IsOffDay = 0 --AND IsLeaveDay = 0
				AND lrd.WorkType = @LeaveWorkType
		END

		IF @TotalDays_tmp IS NULL
			SELECT @TotalDays = SUM(CASE lrd.IsHalfDay
						WHEN 1 THEN 0.5
						ELSE 1
						END)
			FROM #tblLeaveRequestDetail lrd WITH (NOLOCK)
			WHERE lrd.WorkType = @LeaveWorkType

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 103
			,@ErrMsg = N'Edit leave request for an employee failed.'

		RETURN
	END CATCH;

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
			GROUP BY OnDate
			HAVING COUNT(DISTINCT LeaveType) = 1
				AND COUNT(OnDate) > 1
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Please check Leave Type on this request.'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			)
	BEGIN
		SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay
					WHEN 1 THEN 0.5
					ELSE 1
					END)
		FROM dbo.EmployeeCalendar cl WITH (NOLOCK)
			INNER JOIN #tblLeaveRequestDetail lrd WITH (NOLOCK) ON cl.WorkDate = lrd.OnDate
		WHERE EmpID = @EmpID
			AND WorkDate BETWEEN @TmpFromDate
				AND @TmpToDate
			AND IsHoliday = 0
			AND IsOffDay = 0
			AND IsLeaveDay = 0
			AND lrd.WorkType = @LeaveWorkType

		IF @TotalDays_tmp IS NULL
		BEGIN
			SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay
						WHEN 1 THEN 0.5
						ELSE 1
						END)
			FROM #tblLeaveRequestDetail lrd WITH (NOLOCK)
			WHERE lrd.WorkType = @LeaveWorkType
		END

		SELECT @AnnualLeaveDay = SUM(CASE 
					WHEN LeaveType = @AnnualLeaveType THEN CASE 
							WHEN IsHalfDay = 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@SickLeaveDay = SUM(CASE 
					WHEN LeaveType = @SickLeaveTypeId THEN CASE 
							WHEN IsHalfDay = 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@HospitalizationLeaveDay = SUM(CASE 
					WHEN LeaveType = @HospitalizationLeaveTypeId THEN CASE 
							WHEN IsHalfDay = 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@KIVLeaveDay = SUM(CASE 
					WHEN LeaveType = @KIVLeaveType THEN CASE IsHalfDay
							WHEN 1 THEN 0.5
							ELSE 1
							END
					ELSE 0
					END)
			,@KIVLeaveMinutes = SUM(CASE 
					WHEN LeaveType = @KIVByHourLeaveType THEN DATEDIFF(MI, FromTime, ToTime)
					ELSE 0
					END)
		FROM #tblLeaveRequestDetail WITH (NOLOCK)
	END
	ELSE
	BEGIN
		IF @isHalfDay = 1
			AND ISNULL(@TotalDays_tmp, 1) = 1
		BEGIN
			SET @TotalDays_tmp = 0.5
		END

		IF @LeaveTypeId = @AnnualLeaveType
		BEGIN
			SELECT @AnnualLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @SickLeaveTypeId
		BEGIN
			SELECT @SickLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @HospitalizationLeaveTypeId
		BEGIN
			SELECT @HospitalizationLeaveDay = @TotalDays
		END
		ELSE IF @LeaveTypeId = @KIVLeaveType
		BEGIN
			SELECT @KIVLeaveDay = @TotalDays
		END
	END

	IF ISNULL(@TotalDays_tmp, 0) <= 0
		AND @LeaveTypeId <> @PublicHolidayLeaveType
	BEGIN
		SET @ErrCode = 105
		SET @ErrMsg = 'Your leave days invalid.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.LeaveRequest AS l WITH (NOLOCK) ON r.RequestId = l.RequestId
			WHERE r.RequestId != @RequestId
				AND r.empid = @empid
				AND r.RequestType = @RequestType
				AND r.CurrentStatus IN (1, 2, 4, 6)
				AND (
					(
						NOT EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							WHERE r.RequestId = ldt.RequestId
							)
						AND NOT EXISTS (
							SELECT 1
							FROM #tblLeaveRequestDetail WITH (NOLOCK)
							)
						AND (
							CAST(l.FromDate AS DATE) BETWEEN @TmpFromDate
								AND @TmpToDate
							OR CAST(l.ToDate AS DATE) BETWEEN @TmpFromDate
								AND @TmpToDate
							OR @TmpFromDate BETWEEN CAST(l.FromDate AS DATE)
								AND CAST(l.ToDate AS DATE)
							OR @TmpToDate BETWEEN CAST(l.FromDate AS DATE)
								AND CAST(l.ToDate AS DATE)
							)
						)
                    OR (
					    NOT EXISTS (
						    SELECT 1
						    FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
                            WHERE r.RequestId = ldt.RequestId
						    )
					    AND EXISTS (
						    SELECT 1
						    FROM #tblLeaveRequestDetail AS ldt WITH (NOLOCK)
						    WHERE ldt.OnDate BETWEEN l.FromDate AND l.ToDate
						    )
					    )
					OR (
						NOT EXISTS (
							SELECT 1
							FROM #tblLeaveRequestDetail WITH (NOLOCK)
							)
						AND EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							WHERE r.RequestId = ldt.RequestId
								AND ldt.OnDate BETWEEN @TmpFromDate AND @TmpToDate
							)
						)
					OR (
						EXISTS (
							SELECT 1
							FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
								INNER JOIN #tblLeaveRequestDetail AS ldtt WITH (NOLOCK) ON ldtt.OnDate = ldt.OnDate
							WHERE r.RequestId = ldt.RequestId
								AND (
									(
										ldt.IsHalfDay = 0
										AND ldtt.IsHalfDay = 0
										)
									OR (
										ldt.IsHalfDay = 0
										AND ldtt.IsHalfDay = 1
										AND (
											ldtt.FromTime BETWEEN ldt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldt.ToTime) + 1)
											OR ldtt.ToTime BETWEEN ldt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldt.ToTime) + 1)
											)
										)
									OR (
										ldt.IsHalfDay = 1
										AND ldtt.IsHalfDay = 0
										AND (
											ldt.FromTime BETWEEN ldtt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldtt.ToTime) + 1)
											OR ldt.ToTime BETWEEN ldtt.FromTime
												AND DATEADD(MILLISECOND, - 1, DATEDIFF(DAY, 0, ldtt.ToTime) + 1)
											)
										)
									OR (
										ldt.IsHalfDay = 1
										AND ldtt.IsHalfDay = 1
										AND (
											ldt.FromTime BETWEEN ldtt.FromTime AND ldtt.ToTime
											OR ldt.ToTime BETWEEN ldtt.FromTime AND ldtt.ToTime
											OR ldtt.FromTime BETWEEN ldt.FromTime AND ldt.ToTime
											OR ldtt.ToTime BETWEEN ldt.FromTime AND ldt.ToTime
											)
										AND ldt.FromTime != ldtt.ToTime
										AND ldt.ToTime != ldtt.FromTime
										)
									)
							)
						)
					)
			)
	BEGIN
		SET @ErrCode = 104
		SET @ErrMsg = 'There is another request in the same range'

		RETURN;
	END

	IF @TotalDays_tmp IS NOT NULL
		OR @TotalDays_tmp > 0
		SET @TotalDays = @TotalDays_tmp

	SELECT @AnnualLeaveDay = ISNULL(@AnnualLeaveDay, 0)

	IF @AnnualLeaveDay > 0
	BEGIN
		IF @AnnualLeaveDay > dbo.fnc_GetAnnualLeaveBalanceByDate(@EmpId, @ToDate, @RequestId)
		BEGIN
			SET @ErrCode = 108
			SET @ErrMsg = 'Not enough annual leave days to request.'

			RETURN;
		END
	END

	DECLARE @Year INT = YEAR(@ToDate)

	EXEC dbo.LeaveRequest_CheckSickLeaveBalance @EmpId = @EmpId
		,@LeaveDays = @SickLeaveDay
		,@Year = @Year
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT

	IF @ErrCode > 0 RETURN;

	EXEC dbo.LeaveRequest_CheckHospitalizationLeaveBalance @EmpId = @EmpId
		,@LeaveDays = @HospitalizationLeaveDay
		,@Year = @Year
		,@ErrCode = @ErrCode OUT
		,@ErrMsg = @ErrMsg OUT

	IF @ErrCode > 0 RETURN;

	SELECT @KIVLeaveDay = ISNULL(@KIVLeaveDay, 0)

	IF @KIVLeaveDay > 0
	BEGIN
		IF @KIVLeaveDay > dbo.fnc_GetKIVByDayBalance(@EmpId, @ToDate, @RequestId)
		BEGIN
			SET @ErrCode = 111
			SET @ErrMsg = 'Not enough Compensation Leave days to request.'

			RETURN;
		END
	END

	SELECT @KIVLeaveMinutes = ISNULL(@KIVLeaveMinutes, 0)

	IF @KIVLeaveMinutes > 0
	BEGIN
		IF @KIVLeaveMinutes > dbo.fnc_GetKIVByHourBalance(@EmpId, @FromDate, @RequestId)
		BEGIN
			SET @ErrCode = 111
			SET @ErrMsg = 'Not enough Compensation Leave hours to request.'

			RETURN;
		END
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
				AND LeaveType IN (@UnpaidLeaveInsuranceType)
			)
	BEGIN
		SET @ErrCode = 112
		SET @ErrMsg = 'Leave type does not support half day.'

		RETURN;
	END

	IF EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
				AND LeaveType IN (@AnnualLeaveType, @UnpaidLeaveType, @KIVLeaveType)
				AND DATEDIFF(MINUTE, FromTime, ToTime) > 300
			)
	BEGIN
		SET @ErrCode = 113
		SET @ErrMsg = 'You can not request leave half day over 5 hours.'

		RETURN;
	END

	-- check rule for leave during working hours
	IF @LeaveTypeId = @BusinessDuringWorkingLeaveType
		AND EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE IsHalfDay = 1
			)
	BEGIN
		IF EXISTS (
				SELECT 1
				FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
					INNER JOIN dbo.LeaveRequest AS lv WITH (NOLOCK) ON lv.RequestId = ldt.RequestId
					AND lv.EmpId = @EmpId
					AND lv.LeaveType = @BusinessDuringWorkingLeaveType
					AND DATEDIFF(MONTH, lv.FromDate, @FromDate) = 0
					INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON wk.RequestId = ldt.RequestId
					AND wk.CurrentStatus IN (1, 2, 4, 6)
				WHERE ldt.RequestId <> @RequestId
					AND ldt.IsHalfDay = 1
				)
		BEGIN
			SET @ErrCode = 114
			SET @ErrMsg = 'You had been reached maximum leave during working hours in month.'

			RETURN
		END

		IF EXISTS (
				SELECT 1
				FROM #tblLeaveRequestDetail WITH (NOLOCK)
				WHERE IsHalfDay = 1
					AND LeaveType = @BusinessDuringWorkingLeaveType
					AND DATEDIFF(MI, FromTime, ToTime) > 120
				)
		BEGIN
			SET @ErrCode = 115
			SET @ErrMsg = 'You can not request leave during working hours > 120 minutes.'

			RETURN
		END

		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
			,@fromDate = @FromDate
			,@toDate = @FromDate
			,@empIds = @EmpId

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.tmpEmployeeCalendar WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND DATEDIFF(DD, @FromDate, WorkDate) = 0
					AND ISNULL(ShiftId, 0) > 0
				)
		BEGIN
			SET @ErrCode = 116
			SET @ErrMsg = 'You can not request because this date has not arranged shift yet.'

			RETURN
		END

		IF EXISTS (
				SELECT 1
				FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
					INNER JOIN dbo.Shift AS shift WITH (NOLOCK) ON empca.ShiftId = shift.ShiftId
					INNER JOIN #tblLeaveRequestDetail AS detail WITH (NOLOCK) ON DATEDIFF(DD, detail.OnDate, empca.WorkDate) = 0
					AND CONVERT(VARCHAR(5), detail.FromTime, 108) = shift.BeginCheckInTime
				WHERE empca.EmpId = @EmpId
					AND DATEDIFF(DD, @FromDate, empca.WorkDate) = 0
				)
		BEGIN
			SET @ErrCode = 117
			SET @ErrMsg = 'You can not request at the beginning of the shift.'

			RETURN
		END
	END

	-- check paternity leave
	SELECT @TotalDaysPaternity = TotalDays
		,@TmpFromDate = FromDate
		,@TmpToDate = ToDate
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId
		AND LeaveType = @PaternityLeaveType

	IF ISNULL(@TotalDaysPaternity, 0) = 0
	BEGIN
		SELECT @TotalDaysPaternity = COUNT(1)
			,@TmpFromDate = MIN(OnDate)
			,@TmpFromDate = MAX(OnDate)
		FROM dbo.LeaveRequestDetail WITH (NOLOCK)
		WHERE RequestId = @RequestId
			AND LeaveType = @PaternityLeaveType
	END

	IF @TotalDaysPaternity > 0
	BEGIN
		UPDATE dbo.EmployeePaternity WITH (ROWLOCK, UPDLOCK)
		SET BalanceDay = BalanceDay + @TotalDaysPaternity
		WHERE EmpId = @EmpId
			AND @TmpFromDate >= ChildBornDate
			AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
	END

	IF @LeaveTypeId = @PaternityLeaveType
		OR EXISTS (
			SELECT 1
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE LeaveType = @PaternityLeaveType
			)
	BEGIN
		IF @LeaveTypeId = @PaternityLeaveType
		BEGIN
			SELECT @TotalDaysPaternity = @TotalDays
				,@TmpFromDate = @FromDate
				,@TmpToDate = @ToDate
		END
		ELSE
		BEGIN
			SELECT @TotalDaysPaternity = COUNT(1)
				,@TmpFromDate = MIN(OnDate)
				,@TmpToDate = MAX(OnDate)
			FROM #tblLeaveRequestDetail WITH (NOLOCK)
			WHERE LeaveType = @PaternityLeaveType
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeePaternity WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND @TmpFromDate >= ChildBornDate
					AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
				)
		BEGIN
			SET @ErrCode = 118
			SET @ErrMsg = 'You can not request because request within 1 month from child born date.'

			RETURN
		END

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeePaternity WITH (NOLOCK)
				WHERE EmpId = @EmpId
					AND @TmpFromDate >= ChildBornDate
					AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
					AND BalanceDay >= @TotalDaysPaternity
				)
		BEGIN
			SET @ErrCode = 119
			SET @ErrMsg = 'You have not enough paternity leave days to request.'

			RETURN
		END

		UPDATE dbo.EmployeePaternity WITH (ROWLOCK, UPDLOCK)
		SET BalanceDay = BalanceDay - @TotalDaysPaternity
		WHERE EmpId = @EmpId
			AND @TmpFromDate >= ChildBornDate
			AND @TmpToDate <= DATEADD(M, 1, ChildBornDate)
	END

	SELECT @OldFromDate = FromDate
		,@OldToDate = ToDate
	FROM dbo.LeaveRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	BEGIN TRY
		BEGIN TRANSACTION Update_LeaveMultiRequest

		UPDATE WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET Remark = @Remark
			,[CurrentStatus] = CASE 
				WHEN @IsTopManager = 1
					AND @VerifierId IS NOT NULL THEN 1
				WHEN @IsTopManager = 1
					AND @ApproverId IS NOT NULL THEN 2
				WHEN @IsTopManager = 1
					AND @ApproverId IS NULL THEN 4
				ELSE 1
				END
			,VerifierId = @VerifierId
			,[VerifiedStatus] = CASE 
				WHEN @IsTopManager = 1
					AND @VerifierId IS NULL THEN 2
				ELSE 1
				END
			,ApproverId = @ApproverId
			,[ApprovedStatus] = CASE 
				WHEN @IsTopManager = 1
					AND @ApproverId IS NULL THEN 2
				ELSE 1
				END
			,HRId = @HRId
			,ModifiedBy = @ModifiedBy
			,ModifiedDate = @ModifiedDate
		WHERE RequestId = @RequestId

		UPDATE dbo.LeaveRequest WITH (ROWLOCK, UPDLOCK)
		SET FromDate = @FromDate
			,ToDate = @ToDate
			,LeaveType = @LeaveTypeId
			,TotalDays = @TotalDays
		WHERE RequestId = @RequestId

		DELETE
		FROM dbo.LeaveRequestDetail
		WHERE RequestId = @RequestId

		INSERT INTO dbo.LeaveRequestDetail (
			RequestId
			,EmpId
			,OnDate
			,ShiftId
			,LeaveType
			,IsHalfDay
			,FromTime
			,ToTime
			,WorkType
			)
		SELECT @RequestId
			,@EmpId
			,OnDate
			,ShiftId
			,LeaveType
			,IsHalfDay
			,FromTime
			,ToTime
			,WorkType
		FROM #tblLeaveRequestDetail WITH (NOLOCK)

		EXEC dbo.LeaveRequest_EmployeeCalendar_UpdateOffDay @RequestId

		EXEC dbo.LeaveRequest_InsertTmpAnnualLeaveTrans @RequestId = @RequestId
			,@EmpId = @EmpId

		EXEC dbo.LeaveRequest_InsertTmpHospitalizationLeaveTrans @RequestId = @RequestId

		EXEC dbo.HospitalLeave_Insert @RequestId = @RequestId, @IsHospitalApplication = @IsHospitalApplication

		EXEC dbo.LeaveRequest_InsertTmpSickLeaveTrans @RequestId = @RequestId

		EXEC dbo.LeaveRequest_InsertKIVLeaveTrans @RequestId = @RequestId

		EXEC dbo.LeaveRequest_InsertWeekendLeaveTrans @RequestId = @RequestId

		IF @ApproverId IS NULL
			AND @VerifierId IS NULL
			AND @IsTopManager = 1
		BEGIN
			EXEC dbo.LeaveRequest_Approve @RequestId = @RequestId
				,@ActorId = @EmpId
				,@RoleID = 3
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END

		IF @OldFromDate <> @FromDate
			OR @OldToDate <> @ToDate
		BEGIN
			EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
				,@fromDate = @OldFromDate
				,@toDate = @OldToDate
				,@empIds = @EmpId
				,@isUpdateRequestData = 1
		END

		EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
			,@fromDate = @FromDate
			,@toDate = @ToDate
			,@empIds = @EmpId
			,@isUpdateRequestData = 1

		EXEC dbo.LeaveRequest_WriteLog @RequestId

		COMMIT TRANSACTION Update_LeaveMultiRequest;
	END TRY

	BEGIN CATCH
		SELECT ERROR_MESSAGE()

		SELECT @ErrCode = 999
			,@ErrMsg = N'Update request failed.'

		ROLLBACK TRANSACTION Update_LeaveMultiRequest;

		RETURN
	END CATCH;

	DROP TABLE #tblLeaveRequestDetail
END
GO

ALTER PROCEDURE [dbo].[SystemSetting_Get]
(
    @CompanyId SMALLINT
)
AS
/*
    Created: Tim.Trinh@2021-08-24
    Task: get system setting
    DB: bodb_HRM

    Revisions:
        20250429@Tim: add param @CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EnableHospitalizationLeaveBalance BIT = 0
		,@EnableSickLeaveBalance BIT = 0
        ,@EnableLimitUseAnnualLeaveBalance BIT = 0

	SELECT @EnableHospitalizationLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableHospitalizationLeaveBalance'

	SELECT @EnableSickLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableSickLeaveBalance'

    SELECT @EnableLimitUseAnnualLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'LimitUseAnnualLeaveBalance'

	SELECT @EnableHospitalizationLeaveBalance AS EnableHospitalizationLeaveBalance
		,@EnableSickLeaveBalance AS EnableSickLeaveBalance
        ,@EnableLimitUseAnnualLeaveBalance AS EnableLimitUseAnnualLeaveBalance
END
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetRequestByCreateDate_AllType]
(
    @CompanyId SMALLINT
    ,@SupervisorId INT = NULL
    ,@empid INT = NULL
    ,@TeamIds VARCHAR(MAX) = ''
    ,@fromdate DATETIME
    ,@todate DATETIME
    ,@status VARCHAR(MAX) = NULL
    ,@role VARCHAR(MAX) = ''
    ,@isLocal BIT = NULL
    ,@requestType INT = NULL
    ,@leaveTypeId INT = NULL
)
AS
/*
    Created: Tom.Vo@2013-11-04
    Task: Get Request By Date
    DB: bodb_HRM

    Revisions:
        20250403@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	CREATE TABLE #tblstatus (Currentstatus TINYINT)

	CREATE TABLE #tblGroupsList (GroupId INT PRIMARY KEY)

	CREATE TABLE #tblEmployeeId (EmpId INT PRIMARY KEY)

	CREATE TABLE #tblRequestId (RequestId INT PRIMARY KEY)

	CREATE TABLE #tblTotalDaysRequestInMonth (
		EmpId INT
		,RequestType TINYINT
		,TotalDaysRequest INT
		)

	CREATE TABLE #tblRequestInDaily (
		RequestID BIGINT
		,EmpId INT
		,RequestType TINYINT
		,InOutMins INT
		,ActualInOutMins INT
		,RequestedTime DATETIME
		,FromDate DATETIME
		,ToDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 1)
		,IsHalfDay BIT
		,IsWarning BIT
		,KeepInViewType TINYINT
		)

	CREATE TABLE #tblGeneralLeaveDetail (
		RequestId BIGINT
		,LeaveCountDetails NVARCHAR(MAX)
		)

	IF ISNULL(@status, '') <> ''
	BEGIN
		INSERT INTO #tblstatus (Currentstatus)
		SELECT value
		FROM STRING_SPLIT(@status, ',')
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupsList (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empid IS NULL
	BEGIN
		IF @SupervisorID IS NULL
			OR @role LIKE '%6%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpID)
			SELECT e.EmpId
			FROM dbo.Employee AS e WITH (NOLOCK)
		END
		ELSE IF @role LIKE '%2%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			EXEC dbo.Request_GetMemberByActorId @EmpId = @SupervisorId
				,@ExcludeUserDelete = 1
				,@IsShowUserInTeam = 0
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 1, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeId (EmpID)
		VALUES (@empid)
	END

	INSERT INTO #tblRequestId (RequestId)
	SELECT r.RequestId
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS eid WITH (NOLOCK) ON r.EmpId = eid.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = eid.empID
		AND e.isDeleted = 0
		LEFT JOIN dbo.EmployeeSummary AS e_s WITH (NOLOCK) ON e_s.EmpId = eid.EmpId
	WHERE (
			@requestType = 0
			OR (
				@requestType = 1
				AND r.RequestType IN (1, 2)
				)
			OR (
				@requestType = 2
				AND r.RequestType IN (3, 4)
				)
			OR (
				@requestType = 3
				AND r.RequestType = 5
				)
			OR (
				@requestType = 4
				AND r.RequestType = 6
				)
			OR (
				@requestType = 5
				AND r.RequestType = 7
				)
			)
		AND (
			(
				@empid IS NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
						WHERE tblemp.EmpId = r.EmpId
						)
					OR r.VerifierId = @SupervisorID
					OR r.ApproverId = @SupervisorID
					)
				)
			OR (
				@empid IS NOT NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
						WHERE tblemp.EmpId = r.EmpId
						)
					)
				)
			)
		AND (
			ISNULL(@status, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tblstatus AS tblstatus WITH (NOLOCK)
				WHERE tblstatus.Currentstatus = r.CurrentStatus
				)
			)
		AND (
			e.GroupId IS NULL
			OR EXISTS (
				SELECT 1
				FROM #tblGroupsList AS tblgr WITH (NOLOCK)
				WHERE tblgr.GroupId = e.GroupId
				)
			)
		AND (
			@isLocal IS NULL
			OR e_s.IsLocal = @isLocal
			)
		AND r.CreatedDate BETWEEN @fromdate
			AND @todate

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND EXISTS (
			SELECT 1
			FROM #tblGroupsList AS tblgr WITH (NOLOCK)
			WHERE tblgr.GroupId = ee.GroupId
			)
		AND (
			DATEDIFF(MM, inout.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, inout.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND EXISTS (
			SELECT GroupId
			FROM #tblGroupsList AS tblgr WITH (NOLOCK)
			WHERE tblgr.GroupId = ee.GroupId
			)
		AND (
			DATEDIFF(MM, lr.FromDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(MM, cs.FromDate, @fromdate) = 0
			OR DATEDIFF(MM, cs.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT @empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE wt.EmpId = @empid
		AND wt.currentstatus = 6
		AND (
			DATEDIFF(MM, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND EXISTS (
			SELECT GroupId
			FROM #tblGroupsList AS tblgr WITH (NOLOCK)
			WHERE tblgr.GroupId = ee.GroupId
			)
		AND (
			DATEDIFF(MM, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,ActualInOutMins
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,inout.OnDate
		,inout.OnDate
		,0
		,CASE 
			WHEN wt.RequestType = 3 THEN inout.LateInMins
			ELSE inout.EarlyOutMins
			END
		,CASE 
			WHEN wt.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON inout.EmpId = att.EmpId
		AND inout.OnDate = att.AttendanceDate

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,CASE 
			WHEN ldt.FromTime IS NULL THEN lr.FromDate
			ELSE ldt.FromTime
			END
		,CASE 
			WHEN ldt.ToTime IS NULL THEN lr.ToDate
			ELSE ldt.ToTime
			END
		,lr.TotalDays
		,1
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
	WHERE lr.TotalDays = 0.5
		AND ldt.IsHalfDay = 1

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,0
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE lr.TotalDays <> 0.5

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,FromShift
		,ToShift
		,KeepInViewType
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.OnDate
		,lr.OnDate
		,lr.OnDate
		,lr.FromTime
		,lr.ToTime
		,CASE 
			WHEN lr.IsHalfDay = 0 THEN 1
			ELSE 0.5
			END TotalDays
		,NULL
		,NULL
		,lr.KeepInViewType
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,IsWarning
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftId
		,CASE 
			WHEN ISNULL(att.TotalWorkHours, 0) = 0 THEN 1
			ELSE 0
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON lr.OnDate = att.AttendanceDate
		AND lr.EmpId = att.EmpId
	WHERE wt.CurrentStatus = 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftId
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
	WHERE wt.CurrentStatus <> 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate
		,count(1) TotalDays
		,MAX(csd.FromShift) FromShift
		,MAX(csd.ToShift) ToShift
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
		INNER JOIN dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK) ON csd.RequestId = cs.RequestId
	GROUP BY wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate

	INSERT INTO #tblGeneralLeaveDetail (
		RequestId
		,LeaveCountDetails
		)
	SELECT DISTINCT wt.RequestId
		,STUFF((
				SELECT ', ' + (
						CAST(SUM(CASE 
									WHEN rd1.IsHalfDay = 0 THEN 1
									ELSE 0.5
									END) AS NVARCHAR(100)) + ' days ' + lt1.Code
						)
				FROM dbo.LeaveRequestDetail AS rd1 WITH (NOLOCK)
					INNER JOIN dbo.LeaveType AS lt1 WITH (NOLOCK) ON lt1.LeaveTypeId = rd1.LeaveType
                    AND lt1.CompanyId = @CompanyId
				WHERE rd1.RequestId = rd.RequestId
					AND rd1.LeaveType <> 0
				GROUP BY rd1.RequestId
					,rd1.LeaveType
					,lt1.Code
				FOR XML PATH('')
				), 1, 2, '') AS LeaveCountDetails
	FROM (
		SELECT rq.RequestId
			,CreatedDate
			,EmpId
		FROM dbo.WorkingTimeRequest AS rq WITH (NOLOCK)
			INNER JOIN #tblRequestId AS r WITH (NOLOCK) ON r.RequestId = rq.RequestId
		) AS wt
		INNER JOIN #tblRequestInDaily AS rd WITH (NOLOCK) ON wt.RequestId = rd.RequestID
		INNER JOIN #tblRequestId AS r1 WITH (NOLOCK) ON r1.RequestId = rd.RequestId
	ORDER BY wt.RequestId

	SELECT r.RequestId
		,r.RequestType
		,r.Currentstatus AS [Status]
		,r.empID
		,rd.FromDate
		,rd.ToDate
		,rd.TotalDays
		,rd.IsHalfDay
		,rd.RequestedTime AS RequestedDate
		,rd.FromTime
		,rd.ToTime
		,rd.KeepInViewType
		,gdt.LeaveCountDetails
		,lv.LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,r.Remark
		,ISNULL(rm.TotalDaysRequest, 0) TotalDaysRequestInMonth
		,u.Code AS UnitCode
		,CASE 
			WHEN r.RequestType IN (1, 2) THEN inoutmiss.ReasonId
			WHEN r.RequestType IN (3, 4) THEN inout.ReasonId
			ELSE 0
			END [ReasonId]
		,CASE 
			WHEN r.RequestType IN (1, 2, 6, 7) THEN lr.RefNo
			WHEN r.RequestType IN (3, 4) THEN inout.RefNo
			WHEN r.RequestType IN (5) THEN NULL
			END RefNo
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN s1.ShiftID
			ELSE s3.ShiftID END
			) AS FromShiftId
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShiftName
		,s2.ShiftID AS ToShiftId
		,(CASE 
			WHEN s2.ShiftID IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShiftName
		,s2.[Name] AS ToShiftName
		,csr.TypeId AS ChangeShiftType
		,rd.InOutMins AS TotalMinutes
		,rd.ActualInOutMins
		,r.CreatedDate
		,e.EmpId AS RequesterId
		,e.NickName AS RequesterNickName
		,e.FullName AS RequesterFullName
		,g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dep.DepartmentId
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,verifier.EmpId AS VerifierId
		,verifier.NickName AS VerifierNickName
		,verifier.FullName AS VerifierFullName
		,r.VerifiedDate
		,r.VerifiedStatus
		,approver.EmpId AS ApproverId
        ,approver.NickName AS ApproverNickName
		,approver.FullName AS ApproverFullName
		,r.ApprovedDate
		,r.ApprovedStatus
		,hr.NickName AS ProcessedByNickName
		,hr.FullName AS ProcessedByFullName
		,r.HRDate AS ProcessedDate
		,r.HRStatus AS ProcessedStatus
		,r.ModifiedDate
		,ISNULL(rd.IsWarning, 0) AS IsWarning
		,r.ReworkCount
		,dbo.fnc_GetAnnualLeaveBalance(r.EmpId, rd.FromDate, r.RequestId) AS AnnualLeaveBalance
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblRequestInDaily AS rd WITH (NOLOCK) ON r.RequestId = rd.RequestID
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON r.RequestId = rq.RequestId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = r.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = r.empID
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = dep.UnitId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.empid = r.VerifierId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.empid = r.ApproverId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.empid = r.HRId
		LEFT JOIN #tblTotalDaysRequestInMonth AS rm ON r.empID = rm.empid
		AND r.RequestType = rm.RequestType
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS C WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftID = rd.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftID = rd.ToShift
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftID = c.ShiftID
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeID = lr.LeaveType
        AND lv.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId 
		AND (@leaveTypeId IS NULL OR lr.LeaveType = @leaveTypeId)
	ORDER BY r.CreatedDate DESC

	SELECT csrd.RequestId
		,csrd.OnDate
		,csrd.ToDate
	FROM #tblRequestId AS r WITH (NOLOCK)
		INNER JOIN ChangeShiftRequest AS csr WITH (NOLOCK) ON csr.RequestId = r.RequestId
		INNER JOIN ChangeShiftRequestDetail AS csrd WITH (NOLOCK) ON csr.RequestId = csrd.RequestId

	DROP TABLE #tblstatus

	DROP TABLE #tblGroupsList

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblTotalDaysRequestInMonth

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestId
END

GO


ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetRequestByRequestDate_AllType] 
(
    @CompanyId SMALLINT
    ,@SupervisorId INT = NULL
    ,@empid INT = NULL
    ,@TeamIds VARCHAR(MAX) = ''
    ,@fromdate DATETIME
    ,@todate DATETIME
    ,@status VARCHAR(MAX) = NULL
    ,@role VARCHAR(MAX) = ''
    ,@isLocal BIT = NULL
    ,@requestType INT = NULL
    ,@leaveTypeId INT = NULL
)
AS
/*
    Created: Tom.Vo@2013-11-04
    Task: get all emp request list
    DB: bodb_HRM

    Revisions:
        20250403@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	-- work type
	DECLARE @OffDay TINYINT = 1
		,@LeaveDay TINYINT = 2
		,@Onduty TINYINT = 3

	CREATE TABLE #tblstatus (Currentstatus TINYINT)

	CREATE TABLE #tblGroupsList (GroupId INT)

	CREATE TABLE #tblEmployeeId (EmpId INT)

	CREATE TABLE #tblRequestId (RequestId INT)

	CREATE TABLE #tblTotalDaysRequestInMonth (
		empid INT
		,RequestType TINYINT
		,TotalDaysRequest INT
		)

	CREATE TABLE #tblRequestInDaily (
		RequestId BIGINT
		,empid INT
		,RequestType TINYINT
		,InOutMins INT
		,ActualInOutMins INT
		,RequestedTime DATETIME
		,FromDate DATETIME
		,ToDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 1)
		,IsHalfDay BIT
		,IsWarning BIT
		,KeepInViewType TINYINT
		)

	CREATE TABLE #tblGeneralLeaveDetail (
		RequestId BIGINT
		,LeaveCountDetails NVARCHAR(MAX)
		)

	IF ISNULL(@status, '') <> ''
	BEGIN
		INSERT INTO #tblstatus (Currentstatus)
		SELECT value
		FROM STRING_SPLIT(@status, ',')
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupsList (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empid IS NULL
	BEGIN
		IF @SupervisorId IS NULL
			OR @role LIKE '%6%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpID)
			SELECT DISTINCT e.EmpId
			FROM dbo.Employee AS e WITH (NOLOCK)
		END
		ELSE IF @role LIKE '%2%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			EXEC dbo.Request_GetMemberByActorId @EmpId = @SupervisorId
				,@ExcludeUserDelete = 1
				,@IsShowUserInTeam = 0
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 1, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeId (EmpId)
		VALUES (@empid)
	END

	INSERT INTO #tblRequestId (RequestId)
	SELECT r.RequestId
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS eid ON r.EmpId = eid.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = eid.empID
		AND e.isDeleted = 0
		INNER JOIN dbo.EmployeeSummary AS e_s WITH (NOLOCK) ON e_s.EmpId = eid.EmpId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.KeepInViewRequest AS ke WITH (NOLOCK) ON r.RequestId = ke.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS mi WITH (NOLOCK) ON r.RequestId = mi.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
	WHERE (
			@requestType = 0
			OR (
				@requestType = 1
				AND r.RequestType IN (1, 2)
				)
			OR (
				@requestType = 2
				AND r.RequestType IN (3, 4)
				)
			OR (
				@requestType = 3
				AND r.RequestType = 5
				)
			OR (
				@requestType = 4
				AND r.RequestType = 6
				)
			OR (
				@requestType = 5
				AND r.RequestType = 7
				)
			)
		AND (
			(
				@empid IS NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId WITH (NOLOCK)
						WHERE EmpId = r.EmpId
						)
					OR r.VerifierId = @SupervisorID
					OR r.ApproverId = @SupervisorID
					)
				)
			OR (
				@empid IS NOT NULL
				AND EXISTS (
					SELECT 1
					FROM #tblEmployeeId WITH (NOLOCK)
					WHERE EmpId = r.EmpId
					)
				)
			)
		AND (
			ISNULL(@status, '') = ''
			OR r.currentstatus IN (
				SELECT Currentstatus
				FROM #tblstatus WITH (NOLOCK)
				)
			)
		AND (
			e.GroupId IS NULL
			OR e.GroupId IN (
				SELECT GroupId
				FROM #tblGroupsList WITH (NOLOCK)
				)
			)
		AND (
			@isLocal IS NULL
			OR e_s.IsLocal = @isLocal
			)
		AND (
			(
				r.RequestType IN (3, 4)
				AND (
					inout.OnDate BETWEEN @fromdate
						AND @todate
					)
				)
			OR (
				r.RequestType = 6
				AND (
					(
						lr.FromDate >= @fromdate
						AND lr.FromDate <= @todate
						AND lr.ToDate >= @todate
						)
					OR (
						lr.FromDate <= @fromdate
						AND lr.ToDate >= @todate
						)
					OR lr.ToDate BETWEEN @fromdate
						AND @todate
					)
				)
			OR (
				r.RequestType = 7
				AND ke.OnDate BETWEEN @fromdate
					AND @todate
				)
			OR (
				r.RequestType IN (1, 2)
				AND mi.OnDate BETWEEN @fromdate
					AND @todate
				)
			OR (
				r.RequestType = 5
				AND (
					(
						cs.FromDate >= @fromdate
						AND cs.FromDate <= @todate
						AND cs.ToDate >= @todate
						)
					OR (
						cs.FromDate <= @fromdate
						AND cs.FromDate <= @todate
						AND cs.ToDate >= @todate
						)
					OR cs.ToDate BETWEEN @fromdate
						AND @todate
					)
				)
			)
		AND (
			@leaveTypeId IS NULL
			OR lr.LeaveType = @leaveTypeId
			)

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND ee.GroupId IN (
			SELECT GroupId
			FROM #tblGroupsList
			)
		AND (
			DATEDIFF(M, inout.OnDate, @fromdate) = 0
			OR DATEDIFF(M, inout.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND ee.GroupId IN (
			SELECT GroupId
			FROM #tblGroupsList
			)
		AND (
			DATEDIFF(M, lr.FromDate, @fromdate) = 0
			OR DATEDIFF(M, lr.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(M, cs.FromDate, @fromdate) = 0
			OR DATEDIFF(M, cs.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT @empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE wt.EmpId = @empid
		AND wt.currentstatus = 6
		AND DATEDIFF(M, lr.OnDate, @fromdate) = 0
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequest lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND ee.GroupId IN (
			SELECT GroupId
			FROM #tblGroupsList
			)
		AND (
			DATEDIFF(M, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(M, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,ActualInOutMins
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,inout.OnDate
		,inout.OnDate
		,0
		,CASE 
			WHEN wt.RequestType = 3 THEN inout.LateInMins
			ELSE inout.EarlyOutMins
			END
		,CASE 
			WHEN wt.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON inout.EmpId = att.EmpId
		AND inout.OnDate = att.AttendanceDate

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,CASE 
			WHEN ldt.FromTime IS NULL THEN lr.FromDate
			ELSE ldt.FromTime
			END
		,CASE 
			WHEN ldt.ToTime IS NULL THEN lr.ToDate
			ELSE ldt.ToTime
			END
		,lr.TotalDays
		,1
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
	WHERE lr.TotalDays = 0.5
		AND ldt.IsHalfDay = 1

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,0
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE lr.TotalDays <> 0.5

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,FromShift
		,ToShift
		,IsHalfDay
		,KeepInViewType
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.OnDate
		,lr.OnDate
		,lr.OnDate
		,lr.FromTime
		,lr.ToTime
		,CASE 
			WHEN lr.IsHalfDay = 0 THEN 1
			ELSE 0.5
			END TotalDays
		,NULL
		,NULL
		,lr.IsHalfDay
		,lr.KeepInViewType
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,IsWarning
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftID
		,CASE 
			WHEN ISNULL(att.TotalWorkHours, 0) = 0 THEN 1
			ELSE 0
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON lr.OnDate = att.AttendanceDate
		AND lr.EmpId = att.EmpId
	WHERE wt.CurrentStatus = 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftID
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
	WHERE wt.CurrentStatus <> 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate
		,COUNT(1) TotalDays
		,MAX(csd.FromShift) FromShift
		,MAX(csd.ToShift) ToShift
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
		INNER JOIN dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK) ON csd.RequestId = cs.RequestId
	GROUP BY wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate

	INSERT INTO #tblGeneralLeaveDetail (
		RequestId
		,LeaveCountDetails
		)
	SELECT DISTINCT wt.RequestId
		,STUFF((
				SELECT ', ' + CAST(SUM(LeaveDay) AS NVARCHAR(100)) + CASE 
						WHEN SUM(LeaveDay) > 1 THEN ' days '
						ELSE ' day '
						END + Code
				FROM (
					SELECT RequestId
						,CASE 
							WHEN IsOffDay = 1 THEN 'Off'
							ELSE CASE 
									WHEN IsHoliday = 1 THEN 'PH'
									ELSE Code
									END
							END AS Code
						,CASE 
							WHEN IsOffDay <> 1
								AND IsHoliday <> 1 THEN LeaveDay
							ELSE 1
							END AS LeaveDay
					FROM (
						SELECT ldt.RequestId
							,ldt.LeaveType AS LeaveTypeId
							,lt1.Code
							,CASE 
								WHEN ldt.LeaveType <> 0
									AND ldt.IsHalfDay = 0 THEN 1
								WHEN ldt.LeaveType <> 0
									AND ldt.IsHalfDay = 1 THEN 0.5
								ELSE 0
								END AS LeaveDay
							,CASE 
								WHEN (
										ldt.WorkType = 1
										OR (
											WorkType <> @Onduty
											AND cl.IsOffDay = 1
											)
										) THEN 1
								ELSE 0
								END AS IsOffDay
							,CASE 
								WHEN (
										ldt.WorkType = 1
										OR (
											WorkType <> @Onduty
											AND cl.IsHoliday = 1
											)
										) THEN 1
								ELSE 0
								END AS IsHoliday
						FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							INNER JOIN #tblRequestId AS r ON r.RequestId = ldt.RequestId
							LEFT JOIN dbo.LeaveType AS lt1 WITH (NOLOCK) ON lt1.LeaveTypeId = ldt.LeaveType
                            AND lt1.CompanyId = @CompanyId
							LEFT JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON ldt.OnDate = cl.WorkDate
							AND ldt.EmpId = cl.EmpId
						WHERE ldt.WorkType <> @Onduty
						) AS a
					WHERE a.LeaveTypeId <> 0
						OR a.IsOffDay = 1
						OR a.IsHoliday = 1
					) AS b
				WHERE b.RequestId = wt.RequestId
				GROUP BY b.RequestId
					,b.Code
				FOR XML PATH('')
				), 1, 2, '') AS LeaveCountDetails
	FROM (
		SELECT rq.RequestId
			,CreatedDate
			,EmpId
		FROM dbo.WorkingTimeRequest AS rq WITH (NOLOCK)
			INNER JOIN #tblRequestId AS r ON r.RequestId = rq.RequestId
		) AS wt

	SELECT r.RequestId
		,r.RequestType
		,r.Currentstatus AS [Status]
		,r.empID
		,rd.FromDate
		,rd.ToDate
		,rd.TotalDays
		,rd.IsHalfDay
		,rd.RequestedTime AS RequestedDate
		,rd.FromTime
		,rd.ToTime
		,rd.KeepInViewType
		,gdt.LeaveCountDetails
		,lv.LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,r.Remark
		,ISNULL(rm.TotalDaysRequest, 0) TotalDaysRequestInMonth
		,u.Code AS UnitCode
		,CASE 
			WHEN r.RequestType IN (1, 2) THEN inoutmiss.ReasonId
			WHEN r.RequestType IN (3, 4) THEN inout.ReasonId
			ELSE 0
			END [ReasonId]
		,CASE 
			WHEN r.RequestType IN (1, 2, 6, 7) THEN lr.RefNo
			WHEN r.RequestType IN (3, 4) THEN inout.RefNo
			WHEN r.RequestType IN (5) THEN NULL
			END RefNo
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN s1.ShiftID
			ELSE s3.ShiftID END
			) AS FromShiftId
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShiftName
		,s2.ShiftID AS ToShiftId
		,(CASE 
			WHEN s2.ShiftID IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShiftName
		,s2.[Name] AS ToShiftName
		,csr.TypeId AS ChangeShiftType
		,rd.InOutMins AS TotalMinutes
		,rd.ActualInOutMins
		,r.CreatedDate
		,e.EmpId AS RequesterId
		,e.NickName AS RequesterNickName
		,e.FullName AS RequesterFullName
		,g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dep.DepartmentId
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,verifier.EmpId AS VerifierId
		,verifier.NickName AS VerifierNickName
		,verifier.FullName AS VerifierFullName
		,r.VerifiedDate
		,r.VerifiedStatus
		,approver.EmpId AS ApproverId
		,approver.NickName AS ApproverNickName
		,approver.FullName AS ApproverFullName
		,r.ApprovedDate
		,r.ApprovedStatus
		,hr.NickName AS ProcessedByNickName
		,hr.FullName AS ProcessedByFullName
		,r.HRDate AS ProcessedDate
		,r.HRStatus AS ProcessedStatus
		,r.ModifiedDate
		,ISNULL(rd.IsWarning, 0) AS IsWarning
		,r.ReworkCount
		,dbo.fnc_GetAnnualLeaveBalance(r.EmpId, rd.FromDate, r.RequestId) AS AnnualLeaveBalance
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON r.RequestId = rq.RequestId
		INNER JOIN #tblRequestInDaily AS rd ON r.RequestId = rd.RequestID
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = r.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = r.empID
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = dep.UnitId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.empid = r.VerifierId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.empid = r.ApproverId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.empid = r.HRId
		LEFT JOIN #tblTotalDaysRequestInMonth AS rm ON r.empID = rm.empid
		AND r.RequestType = rm.RequestType
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS c WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftID = rd.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftID = rd.ToShift
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftID = c.ShiftID
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeID = lr.LeaveType
        AND lv.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId
	ORDER BY r.CreatedDate DESC

	SELECT csrd.RequestId
		,csrd.OnDate
		,csrd.ToDate
	FROM #tblRequestId AS r
		INNER JOIN ChangeShiftRequest AS csr WITH (NOLOCK) ON csr.RequestId = r.RequestId
		INNER JOIN ChangeShiftRequestDetail AS csrd WITH (NOLOCK) ON csr.RequestId = csrd.RequestId

	DROP TABLE #tblstatus

	DROP TABLE #tblGroupsList

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblTotalDaysRequestInMonth

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestId
END



