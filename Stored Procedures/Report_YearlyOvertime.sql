/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_YearlyOvertime]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@MonthXml VARCHAR(MAX)
	,@TeamIds VARCHAR(MAX) = ''
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
	,@IsLocal BIT = NULL
)
AS
/*
    Created: Tim.Trinh@2019-07-09
    Task: Get yearly overtime
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
    Param's Explanation:
        @MonthXml: <ROOT><Row Month='{0}' FromDate='{1}' ToDate='{2}' /></ROOT>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DocHandler INT
		-- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- request status
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6

	CREATE TABLE #tblEmployeeIds (EmpId INT)

	CREATE TABLE #tblGroupIds (GroupId INT)

	CREATE TABLE #tblMonth (
		[Month] TINYINT
		,FromDate DATE
		,ToDate DATE
		)

	CREATE TABLE #tblOvertimeSummary (
		EmpId INT
		,[Month] TINYINT
		,NormalHours DECIMAL(18, 2)
		,OffHours DECIMAL(18, 2)
		,PublicHours DECIMAL(18, 2)
		,SpecialHours DECIMAL(18, 2)
		)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@MonthXml

	INSERT INTO #tblMonth (
		[Month]
		,FromDate
		,ToDate
		)
	SELECT [Month]
		,FromDate
		,ToDate
	FROM OPENXML(@DocHandler, '/ROOT/Row', 1) WITH ([Month] TINYINT, FromDate DATE, ToDate DATE) AS Data

	EXEC sp_xml_removedocument @DocHandler

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblGroupIds AS tblgr WITH (NOLOCK) ON emp.GroupId = tblgr.GroupId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId AND empsum.IsTopManager = 0
		INNER JOIN (
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)
		) AS [member] ON emp.EmpId = [member].EmpId
	WHERE (
			@EmployeeStatusId IS NULL
			OR (
				@EmployeeStatusId = @Enable
				AND emp.[Enabled] = 1
				AND emp.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Disabled
				AND emp.[Enabled] = 0
				AND emp.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Deleted
				AND emp.isDeleted = 1
				)
			)
		AND (
			emp.NickName LIKE '%' + ISNULL(@Employee, '') + '%'
			OR emp.FullName LIKE '%' + ISNULL(@Employee, '') + '%'
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)

	INSERT INTO #tblOvertimeSummary (
		EmpId
		,[Month]
		,NormalHours
		,OffHours
		,PublicHours
		,SpecialHours
		)
	SELECT req.EmpId
		,tbl.[Month]
		,SUM(req.NormalHours)
		,SUM(req.OffHours)
		,SUM(req.PublicHours)
		,SUM(ISNULL(req.SpecialHours, 0))
	FROM dbo.OTDailyRequest AS req WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON req.EmpId = emp.EmpId
		INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmpId
		INNER JOIN #tblMonth AS tbl ON req.OvertimeDate BETWEEN tbl.FromDate
			AND tbl.ToDate
	WHERE req.[Status] IN (@ApprovedStatusId, @ProcessedStatusId)
	GROUP BY req.EmpId
		,tbl.[Month]

	SELECT EmpId
		,Code
		,NickName
		,FullName
		,TeamId
        ,TeamCode
		,TeamName
		,DepartmentCode
		,DepartmentName
		,ISNULL([1], 0) AS Jan
		,ISNULL([2], 0) AS Feb
		,ISNULL([3], 0) AS Mar
		,ISNULL([4], 0) AS Apr
		,ISNULL([5], 0) AS May
		,ISNULL([6], 0) AS Jun
		,ISNULL([7], 0) AS Jul
		,ISNULL([8], 0) AS Aug
		,ISNULL([9], 0) AS Sep
		,ISNULL([10], 0) AS Oct
		,ISNULL([11], 0) AS Nov
		,ISNULL([12], 0) AS [Dec]
	FROM (
		SELECT emp.EmpId
			,emp.Code
			,emp.NickName
			,emp.FullName
			,gr.GroupId AS TeamId
			,gr.Code AS TeamCode
			,gr.[Name] AS TeamName
			,dept.Code as DepartmentCode
            ,dept.[Name] AS DepartmentName
			,cl.[Month] AS [Month]
			,(otsum.NormalHours + otsum.OffHours + otsum.PublicHours + otsum.SpecialHours) AS TotalHours
		FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmpId
			INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
			INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON gr.DepartmentId = dept.DepartmentId
			CROSS JOIN #tblMonth AS cl
			INNER JOIN #tblOvertimeSummary AS otsum ON emp.EmpId = otsum.EmpId
			AND cl.[Month] = otsum.[Month]
		) AS tmp
	PIVOT(MAX(TotalHours) FOR [Month] IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12])) AS tmp2
	ORDER BY NickName

	DROP TABLE #tblEmployeeIds

	DROP TABLE #tblGroupIds

	DROP TABLE #tblMonth

	DROP TABLE #tblOvertimeSummary
END