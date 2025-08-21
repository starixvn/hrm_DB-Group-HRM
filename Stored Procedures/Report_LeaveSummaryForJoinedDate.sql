/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_LeaveSummaryForJoinedDate] 
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
		20250812@Mira: change DB structure [Redmine: #235678]

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
		ce.EmpId,
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
	FROM dbo.CompanyEmployee ce WITH (NOLOCK)
	INNER JOIN dbo.Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
	WHERE ce.EmpId IN (SELECT EmpId FROM #tmpEmployee)


	-- calculate the balance for the current range
	SELECT ce.EmpId
		,ISNULL(CreditDays, 0) AS CreditDays
		,ISNULL(ExtraDays, 0) AS ExtraDays
		,SUM(ISNULL(DeductDays, 0)) AS DeductDays
		,MIN(cred.FromDate) AS FromDate
	INTO #tmpCurrenBalace
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
        INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
        INNER JOIN #tmpEmployee AS tmpe WITH (NOLOCK) ON tmpe.EmpId = ce.EmpId
        INNER JOIN #tmpTeam AS t WITH (NOLOCK) ON ce.GroupId = t.GroupId
		LEFT JOIN (
		SELECT ltrans.EmpId
			,ltrans.DeductDays
			,ltrans.FromDate
		FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
            INNER JOIN #tmpEmployee AS tmpe WITH (NOLOCK) ON tmpe.EmpId = ltrans.EmpId
		WHERE ltrans.FromDate >= (SELECT RangeStartDate FROM #tmpLeaveRange WHERE EmpId = ltrans.EmpId)
			AND ltrans.ToDate <= (SELECT RangeEndDate FROM #tmpLeaveRange WHERE EmpId = ltrans.EmpId)
			AND ISNULL(ltrans.Deleted, 0) = 0
		) AS ded ON ce.EmpId = ded.EmpId
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
		) extra ON ce.EmpId = extra.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
	WHERE (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			ISNULL(ce.isDeleted, 0) = 0
			OR YEAR(e.ResignedDate) >= YEAR(@fromDate)
			)
	GROUP BY ce.EmpId
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
		,ce.Code
		,FullName
		,Email
		,NickName
		,g.[Rank]
		,g.GroupId AS TeamId
		,g.[Name] AS Team
		,dep.[Name] AS Department
	FROM #tmpCurrenBalace AS cb
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = cb.Empid
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = ce.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId

	WHERE ISNULL(ce.[Enabled], 0) = 1
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
	ORDER BY g.[Name]
		,ce.[Code]
	

    DROP TABLE #tmpEmployee
	DROP TABLE #tmpCurrenBalace
	DROP TABLE #tmpTeam
	DROP TABLE #tmpLeaveRange
END