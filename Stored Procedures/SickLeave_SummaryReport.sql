/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SickLeave_SummaryReport] @EmpId INT = NULL
	,@TeamIds VARCHAR(max) = ''
	,@Year INT
	,@isLocal BIT = NULL
	,@CompanyId INT
	,@EmployeeStatusIds VARCHAR(10) = ''
AS
/*
	Created: Tim.Trinh@2021-08-23
	Task: sick leave summary
	DB: HRM_SMS
	Original:

	Revisions:
		- 20250408@Hank: remove section [Redmine: #222886]
		20251001@Mira: Get employee by data permission [Redmine: #240215]
		20251001@Mira: Get employee by data permission [Redmine: #240215]
		20251203@Jay: enhance sick leave [Redmine: #245871]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblGroupId (GroupId INT)
    DECLARE @tblStatus TABLE (Id TINYINT)
	DECLARE @Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupId (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

    IF ISNULL(@EmployeeStatusIds, '') != ''
    BEGIN
        INSERT INTO @tblStatus (Id)
	    SELECT value
	    FROM STRING_SPLIT(@EmployeeStatusIds, ',')
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
	FROM dbo.CompanyEmployee AS emp WITH (NOLOCK)
		INNER JOIN #tblGroupId AS tblgr WITH (NOLOCK) ON emp.GroupId = tblgr.GroupId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = emp.UserId
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
			OR YEAR(e.ResignedDate) >= year(@todate)
			)
		AND (@EmpId IS NULL OR emp.EmpId = @EmpId)
	GROUP BY emp.EmpId
		,ISNULL(credit.CreditDays, 0)

	SELECT ce.EmpId
		,ce.Code
		,e.FullName
		,ce.NickName
        ,[Enabled]
        ,ce.IsDeleted
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
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN #tblGroupId AS tblgr WITH (NOLOCK) ON ce.GroupId = tblgr.GroupId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		LEFT JOIN #tblCurrenBalace AS cb WITH (NOLOCK) ON ce.EmpId = cb.EmpId
	WHERE (
			ISNULL(@EmployeeStatusIds, '') = ''
            OR EXISTS (
                SELECT 1
                FROM @tblStatus AS s
                WHERE (s.Id = @Enable AND ce.[Enabled] = 1 AND ce.isDeleted = 0)
                    OR (s.Id = @Disabled AND ce.[Enabled] = 0 AND ce.isDeleted = 0)
                    OR (s.Id = @Deleted AND ce.isDeleted = 1)
                )
			)
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (@EmpId IS NULL OR ce.EmpId = @EmpId)
	ORDER BY gr.[Name] ASC
		,ce.Code ASC

	DROP TABLE #tblGroupId

	DROP TABLE #tblCurrenBalace
END