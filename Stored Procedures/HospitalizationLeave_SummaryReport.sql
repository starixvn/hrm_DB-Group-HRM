
/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[HospitalizationLeave_SummaryReport] @EmpId INT = NULL
	,@TeamIds VARCHAR(max) = ''
	,@Year INT
	,@isLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@CompanyId INT
AS
/*
	Created: Tim.Trinh@2021-08-19
	Task: hospitalization leave summary
	DB: HRM_SMS
	Original:

	Revisions:
		- 20250408@Hank: remove section [Redmine: #222886]
		- 20250821@Jay: restructure for transfer [Redmine: #235678]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblGroupId (GroupId INT)

	CREATE TABLE #tblEmployeeId (EmpId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupId (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empid IS NULL
	BEGIN
		INSERT INTO #tblEmployeeId (EmpId)
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 0, @CompanyId)
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeId (EmpId)
		VALUES (@EmpId)
	END

	DECLARE @fromdate DATETIME
		,@todate DATETIME

	SET @fromdate = CAST(@Year AS VARCHAR(10)) + '/01/01'
	SET @todate = DATEADD(yy, 1, @fromdate)

	SELECT ce.EmpId
		,ISNULL(credit.CreditDays, 0) AS CreditDays
		,SUM(ISNULL(deduct.DeductDays, 0)) AS DeductDays
		,SUM(CASE 
				WHEN MONTH(FromDate) = 1 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Jan
		,SUM(CASE 
				WHEN MONTH(FromDate) = 2 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Feb
		,SUM(CASE 
				WHEN MONTH(FromDate) = 3 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Mar
		,SUM(CASE 
				WHEN MONTH(FromDate) = 4 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Apr
		,SUM(CASE 
				WHEN MONTH(FromDate) = 5 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS May
		,SUM(CASE 
				WHEN MONTH(FromDate) = 6 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Jun
		,SUM(CASE 
				WHEN MONTH(FromDate) = 7 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Jul
		,SUM(CASE 
				WHEN MONTH(FromDate) = 8 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Aug
		,SUM(CASE 
				WHEN MONTH(FromDate) = 9 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Sep
		,SUM(CASE 
				WHEN MONTH(FromDate) = 10 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Oct
		,SUM(CASE 
				WHEN MONTH(FromDate) = 11 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS Nov
		,SUM(CASE 
				WHEN MONTH(FromDate) = 12 THEN ISNULL(DeductDays, 0)
				ELSE 0
				END) AS [DEC]
	INTO #tblCurrenBalace
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN Employee e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN #tblEmployeeId AS tblemp WITH (NOLOCK) ON ce.EmpId = tblemp.EmpId
		INNER JOIN #tblGroupId AS tblgr WITH (NOLOCK) ON ce.GroupId = tblgr.GroupId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		LEFT JOIN dbo.HospitalizationLeaveTrans AS deduct WITH (NOLOCK) ON ce.EmpId = deduct.EmpId
		AND YEAR(deduct.FromDate) = @Year
		AND deduct.IsDeleted = 0
		LEFT JOIN (
		SELECT EmpId
			,SUM(CreditDays) CreditDays
		FROM dbo.HospitalizationLeaveTrans WITH (NOLOCK)
		WHERE FromDate >= @fromdate
			AND FromDate < @todate
			AND IsDeleted = 0
			AND CreditDays > 0
		GROUP BY EmpId
		) credit ON ce.EmpId = credit.EmpId
	WHERE (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			ISNULL(ce.isDeleted, 0) = 0
			OR YEAR(e.ResignedDate) >= year(@todate)
			)
	GROUP BY ce.EmpId
		,ISNULL(credit.CreditDays, 0)

	SELECT ce.EmpId
		,ce.Code
		,e.FullName
		,ce.NickName
		,gr.[Name] AS Team
		,dep.[Name] AS Department
		,ISNULL(cb.CreditDays, 0) AS Balance
		,cb.Jan
		,cb.Feb
		,cb.Mar
		,cb.Apr
		,cb.May
		,cb.Jun
		,cb.Jul
		,cb.Aug
		,cb.Sep
		,cb.Oct
		,cb.Nov
		,cb.[Dec]
		,ISNULL(cb.CreditDays, 0) - ISNULL(cb.DeductDays, 0) AS RemainingBalance
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN Employee e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN #tblEmployeeId AS tblemp WITH (NOLOCK) ON ce.EmpId = tblemp.EmpId
		INNER JOIN #tblGroupId AS tblgr WITH (NOLOCK) ON ce.GroupId = tblgr.GroupId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		LEFT JOIN #tblCurrenBalace AS cb WITH (NOLOCK) ON ce.EmpId = cb.EmpId
	WHERE ISNULL(ce.[Enabled], 0) = 1
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
	ORDER BY gr.[Name]
		,ce.Code

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblGroupId

	DROP TABLE #tblCurrenBalace
END



