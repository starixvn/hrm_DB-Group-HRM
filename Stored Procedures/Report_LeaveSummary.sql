/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Report_LeaveSummary] @empid INT = NULL
	,@TeamIds VARCHAR(max) = ''
	,@year INT
	,@isLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@role VARCHAR(max) = ''
	,@CompanyId INT
AS
/*
	Created: Tom.Vo@2013-11-21
	Task: leave summary report
	DB: HRM_SMS
	Original:

	Revisions:
	 - 20250408@Hank: remove section [Redmine: #222886]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE
		-- keep in view type
		@KeepInViewByDay TINYINT = 1

	CREATE TABLE #DeductKIV (
		EmpId INT
		,WorkDate DATETIME
		,DeductDays DECIMAL(18, 12)
		)

	CREATE TABLE #tmpOwner (OwnerId INT)

	CREATE TABLE #GroupsList (GroupId INT)

	CREATE TABLE #EmployeeId (EmpId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #GroupsList (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END
		
	--ELSE
	--BEGIN
	--	IF EXISTS (
	--			SELECT 1
	--			FROM dbo.Employee AS e WITH (NOLOCK)
	--				INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON e.EmpId = er.EmployeeId
	--			WHERE EmpId = @SupervisorId
	--				AND er.RoleId IN (2, 3, 4, 5, 6, 7)
	--			)
	--	BEGIN
	--		INSERT INTO #GroupsList (GroupId)
	--		SELECT GroupId
	--		FROM dbo.[Group] WITH (NOLOCK)
	--	END
	--END
	IF @empid IS NULL
	BEGIN
		INSERT INTO #EmployeeId (EmpId)
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 0, @CompanyId)
	END
	ELSE
	BEGIN
		INSERT INTO #EmployeeId (EmpId)
		VALUES (@empid)
	END

	DECLARE @fromdate DATETIME
		,@todate DATETIME

	-- get the first date of year
	SET @fromdate = cast(@year AS VARCHAR(10)) + '/01/01'
	SET @todate = DATEADD(yy, 1, @fromdate)

	-- get the openning balace for annual leave to first date of year
	SELECT e.EmpId AS Empid
		,SUM(ISNULL(CreditDays, 0) - ISNULL(DeductDays, 0)) AS OpenBalance
	INTO #OpenBalance
	FROM dbo.Employee AS e WITH (NOLOCK)
		LEFT JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN (
		SELECT *
		FROM dbo.LeaveTrans WITH (NOLOCK)
		WHERE ISNULL(Deleted, 0) = 0
			AND FromDate <= @fromdate
		) t ON e.EmpId = t.Empid
	WHERE EXISTS (
			SELECT 1
			FROM #EmployeeId
			WHERE e.EmpId = EmpId
			)
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			--@Teamids IS NULL OR
			--@Teamids = '' OR
			e.GroupId IN (
				SELECT GroupId
				FROM #GroupsList
				)
			)
		AND (
			ISNULL(e.isDeleted, 0) = 0
			OR YEAR(ResignedDate) >= year(@todate)
			)
	GROUP BY e.EmpId

	SELECT w.EmpId AS EmpId
		,SUM(CASE 
				WHEN kiv.IsHalfDay = 1 THEN 0.5
				ELSE 1
				END) AS OpenKIV
	INTO #CreditKIV
	FROM dbo.WorkingTimeRequest AS w WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON w.RequestId = kiv.RequestId
		AND kiv.OnDate BETWEEN @fromdate
			AND @todate
	WHERE w.CurrentStatus IN (4, 6)
		AND kiv.KeepInViewType = @KeepInViewByDay
	GROUP BY w.EmpId

	-- KIV leave
	INSERT #DeductKIV (
		EmpId
		,WorkDate
		,DeductDays
		)
	SELECT cl.EmpId AS EmpId
		,cl.WorkDate AS WorkDate
		,CAST((CASE 
				WHEN rq.TotalDays > 1 THEN 1
				ELSE rq.TotalDays END
				) AS DECIMAL(18, 2)) AS DeductDays
	FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
		LEFT JOIN (
		SELECT w.RequestId
			,w.EmpId
			,w.CurrentStatus
			,lv.FromDate
			,lv.ToDate
			,lv.TotalDays
			,lv.LeaveType
		FROM dbo.LeaveRequest AS lv WITH (NOLOCK)
			INNER JOIN dbo.WorkingTimeRequest AS w WITH (NOLOCK) ON lv.RequestId = w.RequestId
		WHERE lv.LeaveType = 10
		) AS rq ON cl.EmpId = rq.EmpId
		AND cl.WorkDate BETWEEN rq.FromDate
			AND rq.ToDate
	WHERE EXISTS (
			SELECT 1
			FROM #EmployeeId
			WHERE EmpId = cl.EmpId
			)
		AND cl.IsLeaveDay = 1
		AND cl.WorkDate BETWEEN rq.FromDate
			AND rq.ToDate
		AND rq.CurrentStatus IN (4, 6)
		AND cl.WorkDate BETWEEN @fromdate
			AND DATEADD(dd, - 1, @todate)

	-- General leave
	INSERT #DeductKIV (
		EmpId
		,WorkDate
		,DeductDays
		)
	SELECT ldt.EmpId
		,ldt.OnDate AS WorkDate
		,CAST((CASE 
				WHEN IsHalfDay = 1 THEN 0.5
				ELSE 1 END
				) AS DECIMAL(18, 2)) AS DeductDays
	FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lv WITH (NOLOCK) ON ldt.RequestId = lv.RequestId
		INNER JOIN dbo.WorkingTimeRequest AS w WITH (NOLOCK) ON ldt.RequestId = w.RequestId
	WHERE ldt.LeaveType = 10
		AND lv.LeaveType = 0
		AND w.CurrentStatus IN (4, 6)
		AND ldt.OnDate BETWEEN @fromdate
			AND DATEADD(dd, - 1, @todate)
		AND EXISTS (
			SELECT 1
			FROM #EmployeeId
			WHERE EmpId = ldt.EmpId
			)

	SELECT EmpId
		,SUM(DeductDays) AS DeductKIVDays
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 1 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Jan
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 2 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Feb
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 3 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Mar
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 4 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Apr
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 5 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS May
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 6 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Jun
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 7 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Jul
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 8 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Aug
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 9 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Sep
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 10 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Oct
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 11 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Nov
		,SUM(CASE 
				WHEN MONTH(WorkDate) = 12 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS [Dec]
	INTO #CurrentKIV
	FROM #DeductKIV
	GROUP BY EmpId

	-- calculate the balance form the first date of year to @todate
	SELECT e.EmpId
		,(ISNULL(CreditDays, 0)) CreditDays
		,SUM(ISNULL(DeductDays, 0)) DeductDays
		,SUM(CASE 
				WHEN MONTH(FromDate) = 1 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Jan
		,SUM(CASE 
				WHEN MONTH(FromDate) = 2 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Feb
		,SUM(CASE 
				WHEN MONTH(FromDate) = 3 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Mar
		,SUM(CASE 
				WHEN MONTH(FromDate) = 4 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Apr
		,SUM(CASE 
				WHEN MONTH(FromDate) = 5 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) May
		,SUM(CASE 
				WHEN MONTH(FromDate) = 6 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Jun
		,SUM(CASE 
				WHEN MONTH(FromDate) = 7 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Jul
		,SUM(CASE 
				WHEN MONTH(FromDate) = 8 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Aug
		,SUM(CASE 
				WHEN MONTH(FromDate) = 9 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Sep
		,SUM(CASE 
				WHEN MONTH(FromDate) = 10 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Oct
		,SUM(CASE 
				WHEN MONTH(FromDate) = 11 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) Nov
		,SUM(CASE 
				WHEN MONTH(FromDate) = 12 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) DEC
	INTO #CurrenBalace
	FROM dbo.Employee AS e WITH (NOLOCK)
		LEFT JOIN (
		SELECT EmpId
			,DeductDays
			,FromDate
		FROM dbo.LeaveTrans WITH (NOLOCK)
		WHERE YEAR(FromDate) = @year
			AND ISNULL(Deleted, 0) = 0
		) AS ded ON e.EmpId = ded.EmpId
		LEFT JOIN (
		SELECT lt.EmpId
			,SUM(CreditDays) CreditDays
		FROM dbo.LeaveTrans AS lt WITH (NOLOCK)
		WHERE FromDate >= @fromdate
			AND FromDate < @todate
			AND ISNULL(Deleted, 0) <> 1
			AND CreditDays > 0
			AND ISNULL(Deleted, 0) <> 1
		GROUP BY lt.EmpId
		) Cred ON e.EmpId = Cred.Empid
		LEFT JOIN EmployeeSummary es WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE EXISTS (
			SELECT 1
			FROM #EmployeeId
			WHERE e.EmpId = EmpId
			)
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			--@Teamids IS NULL OR
			--@Teamids = '' OR
			e.GroupId IN (
				SELECT GroupId
				FROM #GroupsList
				)
			)
		AND (
			ISNULL(e.isDeleted, 0) = 0
			OR YEAR(ResignedDate) >= year(@todate)
			)
	GROUP BY e.EmpId
		,(ISNULL(CreditDays, 0))

	-- show the report
	SELECT ISNULL(OpenKIV, 0) AS CreditKIV
		,ISNULL(OpenBalance, 0) AS [AnnualLeaveLastYear]
		,ISNULL(CreditDays, 0) AS [AnnualLeaveCurrentYear]
		,(cb.Jan + ISNULL(dek.Jan, 0)) AS Jan
		,(cb.Feb + ISNULL(dek.Feb, 0)) AS Feb
		,(cb.Mar + ISNULL(dek.Mar, 0)) AS Mar
		,(cb.Apr + ISNULL(dek.Apr, 0)) AS Apr
		,(cb.May + ISNULL(dek.May, 0)) AS May
		,(cb.Jun + ISNULL(dek.Jun, 0)) AS Jun
		,(cb.Jul + ISNULL(dek.Jul, 0)) AS Jul
		,(cb.Aug + ISNULL(dek.Aug, 0)) AS Aug
		,(cb.Sep + ISNULL(dek.Sep, 0)) AS Sep
		,(cb.Oct + ISNULL(dek.Oct, 0)) AS Oct
		,(cb.Nov + ISNULL(dek.Nov, 0)) AS Nov
		,(cb.[Dec] + ISNULL(dek.[Dec], 0)) AS [Dec]
		,ISNULL(CreditDays, 0) - ISNULL(cb.DeductDays, 0) AS LeaveBalance
		,ISNULL(OpenKIV, 0) - ISNULL(dek.DeductKIVDays, 0) AS KIVBalance
		,'' AS Remark
		,cb.EmpId
		,e.Code
		,FullName
		,Email
		,NickName
		,g.[Rank]
		,g.GroupId AS TeamId
		,g.[Name] AS Team
		,dep.Name AS Department
	FROM #CurrenBalace AS cb
		LEFT JOIN #OpenBalance AS op ON OP.empid = cb.empid
		LEFT JOIN #CreditKIV AS crk ON cb.EmpId = crk.EmpId
		LEFT JOIN #CurrentKIV AS dek ON cb.EmpId = dek.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = cb.Empid
		LEFT JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
	WHERE ISNULL(e.[Enabled], 0) = 1
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
	
	UNION ALL
	SELECT ISNULL(OpenKIV, 0) AS CreditKIV
		,ISNULL(OpenBalance, 0) [AnnualLeaveLastYear]
		,0 AS [AnnualLeaveCurrentYear]
		,dek.Jan
		,dek.Feb
		,dek.Mar
		,dek.Apr
		,dek.May
		,dek.Jun
		,dek.Jul
		,dek.Aug
		,dek.Sep
		,dek.Oct
		,dek.Nov
		,dek.[Dec]
		,ISNULL(OpenBalance, 0) AS LeaveBalance
		,ISNULL(OpenKIV, 0) - ISNULL(dek.DeductKIVDays, 0) AS KIVBalance
		,'' AS Remark
		,op.EmpId
		,e.[Code]
		,FullName
		,Email
		,NickName
		,g.[Rank]
		,g.GroupId AS TeamId
		,g.[Name] AS Team
		,dep.Code AS Department
	FROM #OpenBalance AS op
		LEFT JOIN #CreditKIV AS kiv ON op.EmpId = kiv.EmpId
		LEFT JOIN #CurrentKIV AS dek ON op.EmpId = dek.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.Empid = op.Empid
		LEFT JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
	WHERE e.Empid NOT IN (
			SELECT EmpID
			FROM #CurrenBalace AS cb
			)
		AND ISNULL(e.[Enabled], 0) = 1
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
	ORDER BY g.[Name]
		,e.[Code]

	DROP TABLE #OpenBalance

	DROP TABLE #CurrenBalace

	DROP TABLE #CreditKIV

	DROP TABLE #DeductKIV

	DROP TABLE #CurrentKIV

	DROP TABLE #GroupsList
END

