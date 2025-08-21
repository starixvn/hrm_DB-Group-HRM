/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetEmployees] 
(	
	@query NVARCHAR(256) = NULL,
	@teamIds NVARCHAR(MAX) = '',
	@enable BIT = NULL,
	@isDelete BIT = NULL,
	@isLocal BIT = NULL,
	@pageNumber INT = 1,
	@pageSize INT = 2000,
	@totalRow INT = NULL OUTPUT,
	@titleId INT = NULL,
	@companyId INT
)
AS
/*
	Created: Tom.Vo@2013-10-23
	Task: Get employees with filtering and pagination
	DB: HRM_SMS

	Revisions:
		-Otis - 03062023: get field ResignedReason
		-Jay  - 04042025: remove Section
		-Henry- 10042025: map Company
		-Henry- 19062025: fix ambiguous column error
		-20250714@Mira: get joblevel and mGrade [#Redmine: 232030]
		-20250115: Converted from dynamic SQL to normal SQL for better readability
		20250812@Mira: tranfer employee [Redmine: #235678]
*/
BEGIN
	SET NOCOUNT ON;

	-- Input validation
	IF @companyId IS NULL
	BEGIN
		RAISERROR('Company ID is required', 16, 1);
		RETURN;
	END

	-- Set default values
	SET @pageNumber = ISNULL(@pageNumber, 1);
	SET @pageSize = ISNULL(@pageSize, 2000);
	
	-- Clean up query parameter
	IF LEN(ISNULL(@query, '')) = 0 
		OR @query LIKE '% or %'
		OR @query LIKE '%--%'
	BEGIN
		SET @query = NULL;
	END

	-- Get total count for pagination
	SELECT @totalRow = COUNT(1) 
	FROM dbo.Employee AS e WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.UserId = e.UserId AND ce.CompanyId = @companyId
	INNER JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = ce.EmpId
	WHERE (@enable IS NULL OR ce.Enabled = @enable)
		AND (@isDelete IS NULL OR ISNULL(ce.isDeleted, 0) = @isDelete)
		AND (@query IS NULL OR (
			ce.NickName LIKE '%' + @query + '%' 
			OR e.FullName LIKE N'%' + @query + '%' 
			OR ce.Code LIKE '%' + @query + '%'
		))
		AND (@teamIds = '' OR @teamIds IS NULL OR ce.GroupId IN (
			SELECT CAST(value AS INT) FROM STRING_SPLIT(@teamIds, ',')
		))
		AND (@titleId IS NULL OR ce.JobTitleId = @titleId)
		AND (@isLocal IS NULL OR s.IsLocal = @isLocal);

	-- Main query with pagination
	SELECT 
		ce.EmpId,
		ce.[Code],
		ce.[DomainUsername],
		e.[FullName],
		ce.[NickName],
		e.[DOB],
		ce.[Email],
		ce.[JobTitleId],
		ce.[Enabled],
		[Phone],
		[Gender],
		[JoinedDate],
		e.[ConfirmedDate],
		e.[ResignedDate],
		[ResignedReason],
		[Skype],
		[LetsTalk],
		[Marriage],
		[LastLogin],
		ce.[CreatedDate],
		ce.[CreatedBy],
		ce.[ModifiedDate],
		ce.[ModifiedBy],
		ce.[isDeleted],
		[PermanentAddress],
		[CurrentAddress],
		[IdCardNumber],
		[PassportNo],
		[PassportExp],
		e.[Password],
		[ChineseName],
		[PlaceOfbirth],
		[Ethnic],
		[Native],
		[Religion],
		[DateOfIDCard],
		[PlaceOfIDCard],
		[HomePhone],
		[Qualification],
		[Major],
		[PasswordReset],
		ce.[EmployeeCard],
		sc.[Name] AS SubCompanyName,
		s.[AnnualLeaveBalance],
		dbo.fnc_GetKIVBalance(ce.EmpId, NULL) AS KeepInViewBalance,
		s.[CanOT],
		s.[IsLocal],
		s.[WorkingDays],
		s.[WorkingHours],
		s.[IsDefaultSchedule],
		ce.[CompanyDate],
		ce.[IsSpecialUser] 'IsTopManager',
		s.[OffDaysbyWeek],
		s.CountryCode,
		s.IsExpatUseHoliday,
		ISNULL(ctry.Nationality, ctry.CountryName) AS CountryName,
		e.MilitaryFromDate,
		e.MilitaryToDate,
		jt.Name AS [JobTitle],
		jl.[Name] AS JobLevel,
		ml.[Name] AS ManagementLevel,
		c.CompanyId,
		c.[Name] AS CompanyName,
		unit.[Name] AS UnitName,
		unit.[Code] AS UnitCode,
		g.GroupId AS [TeamId],
		g.Code AS [TeamCode],
		g.Name AS [TeamName],
		g.Rank,
		dep.DepartmentId,
		dep.Code AS DepartmentCode,
		dep.[Name] AS DepartmentName
	FROM dbo.Employee AS e WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.UserId = e.UserId AND ce.CompanyId = @companyId
	LEFT JOIN dbo.SubCompany sc WITH (NOLOCK) ON ce.SubCompanyId = sc.SubCompanyId
	INNER JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = ce.EmpId
	LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupID = g.GroupID
	INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
	INNER JOIN dbo.[Unit] AS unit WITH (NOLOCK) ON dep.UnitId = unit.UnitId
	LEFT JOIN [dbo].[Country] AS ctry WITH(NOLOCK) ON ctry.CountryCode = s.CountryCode
	LEFT JOIN [dbo].[Lookup] AS l WITH(NOLOCK) ON l.Code = 'JT'
	LEFT JOIN [dbo].[LookupData] AS jt WITH(NOLOCK) ON l.Id = jt.LookupId AND ce.JobTitleId = jt.Id
	LEFT JOIN [dbo].Company c WITH (NOLOCK) ON c.CompanyId = @companyId
	LEFT JOIN dbo.[JobLevel] AS jl WITH (NOLOCK) ON jl.JobLevelId = ce.JobLevelId
	LEFT JOIN ManagementLevel ml WITH (NOLOCK) ON ce.ManagementLevelId = ml.ManagementLevelId
	WHERE (@enable IS NULL OR ce.Enabled = @enable)
		AND (@isDelete IS NULL OR ISNULL(ce.isDeleted, 0) = @isDelete)
		AND (@query IS NULL OR (
			ce.NickName LIKE '%' + @query + '%' 
			OR e.FullName LIKE N'%' + @query + '%' 
			OR ce.Code LIKE '%' + @query + '%'
		))
		AND (@teamIds = '' OR @teamIds IS NULL OR ce.GroupId IN (
			SELECT CAST(value AS INT) FROM STRING_SPLIT(@teamIds, ',')
		))
		AND (@titleId IS NULL OR ce.JobTitleId = @titleId)
		AND (@isLocal IS NULL OR s.IsLocal = @isLocal)
	ORDER BY 
		CASE WHEN @enable = 0 THEN e.ResignedDate END DESC,
		JoinedDate DESC,
		[Code] DESC,
		[NickName]
	OFFSET (@pageNumber - 1) * @pageSize ROWS 
	FETCH NEXT @pageSize ROWS ONLY;

	-- Get employee roles
	SELECT 
		EmployeeId,
		RoleId
	FROM dbo.EmployeeRole AS emRo WITH (NOLOCK);

END