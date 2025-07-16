/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetEmployees] 
(	
	@query NVARCHAR(256) = NULL
	,@teamIds NVARCHAR(MAX) = ''
	,@enable BIT = NULL
	,@isDelete BIT = NULL
	,@isLocal BIT = NULL
	,@pageNumber INT = 1
	,@pageSize INT = 2000
	,@totalRow INT = NULL OUTPUT
	,@titleId INT = NULL
	,@companyId INT
)
AS
/*
	Created: Tom.Vo@2013-10-23
	Task: Insert default working calendar for employee
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
		-Otis - 03062023: get field ResignedReason
		-Jay  - 04042025: remove Section
		-Henry- 10042025: map Company
		-Henry- 19062025: fix ambiguous column error
		-20250714@Mira: get joblevel and mGrade [#Redmine: 232030]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #GroupsList (GroupId INT)

	INSERT INTO #GroupsList (GroupId)
	SELECT value
	FROM STRING_SPLIT(@teamIds, ',')

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
				INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = ' + CAST(@companyId AS VARCHAR(10))  + CHAR(13)
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
				END + ' (e.NickName LIKE ''' + @q + ' OR e.FullName LIKE N''%' + @q + ' OR e.Code LIKE ''%' + @q + ')' + CHAR(13)
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

	IF @titleId IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + ' JobTitleId = ' + CONVERT(NVARCHAR(10), @titleId) + CHAR(13)
			,@bWhere = 1
	END

	IF @isLocal IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + ' s.IsLocal = ' + CONVERT(NVARCHAR(10), @isLocal) + CHAR(13)
			,@bWhere = 1
	END

	SELECT @SQL = @SQL + @sWhere

	PRINT @SQL

	EXEC sp_executesql @SQL
		,N'@totalRow INT OUTPUT'
		,@totalRow = @totalRow OUTPUT

	SELECT @SQL = 'SELECT e.[EmpId]
      ,e.[Code]
      ,e.[DomainUsername]
      ,[FullName]
      ,[NickName]
      ,[DOB]
      ,e.[Email]
      ,[JobTitleId]
      ,e.[Enabled]
      ,[Phone]
      ,[Gender]
      ,[JoinedDate]
      ,e.[ConfirmedDate]
      ,e.[ResignedDate]
	  ,[ResignedReason]
      ,[Skype]
      ,[LetsTalk]
      ,[Marriage]
      ,[LastLogin]
      ,e.[CreatedDate]
      ,e.[CreatedBy]
      ,e.[ModifiedDate]
      ,e.[ModifiedBy]
      ,e.[isDeleted]
      ,[PermanentAddress]
      ,[CurrentAddress]
      ,[IdCardNumber]
      ,[PassportNo]
      ,[PassportExp]
      ,e.[Password]
      ,[ChineseName]
      ,[PlaceOfbirth]
      ,[Ethnic]
      ,[Native]
      ,[Religion]
      ,[DateOfIDCard]
      ,[PlaceOfIDCard]
      ,[HomePhone]
      ,[Qualification]
      ,[Major]
      ,[PasswordReset]
      ,[EmployeeCard]
	  ,sc.[Name] AS SubCompanyName' + CHAR(13)
	  + ',s.[AnnualLeaveBalance]' + CHAR(13)
	  + ',dbo.fnc_GetKIVBalance(e.EmpId,null) AS KeepInViewBalance' + CHAR(13)
	  + ',s.[CanOT]' + CHAR(13)
	  + ',s.[IsLocal]' + CHAR(13)
	  + ',s.[WorkingDays]' + CHAR(13)
	  + ',s.[WorkingHours]' + CHAR(13)
	  + ',s.[IsDefaultSchedule]' + CHAR(13)
	  + ',s.[CompanyDate]' + CHAR(13)
	  + ',s.[IsTopManager]' + CHAR(13)
	  + ',s.[OffDaysbyWeek]' + CHAR(13)
	  + ',s.CountryCode' + CHAR(13)
	  + ',s.IsExpatUseHoliday' + CHAR(13)
	  + ',ISNULL(ctry.Nationality, ctry.CountryName) CountryName' + CHAR(13)
	  + ',s.MilitaryFromDate' + CHAR(13)
	  + ',s.MilitaryToDate' + CHAR(13)
	  + ',jt.Name AS [JobTitle]' + CHAR(13)
	  + ',jl.[Name] AS JobLevel' + CHAR(13)
	  + ',ml.[Name] AS ManagementLevel' + CHAR(13)
	  + ',c.CompanyId' + CHAR(13)
	  + ',c.[Name] AS CompanyName' + CHAR(13)
	  + ',unit.[Name] AS UnitName' + CHAR(13)
	  + ',unit.[Code] AS UnitCode' + CHAR(13)
	  + ',g.GroupId AS [TeamId]' + CHAR(13)
	  + ',g.Code AS [TeamCode]' + CHAR(13)
	  + ',g.Name AS [TeamName]' + CHAR(13)
	  + ',g.Rank' + CHAR(13)
	  + ',dep.DepartmentId' + CHAR(13)
	  + ',dep.Code AS DepartmentCode' + CHAR(13)
	  + ',dep.[Name] AS DepartmentName' + CHAR(13)
	  + 'FROM dbo.Employee AS e WITH (NOLOCK)' + CHAR(13)
	  + 'INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = ' + CAST(@companyId AS VARCHAR(10))  + CHAR(13)
	  + 'LEFT JOIN dbo.SubCompany sc WITH (NOLOCK) ON ce.SubCompanyId = sc.SubCompanyId' + CHAR(13)
	  + 'INNER JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = e.EmpId' + CHAR(13)
	  + 'LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID' + CHAR(13)
	  + 'INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId' + CHAR(13)
	  + 'INNER JOIN dbo.[Unit] AS unit WITH (NOLOCK) ON dep.UnitId = unit.UnitId' + CHAR(13)
	  + 'LEFT JOIN [dbo].[Country] AS ctry WITH(NOLOCK) ON ctry.CountryCode = s.CountryCode' + CHAR(13)
	  + 'LEFT JOIN [dbo].[Lookup] AS l WITH(NOLOCK) ON l.Code = ''JT''' + CHAR(13)
	  + 'LEFT JOIN [dbo].[LookupData] AS jt WITH(NOLOCK) ON l.Id = jt.LookupId AND e.JobTitleId = jt.Id' + CHAR(13)
	  + 'LEFT JOIN [dbo].Company c WITH (NOLOCK) ON c.CompanyId =' + CAST(@companyId AS VARCHAR(10))  + CHAR(13)
	  + 'LEFT JOIN dbo.[JobLevel] AS jl WITH (NOLOCK) ON jl.JobLevelId = e.JobLevelId' + CHAR(13)
	  + 'LEFT JOIN ManagementLevel ml WITH (NOLOCK) ON e.ManagementLevelId = ml.ManagementLevelId' + CHAR(13)
	  + @sWhere + 'ORDER BY ' + CHAR(13)

	IF (@enable = 0)
	BEGIN
		SELECT @SQL = @SQL + ' e.ResignedDate DESC,'
	END

	SELECT @SQL = @SQL + 'JoinedDate DESC' + CHAR(13)
		+ ',[Code] DESC' + CHAR(13)
		+ ',[NickName]' + CHAR(13)
		+ 'OFFSET ' + CONVERT(NVARCHAR(10), (@pageNumber - 1) * @pageSize) + ' ROWS FETCH NEXT ' + CONVERT(NVARCHAR(10), @pageSize) + ' ROWS ONLY;'

	EXEC sp_executesql @SQL

	SELECT EmployeeId
		,RoleId
	FROM dbo.EmployeeRole AS emRo WITH (NOLOCK)

	PRINT @SQL

	DROP TABLE #GroupsList
END