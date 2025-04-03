/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SickLeave_SummaryReport] @EmpId INT = NULL
	,@TeamIds VARCHAR(max) = ''
	,@Year INT
	,@isLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@CompanyId INT
AS
/*
Created: Tim.Trinh@2021-08-23
Task: sick leave summary
DB: HRM_SMS
Original:

Revisions:
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

	SELECT emp.EmpId
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
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		INNER JOIN #tblGroupId AS tblgr WITH (NOLOCK) ON emp.GroupId = tblgr.GroupId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
		LEFT JOIN dbo.SickLeaveTrans AS deduct WITH (NOLOCK) ON emp.EmpId = deduct.EmpId
		AND YEAR(deduct.FromDate) = @Year
		AND deduct.IsDeleted = 0
		LEFT JOIN (
		SELECT EmpId
			,SUM(CreditDays) CreditDays
		FROM dbo.SickLeaveTrans WITH (NOLOCK)
		WHERE FromDate >= @fromdate
			AND FromDate < @todate
			AND IsDeleted = 0
			AND CreditDays > 0
		GROUP BY EmpId
		) credit ON emp.EmpId = credit.EmpId
	WHERE (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			ISNULL(emp.isDeleted, 0) = 0
			OR YEAR(emp.ResignedDate) >= year(@todate)
			)
	GROUP BY emp.EmpId
		,ISNULL(credit.CreditDays, 0)

	SELECT emp.EmpId
		,emp.Code
		,emp.FullName
		,emp.NickName
		,gr.[Name] AS Team
		,sec.[Name] AS Section
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
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		INNER JOIN #tblGroupId AS tblgr WITH (NOLOCK) ON emp.GroupId = tblgr.GroupId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.Section AS sec WITH (NOLOCK) ON sec.SectionId = gr.SectionId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = sec.DepartmentId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
		LEFT JOIN #tblCurrenBalace AS cb WITH (NOLOCK) ON emp.EmpId = cb.EmpId
	WHERE ISNULL(emp.[Enabled], 0) = 1
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
	ORDER BY gr.[Name]
		,emp.Code

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblGroupId

	DROP TABLE #tblCurrenBalace
END





