USE [bodb_HRM]
GO
/****** Object:  StoredProcedure [dbo].[Report_LeaveSummaryForJoinedDate]    Script Date: 5/15/2025 1:49:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_LeaveSummaryForJoinedDate] 
(
    @CompanyId INT
    ,@empid INT = NULL
	,@TeamIds VARCHAR(max) = ''
	,@year INT
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
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE
		-- keep in view type
		@KeepInViewByDay TINYINT = 1


	CREATE TABLE #tmpTeam (GroupId INT)

	CREATE TABLE #tmpEmployee (EmpId INT PRIMARY KEY)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empid IS NULL
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		SELECT DISTINCT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 0, @CompanyId)
	END
	ELSE
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		VALUES (@empid)
	END

	DECLARE @fromdate DATETIME
		,@todate DATETIME

	-- get the first date of year
	SET @fromdate = cast(@year AS VARCHAR(10)) + '/01/01'
	SET @todate = DATEADD(yy, 1, @fromdate)

	-- get the openning balace for annual leave to first date of year
	SELECT e.EmpId AS Empid
		,SUM(ISNULL(tempdata.CreditDays, 0) + ISNULL(tempdata.ExtraDays, 0) - ISNULL(tempdata.DeductDays, 0)) AS OpenBalance
	INTO #tmpOpenBalance
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN #tmpEmployee AS tmpe ON tmpe.EmpId = e.EmpId
        INNER JOIN #tmpTeam AS t ON e.GroupId = t.GroupId
		LEFT JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN (
		    SELECT EmpId, CreditDays, DeductDays, ExtraDays
		    FROM dbo.LeaveTrans WITH (NOLOCK)
		    WHERE ISNULL(Deleted, 0) = 0
			    AND FromDate <= @fromdate
		) tempdata ON e.EmpId = tempdata.Empid
	WHERE (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			ISNULL(e.isDeleted, 0) = 0
			OR YEAR(ResignedDate) >= year(@todate)
			)
	GROUP BY e.EmpId


	-- calculate the balance form the first date of year to @todate
	SELECT e.EmpId
		,ISNULL(CreditDays, 0) AS CreditDays
		,ISNULL(ExtraDays, 0) AS ExtraDays
		,ISNULL(DeductDays, 0) AS DeductDays
		
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
		WHERE YEAR(ltrans.FromDate) = @year
			AND ISNULL(ltrans.Deleted, 0) = 0
		) AS ded ON e.EmpId = ded.EmpId
		LEFT JOIN (
		SELECT ltrans.EmpId
			,SUM(ltrans.CreditDays) CreditDays
		FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
            INNER JOIN #tmpEmployee AS tmpe WITH (NOLOCK) ON tmpe.EmpId = ltrans.EmpId
		WHERE ltrans.FromDate >= @fromdate
			AND ltrans.FromDate < @todate
			AND ISNULL(ltrans.Deleted, 0) <> 1
			AND ltrans.CreditDays > 0
		GROUP BY ltrans.EmpId
		) cred ON e.EmpId = cred.Empid
		LEFT JOIN (
		SELECT ltrans.EmpId
			,SUM(ltrans.ExtraDays)
		FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
            INNER JOIN #tmpEmployee AS tmpe WITH (NOLOCK) ON tmpe.EmpId = ltrans.EmpId
		WHERE ltrans.FromDate >= @fromdate
			AND ltrans.FromDate < @todate
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
			OR YEAR(e.ResignedDate) >= year(@todate)
			)
	--GROUP BY e.EmpId
		--,ISNULL(CreditDays, 0)
		--,ISNULL(ExtraDays, 0)

	SELECT * from #tmpCurrenBalace order by EmpId;
	return;

	-- show the report
	SELECT ISNULL(OpenBalance, 0) AS [AnnualLeaveLastYear]
		,ISNULL(CreditDays, 0) AS [AnnualLeaveCurrentYear]
		,ISNULL(ExtraDays, 0) AS ExtraLeave
		,ISNULL(CreditDays, 0) + ISNULL(ExtraDays, 0) - ISNULL(cb.DeductDays, 0) AS LeaveBalance
		,(cb.Jan) AS Jan
		,(cb.Feb) AS Feb
		,(cb.Mar) AS Mar
		,(cb.Apr) AS Apr
		,(cb.May) AS May
		,(cb.Jun) AS Jun
		,(cb.Jul) AS Jul
		,(cb.Aug) AS Aug
		,(cb.Sep) AS Sep
		,(cb.Oct) AS Oct
		,(cb.Nov) AS Nov
		,(cb.[Dec]) AS [Dec]
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
		LEFT JOIN #tmpOpenBalance AS op ON OP.empid = cb.empid
	WHERE ISNULL(e.[Enabled], 0) = 1
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
	
	UNION ALL
	SELECT ISNULL(OpenBalance, 0) [AnnualLeaveLastYear]
		,0 AS [AnnualLeaveCurrentYear]
		,0 AS ExtraLeave
		,ISNULL(OpenBalance, 0) AS LeaveBalance
		,0 AS Jan
		,0 AS Feb
		,0 AS Mar
		,0 AS Apr
		,0 AS May
		,0 AS Jun
		,0 AS Jul
		,0 AS Aug
		,0 AS Sep
		,0 AS Oct
		,0 AS Nov
		,0 AS [Dec]
		,'' AS Remark
		,op.EmpId
		,e.[Code]
		,FullName
		,Email
		,NickName
		,g.[Rank]
		,g.GroupId AS TeamId
		,g.[Name] AS Team
		,dep.[Name] AS Department
	FROM #tmpOpenBalance AS op
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.Empid = op.Empid
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
	WHERE e.Empid NOT IN (
			SELECT EmpID
			FROM #tmpCurrenBalace AS cb
			)
		AND ISNULL(e.[Enabled], 0) = 1
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
	ORDER BY g.[Name]
		,e.[Code]

    DROP TABLE #tmpEmployee

	DROP TABLE #tmpOpenBalance

	DROP TABLE #tmpCurrenBalace

	DROP TABLE #tmpTeam
END