/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[Employee_GroupScope_Get] 
	@query NVARCHAR(256) = NULL
	,@teamIds NVARCHAR(MAX) = ''
	,@enable BIT = NULL
	,@isDelete BIT = NULL
	,@pageNumber INT = 1
	,@pageSize INT = 2000
	,@totalRow INT = NULL OUTPUT
	,@titleId INT = NULL
	,@companyIds NVARCHAR(MAX) = ''
AS
/*
	Created: 20250429@Jay.Do
	Task: get employees in group space 
	DB: bodb_HRM
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #GroupsList (GroupId INT)

	INSERT INTO #GroupsList (GroupId)
	SELECT value
	FROM STRING_SPLIT(@teamIds, ',')

	CREATE TABLE #CompaniesList (CompanyId INT)

	INSERT INTO #CompaniesList (CompanyId)
	SELECT value
	FROM STRING_SPLIT(@companyIds, ',')

	IF LEN(@query) = 0
		OR @query LIKE '% or %'
		OR @query LIKE '%--%'
	BEGIN
		SET @query = NULL
	END

	SET @query = REPLACE(@query, '''', '''''')

	DECLARE @q NVARCHAR(256) = @query + '%'''

	SELECT @pageNumber = ISNULL(@pageNumber, 1)
		,@pageSize = ISNULL(@pageSize, 2000)

	DECLARE @SQL NVARCHAR(4000)
		,@sWhere NVARCHAR(4000)
		,@bWhere BIT

	SELECT @SQL = 'SELECT @totalRow = count(1) FROM  dbo.Employee AS e WITH (NOLOCK)
				INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId IN (SELECT CompanyId FROM #CompaniesList) '  + CHAR(13)
				+ 'INNER JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = e.EmpId ' + CHAR(13)

	SELECT @sWhere = ''
		,@bWhere = 0

	IF @enable IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + 'WHERE ISNULL(e.isDeleted, 0) = 0 and e.Enabled = ' + CONVERT(NVARCHAR(10), @enable) + CHAR(13)
			,@bWhere = 1
	END
	ELSE IF @isDelete IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + ' e.isDeleted = ' + CONVERT(NVARCHAR(10), @isDelete) + CHAR(13)
			,@bWhere = 1
	END

	IF @q IS NOT NULL
		AND @query IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + 
				' (e.NickName LIKE ''' + @q + ')' + CHAR(13)
			,@bWhere = 1
	END

	IF ISNULL( @teamIds, '') <> ''
	BEGIN
	SELECT @sWhere = @sWhere + CASE 
			WHEN @bWhere = 1 THEN ' AND '
			ELSE ' WHERE '
			END + ' ( e.GroupId IN (SELECT GroupId FROM #GroupsList) )' + CHAR(13)
		,@bWhere = 1
	END

	IF ISNULL( @companyIds, '') <> ''
	BEGIN
	SELECT @sWhere = @sWhere + CASE 
			WHEN @bWhere = 1 THEN ' AND '
			ELSE ' WHERE '
			END + ' ( ce.CompanyId IN (SELECT CompanyId FROM #CompaniesList) )' + CHAR(13)
		,@bWhere = 1
	END

	IF @titleId IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + ' JobTitleId = ' + CONVERT(NVARCHAR(10), @titleId) + CHAR(13)
			,@bWhere = 1
	END

	SELECT @SQL = @SQL + @sWhere

	PRINT @SQL

	EXEC sp_executesql @SQL
		,N'@totalRow INT OUTPUT'
		,@totalRow = @totalRow OUTPUT

	SELECT @SQL = 'SELECT 
		e.CtrId
		,e.[EmpId]
		,e.[Code] AS EmployeeCode
      ,e.[NickName]
      ,e.[JobTitleId]
      ,e.[Enabled]
      ,e.[JoinedDate]
      ,e.[ResignedDate]
      ,e.[isDeleted]
	  ,e.[FullName]'
	  + ',s.[IsLocal]' + CHAR(13)
	  + ',s.[IsTopManager] AS IsSpecial' + CHAR(13)
	  + ',s.[CompanyDate]' + CHAR(13)
	  + ',jt.Name AS [JobTitle]' + CHAR(13)
	  + ',c.CompanyId' + CHAR(13)
	  + ',c.[Name] AS Company' + CHAR(13)
	  + ',u.[GroupUnitId] AS UnitId' + CHAR(13)
	  + ',u.[Code] AS UnitCode' + CHAR(13)
	  + ',eu.FullName AS UnitPIC' + CHAR(13)
	  + ',g.GroupId AS [TeamId]' + CHAR(13)
	  + ',g.Code AS [TeamCode]' + CHAR(13)
	  + ',g.Name AS [TeamName]' + CHAR(13)
	  + ',eg.FullName AS [TeamPIC]' + CHAR(13)
	  + ',d.DepartmentId' + CHAR(13)
	  + ',d.Code AS DepartmentCode' + CHAR(13)
	  + ',d.[Name] AS DepartmentName' + CHAR(13)
	  + ',ed.FullName AS DepartmentPIC' + CHAR(13)
	  + ',ml.[Name] AS ManagementLevel' + CHAR(13)
	  + ',jl.[Name] AS JobLevel' + CHAR(13)
	  + 'FROM dbo.Employee AS e WITH (NOLOCK)' + CHAR(13)
	  + 'LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId '  + CHAR(13)
	  + 'LEFT JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = e.EmpId' + CHAR(13)
	  + 'LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID' + CHAR(13)
	  + 'LEFT JOIN dbo.[Department] AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId' + CHAR(13)
	  + 'LEFT JOIN dbo.[Unit] AS u WITH (NOLOCK) ON d.UnitId = u.UnitId' + CHAR(13)
	  + 'LEFT JOIN [dbo].[Lookup] AS l WITH(NOLOCK) ON l.Code = ''JT''' + CHAR(13)
	  + 'LEFT JOIN [dbo].[LookupData] AS jt WITH(NOLOCK) ON l.Id = jt.LookupId AND e.JobTitleId = jt.Id' + CHAR(13)
	  + 'LEFT JOIN [dbo].Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId '  + CHAR(13)
	  + 'LEFT JOIN Employee AS eu WITH (NOLOCK) ON eu.EmpId = u.PICEmpId' + CHAR(13)
	  + 'LEFT JOIN Employee AS ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId' + CHAR(13)
	  + 'LEFT JOIN Employee AS eg WITH (NOLOCK) ON eg.EmpId = g.PICEmpId' + CHAR(13)
	  + 'LEFT JOIN [ManagementLevel] AS ml WITH (NOLOCK) ON e.ManagementLevelId = ml.ManagementLevelId' + CHAR(13)
	  + 'LEFT JOIN [JobLevel] AS jl WITH (NOLOCK) ON e.JobLevelId = jl.JobLevelId' + CHAR(13)
	  + @sWhere + 'ORDER BY ' + CHAR(13)

	IF (@enable = 0)
	BEGIN
		SELECT @SQL = @SQL + ' e.ResignedDate DESC,'
	END

	SELECT @SQL = @SQL + 'u.Code DESC' + CHAR(13)
		+ ',d.[Code] DESC' + CHAR(13)
		+ ',g.[Code] DESC' + CHAR(13)
		+ 'OFFSET ' + CONVERT(NVARCHAR(10), (@pageNumber - 1) * @pageSize) + ' ROWS FETCH NEXT ' + CONVERT(NVARCHAR(10), @pageSize) + ' ROWS ONLY;'

	EXEC sp_executesql @SQL

	PRINT @SQL

	DROP TABLE #GroupsList

	DROP TABLE #CompaniesList
END