CREATE TABLE SubCompany (
	SubCompanyId INT PRIMARY KEY IDENTITY(1,1),
	CompanyId INT,
	[Name] NVARCHAR(200)
)

ALTER TABLE CompanyEmployee 
ADD SubCompanyId INT

ALTER TABLE [Group] 
ADD IsOutsource BIT NOT NULL DEFAULT 0

SET IDENTITY_INSERT SubCompany ON;

INSERT INTO SubCompany (SubCompanyId, CompanyId, Name)
VALUES
	(1, 9, 'PSP'),
	(2, 9, 'PSB'),
	(3, 9, 'WGI'),
	(4, 3, 'DAR'),
	(5, 23, 'SRM'),
	(6, 23, 'EXT'),
	(7, 22, 'OW')

SET IDENTITY_INSERT SubCompany OFF;

INSERT INTO SystemConfigs
VALUES('IsShowSubCompany', 'true', 9),
('IsShowSubCompany', 'true', 3),
('IsShowSubCompany', 'true', 23),
('IsShowSubCompany', 'true', 22)
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetEmployeeByID] @EmpId INT
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get employee by id
    DB: bodb_HRM

    Revisions:
        03062023@Otis: get field ResignedReason
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @KIVLeaveBalance NUMERIC(18, 2)
		,@AnnualLeaveBalance NUMERIC(18, 2)
		,@Today DATE = GETDATE()

	SELECT @KIVLeaveBalance = dbo.fnc_GetKIVByDayBalance(@EmpID, @Today, NULL)
		,@AnnualLeaveBalance = dbo.fnc_GetAnnualLeaveBalance(@EmpId, @Today, NULL)

	SELECT e.EmpId
		,e.UserId
		,e.Code
		,e.DomainUsername
		,e.FullName
		,e.NickName
		,e.EmployeeCard
		,e.DOB AS DateOfBirth
		,e.Email
		,e.[Enabled]
		,e.Phone
		,e.Gender
		,e.TeamDate
		,e.PromotionDate
		,e.JoinedDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.ResignedReason
		,empsum.CompanyDate
		,empsum.WorkingDays
		,empsum.WorkingHours
		,empsum.MilitaryFromDate
		,empsum.MilitaryToDate
		,empsum.WorkingHoursByWeek
		,e.Skype
		,e.LetsTalk
		,e.Marriage
		,e.LastLogin
		,@AnnualLeaveBalance AS AnnualLeaveBalance
		,@KIVLeaveBalance AS KeepInViewBalance
		,empsum.CountryCode
		,ct.CountryName
		,empsum.CanOT
		,empsum.SpecialOT
		,empsum.IsLocal
		,empsum.IsExpatUseHoliday
		,e.CreatedDate
		,e.CreatedBy
		,e.ModifiedDate
		,e.ModifiedBy
		,e.isDeleted
		,e.PermanentAddress AS [Address]
		,e.CurrentAddress
		,e.IdCardNumber AS CardNo
		,e.PassportNo
		,e.PassportExp
		,e.[Password]
		,e.ChineseName
		,empsum.IsDefaultSchedule
		,empsum.IsTopManager
		,empsum.OffDaysbyWeek
		,empsum.Unit
		,e.PlaceOfbirth
		,e.Ethnic
		,e.[Native]
		,e.Religion
		,e.DateOfIDCard
		,e.PlaceOfIDCard
		,e.HomePhone
		,e.Qualification
		,e.Major
		,e_cs.[BankAccount]
		,e_cs.[TaxCode]
		,e_cs.[SocialInsuranceNo]
		,e_cs.[RegisteredHospital]
		,e_cs.[Contract1]
		,e_cs.[FromDate1]
		,e_cs.[ToDate1]
		,e_cs.[Contract2]
		,e_cs.[FromDate2]
		,e_cs.[ToDate2]
		,e_cs.[Contract3]
		,e_cs.[FromDate3]
		,e_cs.[ToDate3]
		,e_cs.[Contract4]
		,e_cs.[FromDate4]
		,e_cs.[ToDate4]
		,e_cs.[Contract5]
		,e_cs.[FromDate5]
		,e_cs.[ToDate5]
		,e_cs.History
		,e.PasswordReset
		,e.PickupRemark
		,e.JobTitleId
		,e.ExpertGradeId
		,e.JobLevelId
		,lk.[Name] AS JobTitle
		,ce.SubCompanyId
		,e.ManagementLevelId
		,ISNULL(e.GroupId, - 1) AS [TeamId]
		,g.Code
		,g.[Name]
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.EmployeeContract AS e_cs WITH (NOLOCK) ON e_cs.EmpId = e.EmpId
		LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON empsum.CountryCode = ct.CountryCode
		LEFT JOIN dbo.LookupData AS lk WITH (NOLOCK) ON e.JobTitleId = lk.Id
		AND lk.LookupId = 1
	WHERE e.EmpId = @EmpId
END
GO

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
      ,[DomainUsername]
      ,[FullName]
      ,[NickName]
      ,[DOB]
      ,[Email]
      ,[JobTitleId]
      ,[Enabled]
      ,[Phone]
      ,[Gender]
      ,[JoinedDate]
      ,[ConfirmedDate]
      ,[ResignedDate]
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
      ,[Password]
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
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetFullProfileInformation] @query NVARCHAR(256) = NULL
	,@teamIds NVARCHAR(MAX) = ''
	,@enable BIT = NULL
	,@isDelete BIT = NULL
	,@isLocal BIT = NULL
	,@titleId INT = NULL
AS
/*
Created: 20190620@Oliver.Dang
Task: get employee full profile information
DB: HRM
Original:

Revisions:
	- 20200714@Merlin.Le: Get section and department code
	- 20230704@Otis.Vu: Get supervisor and roles info
	- 20250404@Jay.Do: Remove section
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (GroupId INT PRIMARY KEY)

	CREATE TABLE #tmpEmployee (EmpId INT PRIMARY KEY)

	CREATE TABLE #tmpSupervisor (
		EmpId INT
		,ActionType INT
		,OwnerId INT
		,Nickname NVARCHAR(20)
		)

	CREATE NONCLUSTERED INDEX IX_tmpSupervisor ON #tmpSupervisor (
		EmpId
		,ActionType
		,OwnerId
		)

	INSERT INTO #tmpGroup (GroupId)
	SELECT val
	FROM fnc_strSplit(@teamIds, ',')

	INSERT INTO #tmpEmployee (EmpId)
	SELECT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE (
			@isDelete IS NULL
			OR e.isDeleted = @isDelete
			)
		AND (
			@enable IS NULL
			OR e.[Enabled] = @enable
			)
		AND (
			@titleId IS NULL
			OR e.JobTitleId = @titleId
			)
		AND (
			ISNULL(@teamIds, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tmpGroup AS tmpgr WITH (NOLOCK)
				WHERE e.GroupId = tmpgr.GroupId
				)
			)
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			ISNULL(@query, '') = ''
			OR e.NickName LIKE '%' + @query + '%'
			OR e.FullName LIKE '%' + @query + '%'
			)

	SELECT DISTINCT e.EmpId
		,e.Code
		,e.FullName
		,e.NickName
		,e.ChineseName
		,e.DOB
		,e.Gender
		,e.Marriage
		,e.CurrentAddress
		,e.PermanentAddress
		,e.IdCardNumber
		,e.DateOfIDCard
		,e.PlaceOfIDCard
		,e.PlaceOfbirth
		,e.Phone
		,e.HomePhone
		,e.Email
		,e.Qualification
		,e.Major
		,g.[Name] AS TeamName
		,dep.[Name] AS DepartmentName
		,unit.[Name] AS UnitName
		,unit.[Code] AS UnitCode
		,e.EmployeeCard
		,c.[Name] AS CompanyName
		, sc.[Name] AS SubCompanyName
		,es.CompanyDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.ResignedReason
		,e.JoinedDate
		,es.MilitaryFromDate
		,es.MilitaryToDate
		,jt.[Name] AS JobTitle
		,jl.[Name] AS JobLevel
		,e.TeamDate
		,e.Ethnic
		,e.[Native]
		,e.Religion
		,ISNULL(ctry.Nationality, ctry.CountryName) AS Nationality
		,e.PassportNo
		,e.PassportExp
		,e.PickupRemark
		,e.Skype
		,e.LetsTalk
		,es.CanOT
		,es.SpecialOT
		,es.WorkingDays
		,es.WorkingHours
		,es.OffDaysbyWeek
		,es.AnnualLeaveBalance
		,es.KeepInViewBalance
		,es.IsTopManager
		,es.IsLocal
	FROM #tmpEmployee AS tpl WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tpl.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		LEFT JOIN dbo.SubCompany AS sc WITH (NOLOCK) ON sc.SubCompanyId = ce.SubCompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON g.DepartmentId = dep.DepartmentId
		INNER JOIN dbo.Unit AS unit WITH (NOLOCK) ON dep.UnitId = unit.UnitId
		LEFT JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON tpl.EmpId = es.EmpId
		LEFT JOIN dbo.[Lookup] AS l WITH (NOLOCK) ON l.Code = 'JT'
		LEFT JOIN dbo.[LookupData] AS jt WITH (NOLOCK) ON l.Id = jt.LookupId
		AND e.JobTitleId = jt.Id
		LEFT JOIN dbo.[Country] AS ctry WITH (NOLOCK) ON ctry.CountryCode = es.CountryCode
		LEFT JOIN dbo.[JobLevel] AS jl WITH (NOLOCK) ON jl.JobLevelId = e.JobLevelId
		AND jl.IsDeleted = 0
	ORDER BY e.EmpId

	INSERT INTO #tmpSupervisor(
		EmpId
		,ActionType
		,OwnerId
		,Nickname
		)
	SELECT DISTINCT su.EmpId
		,su.ActionType
		,su.OwnerId
		,empsu.Nickname
	FROM dbo.[EmployeeSupervisor] AS su WITH (NOLOCK)
		INNER JOIN #tmpEmployee AS emp WITH (NOLOCK) ON su.EmpId = emp.EmpId
		INNER JOIN dbo.Employee AS empsu WITH (NOLOCK) ON su.OwnerId = empsu.EmpId
	WHERE empsu.[Enabled] = 1
		AND empsu.isDeleted = 0
		AND su.ActionType IN (2, 3, 4, 5, 8)
		AND su.IsDeleted = 0
	ORDER BY su.EmpId

	SELECT tbl.EmpId
		,tbl.ActionType
		,tbl.OwnerId
		,tbl.Nickname
	FROM #tmpEmployee AS tpl WITH (NOLOCK)
		INNER JOIN #tmpSupervisor AS tbl WITH (NOLOCK) ON tpl.EmpId = tbl.EmpId

	SELECT emprole.EmployeeId
		,emprole.RoleId
	FROM #tmpEmployee AS tpl WITH (NOLOCK)
		INNER JOIN dbo.EmployeeRole AS emprole WITH (NOLOCK) ON emprole.EmployeeId = tpl.EmpId

	DROP TABLE #tmpGroup

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpSupervisor
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Information_update] @EmpId INT
	,@Code VARCHAR(20)
	,@DomainUsername VARCHAR(50) = ''
	,@FullName NVARCHAR(50) = ''
	,@Nickname NVARCHAR(20) = ''
	,@DOB DATE = NULL
	,@Email VARCHAR(50) = NULL
	,@JobTitleId INT = NULL
	,@JobLevelId INT = NULL
    ,@ManagementLevelId SMALLINT = NULL
	,@Enabled BIT
	,@Phone VARCHAR(50) = NULL
	,@Gender TINYINT = NULL
	,@TeamId INT
	,@Roles VARCHAR(20)
	,@JoinedDate DATE = NULL
	,@ConfirmedDate DATE = NULL
	,@ResignedDate DATE = NULL
	,@ResignedReason NVARCHAR(200) = NULL
	,@Skype VARCHAR(100) = NULL
	,@LetsTalk VARCHAR(100) = NULL
	,@Marriage TINYINT = 1
	,@ModifiedBy INT
	,@PermanentAddress NVARCHAR(250) = ''
	,@CurrentAddress NVARCHAR(250) = ''
	,@IdCardNumber VARCHAR(20) = ''
	,@PassportNo VARCHAR(35) = ''
	,@PassportExp DATE = NULL
	,@ChineseName NVARCHAR(200) = NULL
	,@CanOT BIT
	,@SpecialOT DECIMAL(3, 1) = NULL
	,@IsLocal BIT
	,@WorkingDays INT
	,@WorkingHours INT
	,@WorkingHoursByWeek TINYINT = NULL
	,@CompanyDate DATE = NULL
	,@CountryCode VARCHAR(5) = NULL
	,@IsTopManager BIT = 0
	,@OffDaysbyWeek SMALLINT = 0
	,@IsExpatUseHoliday BIT = 0
	,@PlaceOfbirth NVARCHAR(250) = ''
	,@Ethnic NVARCHAR(250) = ''
	,@Native NVARCHAR(250) = ''
	,@Religion NVARCHAR(250) = ''
	,@DateOfIDCard DATE = NULL
	,@PlaceOfIDCard NVARCHAR(250) = ''
	,@HomePhone NVARCHAR(250) = ''
	,@Qualification NVARCHAR(300) = ''
	,@Major NVARCHAR(300) = ''
	,@EmployeeCard VARCHAR(10) = ''
	,@PickupRemark NVARCHAR(200) = NULL
	,@PromotionDate DATE = NULL
	,@TeamDate DATE = NULL
	,@MilitaryFromDate DATE = NULL
	,@MilitaryToDate DATE = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
	,@SubCompanyId INT = NULL
AS
/*
Created: TOM
Task: UPDATE an employee Information 
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @EmpId_exist INT
		,@Nickname_exist NVARCHAR(20)
		,@FullName_exist NVARCHAR(50)
		,@Code_exist NVARCHAR(50)
		,@Roles_old VARCHAR(100)
		,@Enabled_old BIT
		,@IsDeleted_old BIT
		,@IsDefaultSchedule_old BIT
		,@AnnualLeaveBalance_old NUMERIC(18, 1) = 0
		,@KeepInViewBalance_old NUMERIC(18, 1) = 0
		,@xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

	SELECT TOP 1 @EmpId_exist = e.EmpId
		,@FullName_exist = e.FullName
	FROM dbo.Employee e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee c WITH(NOLOCK) ON c.EmpId = e.EmpId
	WHERE e.EmpId <> @EmpId
		AND Code = @code
		AND c.CompanyId = @CompanyId


	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Code ' + @Code + ' has been assigned to ' + @FullName_exist

		RETURN
	END

	SELECT TOP 1 @EmpId_exist = e.EmpId
		,@Nickname_exist = Nickname
		,@FullName_exist = FullName
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee c WITH(NOLOCK) ON c.EmpId = e.EmpId
	WHERE e.EmpId <> @EmpId
		AND Nickname = @nickname
		AND c.CompanyId = @CompanyId
		AND (
			isDeleted = 0
			OR [Enabled] = 1
			)

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Nickname  ' + @Nickname_exist + '  has been assigned to ' + @FullName_exist

		RETURN
	END

	SELECT @Enabled_old = [Enabled]
		,@IsDeleted_old = isDeleted
	FROM dbo.Employee WITH (NOLOCK)
	WHERE EmpId = @EmpId
	
	SELECT @IsDefaultSchedule_old = IsDefaultSchedule
		,@AnnualLeaveBalance_old = AnnualLeaveBalance
		,@KeepInViewBalance_old = KeepInViewBalance
	FROM dbo.EmployeeSummary WITH (NOLOCK)
	WHERE EmpId = @EmpId

	SELECT @Roles_old = COALESCE(@Roles_old + ',', '') + CONVERT(NVARCHAR(2), RoleId)
	FROM dbo.EmployeeRole WITH (NOLOCK)
	WHERE EmployeeId = @EmpId
	Order by RoleID 

	SET @xml = (
			SELECT Code AS '@Code'
				,DomainUsername AS '@DomainUsername'
				,FullName AS '@FullName'
				,Nickname AS '@Nickname'
				,DOB AS '@DOB'
				,Email AS '@Email'
				,JobTitleId AS '@JobTitleId'
				,JobLevelId AS '@JobLevelId'
				,ManagementLevelId AS'@ManagementLevelId'
				,[Enabled] AS '@Enabled'
				,emp.isDeleted AS '@IsDeleted'
				,Phone AS '@Phone'
				,Gender AS '@Gender'
				,GroupId AS '@TeamId'
				,JoinedDate AS '@JoinedDate'
				,ConfirmedDate AS '@ConfirmedDate'
				,ResignedDate AS '@ResignedDate'
				,ResignedReason AS '@ResignedReason'
				,Skype AS '@Skype'
				,LetsTalk AS '@LetsTalk'
				,Marriage AS '@Marriage'
				,PermanentAddress AS '@PermanentAddress'
				,CurrentAddress AS '@CurrentAddress'
				,IdCardNumber AS '@IdCardNumber'
				,PassportNo AS '@PassportNo'
				,PassportExp AS '@PassportExp'
				,ChineseName AS '@ChineseName'
				,PlaceOfbirth AS '@PlaceOfbirth'
				,Ethnic AS '@Ethnic'
				,[Native] AS '@Native'
				,Religion AS '@Religion'
				,DateOfIDCard AS '@DateOfIDCard'
				,PlaceOfIDCard AS '@PlaceOfIDCard'
				,HomePhone AS '@HomePhone'
				,Qualification AS '@Qualification'
				,Major AS '@Major'
				,EmployeeCard AS '@EmployeeCard'
				,PickupRemark AS '@PickupRemark'
				,PromotionDate AS '@PromotionDate'
				,TeamDate AS '@TeamDate'
				,@Roles_old AS '@RoleIds'
				,CanOT AS '@CanOT'
				,SpecialOT AS '@SpecialOT'
				,IsLocal AS '@IsLocal'
				,WorkingDays AS '@WorkingDays'
				,WorkingHours AS '@WorkingHours'
				,WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,IsTopManager AS '@IsTopManager'
				,CompanyDate AS '@CompanyDate'
				,CountryCode AS '@CountryCode'
				,IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,OffDaysbyWeek AS '@OffDaysbyWeek'
				,MilitaryFromDate AS '@MilitaryFromDate'
				,MilitaryToDate AS '@MilitaryToDate'
				,SubCompanyId AS '@SubCompanyId'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
			WHERE emp.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	IF @Enabled_old = 0 AND @Enabled = 1 AND @IsDeleted_old = 1
	BEGIN
		UPDATE dbo.Employee WITH (ROWLOCK, UPDLOCK)
		SET isDeleted = 0
		WHERE EmpId = @EmpId
	END

	UPDATE dbo.Employee WITH (ROWLOCK, UPDLOCK)
	SET Code = @Code
		,DomainUsername = @DomainUsername
		,FullName = @FullName
		,Nickname = @Nickname
		,DOB = @DOB
		,Email = REPLACE(@Email, ' ', '')
		,JobTitleId = @JobTitleId
		,JobLevelId = @JobLevelId
		,ManagementLevelId = @ManagementLevelId
		,[Enabled] = @Enabled
		,Phone = @Phone
		,Gender = @Gender
		,GroupId = @TeamId
		,JoinedDate = @JoinedDate
		,ConfirmedDate = @ConfirmedDate
		,ResignedDate = @ResignedDate
		,ResignedReason = @ResignedReason
		,Skype = @Skype
		,LetsTalk = @LetsTalk
		,Marriage = @Marriage
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
		,PermanentAddress = @PermanentAddress
		,CurrentAddress = @CurrentAddress
		,IdCardNumber = @IdCardNumber
		,PassportNo = @PassportNo
		,PassportExp = @PassportExp
		,ChineseName = @ChineseName
		,PlaceOfbirth = @PlaceOfbirth
		,Ethnic = @Ethnic
		,[Native] = @Native
		,Religion = @Religion
		,DateOfIDCard = @DateOfIDCard
		,PlaceOfIDCard = @PlaceOfIDCard
		,HomePhone = @HomePhone
		,Qualification = @Qualification
		,Major = @Major
		,EmployeeCard = @EmployeeCard
		,PickupRemark = @PickupRemark
		,PromotionDate = @PromotionDate
		,TeamDate = @TeamDate
	WHERE EmpId = @EmpId

	UPDATE CompanyEmployee  WITH (ROWLOCK, UPDLOCK)
	SET SubCompanyId = @SubCompanyId
	WHERE EmpId = @EmpId

	EXEC dbo.EmployeeRole_Update @EmployeeId = @EmpId
		,@RoleIds = @Roles
		,@ModifiedBy = @ModifiedBy

	EXEC dbo.Employee_Summary_Update @EmpId = @EmpId
		,@AnnualLeaveBalance = @AnnualLeaveBalance_old
		,@KeepInViewBalance = @KeepInViewBalance_old
		,@CanOT = @CanOT
		,@SpecialOT = @SpecialOT
		,@IsLocal = @IsLocal
		,@WorkingDays = @WorkingDays
		,@WorkingHours = @WorkingHours
		,@WorkingHoursByWeek = @WorkingHoursByWeek
		,@CompanyDate = @CompanyDate
		,@CountryCode = @CountryCode
		,@IsDefaultSchedule = @IsDefaultSchedule_old
		,@IsTopManager = @IsTopManager
		,@OffDaysbyWeek = @OffDaysbyWeek
		,@IsExpatUseHoliday = @IsExpatUseHoliday
		,@MilitaryFromDate = @MilitaryFromDate
		,@MilitaryToDate = @MilitaryToDate
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	SET @xml = (
			SELECT Code AS '@Code'
				,DomainUsername AS '@DomainUsername'
				,FullName AS '@FullName'
				,Nickname AS '@Nickname'
				,DOB AS '@DOB'
				,Email AS '@Email'
				,JobTitleId AS '@JobTitleId'
				,JobLevelId AS '@JobLevelId'
				,ManagementLevelId AS '@ManagementLevelId'
				,[Enabled] AS '@Enabled'
				,emp.isDeleted AS '@IsDeleted'
				,Phone AS '@Phone'
				,Gender AS '@Gender'
				,GroupId AS '@TeamId'
				,JoinedDate AS '@JoinedDate'
				,ConfirmedDate AS '@ConfirmedDate'
				,ResignedDate AS '@ResignedDate'
				,ResignedReason AS '@ResignedReason'
				,Skype AS '@Skype'
				,LetsTalk AS '@LetsTalk'
				,Marriage AS '@Marriage'
				,PermanentAddress AS '@PermanentAddress'
				,CurrentAddress AS '@CurrentAddress'
				,IdCardNumber AS '@IdCardNumber'
				,PassportNo AS '@PassportNo'
				,PassportExp AS '@PassportExp'
				,ChineseName AS '@ChineseName'
				,PlaceOfbirth AS '@PlaceOfbirth'
				,Ethnic AS '@Ethnic'
				,[Native] AS '@Native'
				,Religion AS '@Religion'
				,DateOfIDCard AS '@DateOfIDCard'
				,PlaceOfIDCard AS '@PlaceOfIDCard'
				,HomePhone AS '@HomePhone'
				,Qualification AS '@Qualification'
				,Major AS '@Major'
				,EmployeeCard AS '@EmployeeCard'
				,PickupRemark AS '@PickupRemark'
				,PromotionDate AS '@PromotionDate'
				,TeamDate AS '@TeamDate'
				,@Roles AS '@RoleIds'
				,CanOT AS '@CanOT'
				,SpecialOT AS '@SpecialOT'
				,IsLocal AS '@IsLocal'
				,WorkingDays AS '@WorkingDays'
				,WorkingHours AS '@WorkingHours'
				,WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,IsTopManager AS '@IsTopManager'
				,CompanyDate AS '@CompanyDate'
				,CountryCode AS '@CountryCode'
				,IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,OffDaysbyWeek AS '@OffDaysbyWeek'
				,MilitaryFromDate AS '@MilitaryFromDate'
				,MilitaryToDate AS '@MilitaryToDate'
				,SubCompanyId AS '@SubCompanyId'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
			WHERE emp.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 1
		,@ObjectId = @EmpId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Get]
(
    @CompanyId INT
    ,@TeamId INT = NULL
	,@keyWord varchar(20) = null
	,@isDeleted BIT = NULL
)
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get group
    DB: bodb_HRM

    Revisions:
        20250310@Mira: filter by CompanyId [Redmine: #217976]
        20250403@Tim: remove section [Redmine: #222886]
        20250515@Jay: add years of service for extra leave [Redmine: #227166]
        20250530@Jay: show company name for employees from different company [Redmine: #225528]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (
		GroupId INT PRIMARY KEY
		,NoOfMembers INT
		,TotalLocal INT
		,TotalExpat INT
		)

	INSERT INTO #tmpGroup (
		GroupId
		,NoOfMembers
		,TotalLocal
		,TotalExpat
		)
	SELECT g.GroupId
		,SUM(CASE 
				WHEN esum.IsLocal IS NOT NULL THEN 1
				ELSE 0
				END) AS NoOfMembers
		,SUM(CASE 
				WHEN esum.IsLocal = 1 THEN 1
				ELSE 0
				END) TotalLocal
		,SUM(CASE 
				WHEN esum.IsLocal = 0 THEN 1
				ELSE 0
				END) TotalExpat
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.GroupId = g.GroupId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) on c.EmpId = emp.EmpId AND c.CompanyId = @CompanyId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		AND g.CompanyId = @CompanyId
	GROUP BY g.GroupId

	SELECT g.groupId AS TeamId
		,g.[Name]
		,g.Code
		,g.[Rank]
		,g.MailGroup
		,g.IsOutsource
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave
		,tbl.NoOfMembers
		,tbl.TotalLocal
		,tbl.TotalExpat
		,g.PICEmpId
		,cpic.[Name] AS PICCompanyName
		,cpic.[CompanyId] AS PICCompanyId
		,ld.NickName as PICNickName
		,dept.DepartmentId
        ,dept.Code
        ,dept.[Name]
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.Employee AS ld WITH (NOLOCK) ON ld.EmpId = g.PICEmpId
		LEFT JOIN dbo.CompanyEmployee cepic WITH (NOLOCK) ON cepic.EmpId = g.PICEmpId
		LEFT JOIN dbo.Company cpic WITH (NOLOCK) ON cpic.CompanyId = cepic.CompanyId
		LEFT JOIN #tmpGroup AS tbl ON g.GroupId = tbl.GroupId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		AND (
			 @keyWord IS NULL
			 OR LOWER(g.[Name]) like LOWER('%' + @keyWord + '%') 
			 OR LOWER(g.Code) like LOWER('%' + @keyWord + '%') 
			)
		AND g.CompanyId = @CompanyId
	ORDER BY g.[Code]

	SELECT mng.GroupId AS TeamId
		,mng.RoleId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
	FROM dbo.GroupManager AS mng WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON mng.GroupId = g.GroupId
		AND (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON mng.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) on c.EmpId = emp.EmpId
    WHERE g.CompanyId = @CompanyId
        AND c.CompanyId = @CompanyId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1

    DROP TABLE #tmpGroup
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Insert]
(
    @Code VARCHAR(20)
    ,@Name VARCHAR(150)
    ,@CreatedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg VARCHAR(200) = '' OUTPUT
    ,@CompanyId SMALLINT
    ,@GroupTeamId INT
    ,@PICEmpId INT = NULL
    ,@DepartmentId INT
    ,@AccountableArea VARCHAR(200) = NULL
	,@IsOutsource BIT = 0
)
AS
/*
    Created: 20190515@Oliver.Dang
    Task: insert group 
    DB: bodb_HRM

    Revisions:
        - 20250422@Jay: Apply create group team logic [Redmine: #221567]
        - 20250526@Jay: Allow having the same code [Redmine: #228323]
        - 20250530@Jay: allow PICEmpId be null [Redmine: #225528]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupTeamId = @GroupTeamId
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Team Id "' + CAST(@GroupTeamId AS NVARCHAR) + '" exists.'

		RETURN
	END

	INSERT INTO dbo.[Group] (
		Code
		,[Name]
		,CreatedDate
		,CreatedBy
		,CompanyId
		,GroupTeamId
		,PICEmpId
		,DepartmentId
		,AccountableArea
		,IsOutsource
		)
	VALUES (
		@Code
		,@Name
		,GETDATE()
		,@CreatedBy
		,@CompanyId
		,@GroupTeamId
		,@PICEmpId
		,@DepartmentId
		,@AccountableArea
		,@IsOutsource
		)

	DECLARE @id INT = cast(SCOPE_IDENTITY() AS INT)

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,CompanyId as '@CompanyId'
				,GroupTeamId as '@GroupTeamId'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
				,IsOutsource as '@IsOutsource'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @id
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 2
		,@ObjectId = @id
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[Group_UnitScope_Get]
	@keyWord varchar(20) = null,
	@TeamId INT = NULL
AS
/*
Created: Tom.Vo@2013-10-21
Task: get group
DB: HRM

Revisions:
	20250310@Mira: filter by CompanyId [Redmine: #217976]
    20250403@Tim: remove section [Redmine: #222886]
	20250515@Jay: add years of service for extra leave [Redmine: #227166]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (
		GroupId INT PRIMARY KEY
		,NoOfMembers INT
		)

	INSERT INTO #tmpGroup (
		GroupId
		,NoOfMembers
		)
	SELECT g.GroupId
		,SUM(CASE 
				WHEN esum.IsLocal IS NOT NULL THEN 1
				ELSE 0
				END) AS NoOfMembers
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.GroupId = g.GroupId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND g.isDeleted != 1
	GROUP BY g.GroupId

	SELECT g.GroupId AS Id
		,GroupTeamId AS GroupTeamId
		,g.[Name] AS TeamName
		,g.Code AS TeamCode
		,g.[Rank]
		,tbl.NoOfMembers
		,g.PICEmpId
		,e.NickName as TeamPIC
		,cpic.[CompanyId] AS TeamPICCompanyId
		,cpic.[Name] AS TeamPICCompany
		,d.DepartmentId
        ,d.Code AS DepartmentCode
        ,d.[Name] AS DepartmentName
		,d.PICEmpId AS DepartmentPICId
		,ed.NickName AS DepartmentPIC
		,u.Code AS UnitCode
		,g.AccountableArea
		,g.CompanyId
		,c.[Name] AS CompanyName
		,g.MailGroup
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave
		,g.IsOutsource
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS d WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = g.PICEmpId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = d.UnitId
		LEFT JOIN dbo.Employee AS ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN dbo.CompanyEmployee AS cepic WITH (NOLOCK) ON cepic.EmpId = g.PICEmpId
		LEFT JOIN dbo.Company AS cpic WITH (NOLOCK) ON cepic.CompanyId = cpic.CompanyId
		LEFT JOIN #tmpGroup AS tbl ON g.GroupId = tbl.GroupId
		LEFT JOIN dbo.Company AS c ON g.CompanyId = c.CompanyId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND g.isDeleted != 1
		AND (
			 @keyWord IS NULL
			 OR LOWER(g.[Name]) like LOWER('%' + @keyWord + '%') 
			 OR LOWER(g.Code) like LOWER('%' + @keyWord + '%') 
			)
	ORDER BY d.Code

    DROP TABLE #tmpGroup
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Update]
(
    @TeamId INT
    ,@Code VARCHAR(20)
    ,@Name NVARCHAR(150)
    ,@ModifiedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
    ,@PICEmpId INT = NULL
    ,@DepartmentId INT
    ,@AccountableArea VARCHAR(200) = NULL
    ,@GroupTeamId INT
    ,@MailGroup VARCHAR(50) = ''
    ,@LocalBasicAnnualLeaveBalance TINYINT = NULL
    ,@LocalWorkingDays TINYINT = NULL
    ,@LocalWorkingHours TINYINT = NULL
    ,@LocalOffDaysbyWeek TINYINT = NULL
    ,@LocalWorkingHoursByWeek TINYINT = NULL
    ,@LocalYearsOfServiceForExtraLeave INT = NULL
    ,@ExpatBasicAnnualLeaveBalance TINYINT = NULL
    ,@ExpatWorkingDays TINYINT = NULL
    ,@ExpatWorkingHours TINYINT = NULL
    ,@ExpatOffDaysbyWeek TINYINT = NULL
    ,@ExpatWorkingHoursByWeek TINYINT = NULL
    ,@ExpatYearsOfServiceForExtraLeave INT = NULL
	,@IsOutsource BIT = 0
)
AS
/*
    Created: Tom.Vo@2013-10-23
    Task: Update group 
    DB: bodb_HRM

    Revisions:
	    - 20250515@Jay: add years of service for extra leave [Redmine: #227166]
	    - 20250526@Jay: Allow having the same code [Redmine: #228323]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId <> @TeamId 
				AND GroupTeamId = @GroupTeamId
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Team Id "' + CAST(@GroupTeamId AS NVARCHAR) + '" have been used by other group.'

		RETURN
	END

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId AS '@PICEmpId'
				,DepartmentId AS '@DepartmentId'
				,AccountableArea AS '@AccountTableArea'
				,GroupTeamId AS '@GroupTeamId'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,LocalYearsOfServiceForExtraLeave AS '@LocalYearsOfServiceForExtraLeave'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,ExpatYearsOfServiceForExtraLeave AS '@ExpatYearsOfServiceForExtraLeave'
				,IsOutsource AS '@IsOutsource'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	UPDATE dbo.[Group] WITH (ROWLOCK, UPDLOCK)
	SET Code = @Code
		,[Name] = @Name
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
		,PICEmpId = @PICEmpId
		,DepartmentId = @DepartmentId
		,AccountableArea = @AccountableArea
		,GroupTeamId = @GroupTeamId
		,LocalBasicAnnualLeaveBalance = @LocalBasicAnnualLeaveBalance
		,LocalWorkingDays = @LocalWorkingDays
		,LocalWorkingHours = @LocalWorkingHours
		,LocalOffDaysbyWeek = @LocalOffDaysbyWeek
		,LocalWorkingHoursByWeek = @LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave = @LocalYearsOfServiceForExtraLeave
		,ExpatBasicAnnualLeaveBalance = @ExpatBasicAnnualLeaveBalance
		,ExpatWorkingDays = @ExpatWorkingDays
		,ExpatWorkingHours = @ExpatWorkingHours
		,ExpatOffDaysbyWeek = @ExpatOffDaysbyWeek
		,ExpatWorkingHoursByWeek = @ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave = @ExpatYearsOfServiceForExtraLeave
		,[MailGroup] = @MailGroup
		,IsOutsource = @IsOutsource
	WHERE GroupId = @TeamId

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
				,GroupTeamId as '@GroupTeamId'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,LocalYearsOfServiceForExtraLeave AS '@LocalYearsOfServiceForExtraLeave'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,ExpatYearsOfServiceForExtraLeave AS '@ExpatYearsOfServiceForExtraLeave'
				,IsOutsource AS '@IsOutsource'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 2
		,@ObjectId = @TeamId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE SubCompanies_ByCompanyId_Get
	@CompanyId INT
AS
/*
Created: 20250616@Jay
Task: Get all subcompanies by company id
DB: HRM
Original:

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT SubCompanyId,
		CompanyId,
		[Name]
	FROM SubCompany
	WHERE CompanyId = @CompanyId
END
GO
