USE [bodb_HRM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[FnB_Unit_GetByLastModifiedDate]
(
	@CompanyId SMALLINT,
    @LastModifiedDate DATETIME
)
AS
/*
    Created: 20230220@Quinn.Vo
    Task: Get last modified date
    DB: bodb_HRM

    Revisions:  
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(YYYY, -10, GETDATE())
	END

	SELECT DISTINCT u.UnitId
		,u.Code
		,ISNULL(u.[Name], u.Code) AS [Name]
		,u.IsActive
		,u.ModifiedDate
		,u.IsDeleted
	FROM dbo.Unit AS u WITH (NOLOCK) 
	    INNER JOIN dbo.Department AS d WITH (NOLOCK) ON d.UnitId = u.UnitId
	    INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
		AND g.CompanyId = @CompanyId
	WHERE u.ModifiedDate > @LastModifiedDate
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[FnB_Shift_GetAll]
(
	@CompanyId SMALLINT
)
AS
/*
    Created: 20230220@Quinn.Vo
    Task: Get last modified date
    DB: bodb_HRM

    Revisions:  
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT Code
	    ,[Name]
	    ,BeginCheckInTime
	    ,EndCheckInTime
	    ,BeginCheckOutTime
	    ,EndCheckOutTime
	    ,IsInAfterDay
	    ,IsOutAfterDay
	    ,IsDisabled
		,CASE 
			WHEN OldShiftId IS NULL THEN ShiftId
			ELSE OldShiftId
		END AS ShiftId
	FROM dbo.[Shift] WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[FnB_Section_GetByLastModifiedDate]
(
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
)
AS
/*
    Created: 20230220@Quinn.Vo
    Task: Get section by last modified date.
    DB: bosb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(YYYY, -10, GETDATE())
	END
	
	SELECT DISTINCT d.[DepartmentId]  AS [SectionId]
        ,d.[Code]
		,d.[Name]
		,d.[IsActive]
		,d.[ModifiedDate]
		,d.[IsDeleted]
		,d.[DepartmentId]
	FROM dbo.Department AS d WITH (NOLOCK)
		INNER JOIN [Group] AS g WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
	WHERE CompanyId = @CompanyId
		AND d.ModifiedDate > @LastModifiedDate
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[FnB_EmployeeGroup_GetByLastModifiedDate]
(
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
)
AS
/*
    Created: 20140320@Quinn.Vo
    Task: Get all groups from change date
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NOT NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(HH, - 1, @LastModifiedDate)
	END

	SELECT DISTINCT d.DepartmentId AS SectionId
		,g.Code
		,g.[Name]
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
		,g.GroupId AS TeamId
	FROM dbo.[Group] AS g WITH (NOLOCK)
	    LEFT JOIN dbo.Department AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
	WHERE g.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR ISNULL(g.ModifiedDate, g.CreatedDate) > @LastModifiedDate)
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[FnB_EmployeeCalendar_GetByLastModifiedDate]
(
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
)
AS
/*
Created: 20141002@Quinn.Vo
Task: Get employee calendar from change date
DB: bodb_HRM

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpEmployeeCalendarChange (EmpId INT, WorkDate DATE)

	INSERT INTO #tmpEmployeeCalendarChange(EmpId, WorkDate)
	SELECT e.EmpId
	   ,CAST([WorkDate] AS DATE)
	FROM dbo.EmployeeCalendar AS e WITH (NOLOCK)
		INNER JOIN CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR ModifiedDate > @LastModifiedDate)
	UNION 
	SELECT ca.[EmpId]
	   ,[WorkDate]
	FROM dbo.tmpEmployeeCalendar AS ca WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ca.EmpId = e.EmpId AND e.Enabled =1
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ca.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR ca.ModifiedDate > @LastModifiedDate)
	UNION
	SELECT ea.EmpId, CAST(AttendanceDate AS DATE)
	FROM dbo.EmployeeAttendance AS ea
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ea.EmpId
	WHERE ce.CompanyId = @CompanyId 
		AND (@LastModifiedDate IS NULL OR InsertDate > @LastModifiedDate)
	UNION 
	SELECT wfh.EmpId, [WorkDate]
	FROM dbo.tmpEmployeeCalendar AS tmp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeWorkFromHome AS wfh WITH (NOLOCK) ON tmp.WorkDate BETWEEN wfh.FromDate AND wfh.ToDate
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = tmp.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR wfh.ModifiedDate > @LastModifiedDate)

	SELECT a.UserId,
	    a.WorkDate,
	    a.[ShiftId],
	    a.[IsHoliday],
	    a.IsOffDay,
	    a.IsLeaveDay,
	    a.LeaveTypeId,
	    a.LeaveDay,
	    CASE WHEN a.ModifiedDate IS NULL THEN '2023-01-01' ELSE a.ModifiedDate END AS ModifiedDate,
	    HasCheckIn
	FROM 
	(
	    SELECT tcl.[WorkDate]
          , CASE WHEN e.OldEmpId IS NOT NULL THEN e.OldEmpId ELSE e.EmpId END AS UserId
          ,CASE WHEN s.OldShiftId IS NOT NULL THEN s.OldShiftId ELSE s.ShiftID END AS ShiftID
          ,tcl.[IsHoliday]
          ,CAST(CASE WHEN (tcl.[IsOffDay] = 1 OR wfh.EmployeeWorkFromHomeId IS NOT NULL) THEN 1 ELSE 0 END AS BIT) AS IsOffDay
	       ,CASE WHEN tcl.EmpId IS NULL THEN cl.IsLeaveDay ELSE tcl.[IsLeaveDay] END AS IsLeaveDay
          ,CASE WHEN tcl.EmpId IS NULL THEN cl.[LeaveTypeId] ELSE tcl.[LeaveTypeId] END AS LeaveTypeId
          ,CASE WHEN tcl.EmpId IS NULL THEN cl.[LeaveDay] ELSE tcl.[LeaveDay] END AS LeaveDay
	      ,CASE WHEN cl.ModifiedDate > ISNULL(tcl.ModifiedDate, '2010-01-01') AND cl.ModifiedDate > ISNULL(att.InsertDate, '2010-01-01') THEN cl.ModifiedDate
		    WHEN  ISNULL(tcl.ModifiedDate, '2010-01-01') > cl.ModifiedDate AND ISNULL(tcl.ModifiedDate, '2010-01-01')  > ISNULL(att.InsertDate, '2010-01-01') THEN tcl.ModifiedDate
		    ELSE att.InsertDate END AS ModifiedDate
	      ,CAST(CASE WHEN att.InFixed IS NULL THEN 0 ELSE 1 END AS BIT) AS HasCheckIn
	    FROM #tmpEmployeeCalendarChange AS tmp WITH (NOLOCK)
		    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.EmpId
		    INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON tmp.EmpId = cl.EmpId AND tmp.WorkDate = cl.WorkDate
		    INNER JOIN dbo.tmpEmployeeCalendar as tcl  ON tcl.EmpId = tmp.EmpId AND tcl.WorkDate = tmp.WorkDate
		    LEFT JOIN dbo.EmployeeAttendance AS att ON tmp.EmpId = att.EmpId AND tmp.WorkDate = att.AttendanceDate
		    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = tmp.EmpId
		    LEFT JOIN dbo.EmployeeWorkFromHome AS wfh ON tmp.EmpId = wfh.EmpId AND tmp.WorkDate BETWEEN wfh.FromDate AND wfh.ToDate
		    LEFT JOIN dbo.Shift AS s ON tcl.ShiftId = s.ShiftID AND s.CompanyId = @CompanyId
	    WHERE ce.CompanyId = @CompanyId
	) AS a
	WHERE a.WorkDate > DATEADD(dd, -30, GETDATE())

	DROP TABLE #tmpEmployeeCalendarChange
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[FnB_Employee_GetByLastModifiedDate]
(
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
)
AS
/*
    Created: 20140320@Quinn.Vo
    Task: Get all employee from change date
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT e.UserId
		,e.[Password]
		,e.Code
		,e.NickName
		,e.FullName
		,e.EmployeeCard
		,e.DomainUsername AS DomainName
		,e.Phone
		,e.Email
		,e.JobTitleId
		,e.[Enabled]
		,ISNULL(e.isDeleted, 0) AS IsDeleted
		,e.JoinedDate
		,e.ConfirmedDate
		,es.IsLocal
		,g.GroupId AS TeamId
		,CASE 
			WHEN e.ModifiedDate IS NULL THEN e.CreatedDate
			ELSE e.ModifiedDate
			END AS ModifiedDate
		,es.Unit AS CostCenter
		,e.JobLevelId
		,CASE 
			WHEN OldEmpId IS NULL THEN e.EmpId
			ELSE OldEmpId
		END AS EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		LEFT JOIN dbo.LookupData AS ld WITH (NOLOCK) ON ld.Id = e.JobTitleId AND ld.CompanyId = @CompanyId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId AND g.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId AND
		(@LastModifiedDate IS NULL
		OR e.ModifiedDate > @LastModifiedDate
		OR e.CreatedDate > @LastModifiedDate)
	ORDER BY e.ModifiedDate
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[FnB_Department_GetByLastModifiedDate]
(
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
)
AS
/*
    Created: 20230220@Quinn.Vo
    Task: Get last modified date
    DB: bodb_HRM

    Revisions:  
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(YYYY, -10, GETDATE())
	END

	SELECT DISTINCT d.[DepartmentId]
		,d.[Code]
		,d.[Name]
		,d.[UnitId]
		,d.[IsActive]
		,d.[ModifiedDate]
		,d.[IsDeleted]
	FROM dbo.Department AS d WITH (NOLOCK)
		INNER JOIN [Group] AS g WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
	WHERE g.CompanyId = @CompanyId
		AND d.ModifiedDate > @LastModifiedDate
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SyncEPA_Department]
(
	@CompanyId INT,
    @FromDate DATETIME = NULL
)
AS
/*
    Created: 20171108@Tim.Trinh
    Task: Get all departments from change date
    DB: bodb_HRM

    Revisions:
        20250409@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DepartmentIndex INT = 1000000
		,@UnitIndex INT = 2000000

	CREATE TABLE #tblDepartment (
		DepartmentId INT
		,Code VARCHAR(50)
		,[Name] NVARCHAR(200)
		,ParentId INT NULL
		,IsDeleted BIT
		,ModifiedDate DATETIME
		)

	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,ParentId
		,IsDeleted
		,ModifiedDate
		)
	SELECT distinct d.DepartmentId AS SectionId
		,d.Code
		,d.[Name]
		,@DepartmentIndex + d.DepartmentId
		,CASE 
			WHEN d.IsActive = 0
				OR d.IsDeleted = 1 THEN 1
			ELSE 0
			END
		,d.ModifiedDate
	FROM dbo.Department AS d WITH (NOLOCK)
        INNER JOIN dbo.[Group] AS t WITH (NOLOCK) ON d.DepartmentId = t.DepartmentId
    WHERE t.CompanyId = @CompanyId

	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,ParentId
		,IsDeleted
		,ModifiedDate
		)
	SELECT distinct @DepartmentIndex + d.DepartmentId
		,d.Code
		,d.[Name]
		,@UnitIndex + u.UnitId
		,CASE 
			WHEN d.IsActive = 0
				OR d.IsDeleted = 1 THEN 1
			ELSE 0
			END
		,d.ModifiedDate
	FROM dbo.Department d WITH (NOLOCK)
        INNER JOIN dbo.[Group] AS t WITH (NOLOCK) ON d.DepartmentId = t.DepartmentId
	    INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = d.UnitId
    WHERE t.CompanyId = @CompanyId

	INSERT INTO #tblDepartment (
		DepartmentId
		,Code
		,[Name]
		,IsDeleted
		,ModifiedDate
		)
	SELECT distinct @UnitIndex + u.UnitId
		,u.Code
		,ISNULL(u.[Name], u.Code)
		,CASE 
			WHEN u.IsActive = 0
				OR u.IsDeleted = 1 THEN 1
			ELSE 0
			END
		,u.ModifiedDate
	FROM dbo.Unit AS u WITH (NOLOCK)
        INNER JOIN dbo.Department d WITH (NOLOCK) ON u.UnitId = d.UnitId
        INNER JOIN dbo.[Group] AS t WITH (NOLOCK) ON d.DepartmentId = t.DepartmentId
    WHERE t.CompanyId = @CompanyId

	SELECT *
	FROM #tblDepartment WITH (NOLOCK)
	WHERE @FromDate IS NULL
		OR ModifiedDate > @FromDate
	ORDER BY DepartmentId

	DROP TABLE #tblDepartment
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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
      ,[EmployeeCard]' + CHAR(13)
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
	  + ',g.GroupId AS [TeamId]' + CHAR(13)
	  + ',g.Code AS [TeamCode]' + CHAR(13)
	  + ',g.Name AS [TeamName]' + CHAR(13)
	  + ',g.Rank' + CHAR(13)
	  + ',dep.DepartmentId' + CHAR(13)
	  + ',dep.Code AS DepartmentCode' + CHAR(13)
	  + ',dep.[Name] AS DepartmentName' + CHAR(13)
	  + 'FROM dbo.Employee AS e WITH (NOLOCK)' + CHAR(13)
	  + 'INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = ' + CAST(@companyId AS VARCHAR(10))  + CHAR(13)
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

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Unit_Get] @IsActive BIT = NULL
AS
/*
	Created: 20200521@Patsy.Doan
	Task: Get unit.
	DB: HRM

	Revisions:
		20250403@Tim: remove param CompanyId [Redmine: #222886]
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	SELECT u.UnitId
		,u.Code
		,u.[Name]
		,u.GroupUnitId
		,u.PICEmpId
		,e.NickName AS PICNickName
		,u.Category
		,u.[Type]
		,u.AccountableArea
		,u.IsActive
		,u.ModifiedDate
	FROM dbo.Unit AS u WITH (NOLOCK)
	LEFT JOIN dbo.Employee As e WITH (NOLOCK) ON e.EmpId = u.PICEmpId
	WHERE (
			@IsActive IS NULL
			OR u.IsActive = @IsActive
			)
			AND u.IsDeleted = 0
	ORDER BY u.Code
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Group_Get] @CompanyId INT
    ,@TeamId INT = NULL
	,@keyWord varchar(20) = null
	,@isDeleted BIT = NULL
AS
/*
Created: Tom.Vo@2013-10-21
Task: get group
DB: HRM

Revisions:
	20250310@Mira: filter by CompanyId [Redmine: #217976]
    20250403@Tim: remove section [Redmine: #222886]
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
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,tbl.NoOfMembers
		,tbl.TotalLocal
		,tbl.TotalExpat
		,g.PICEmpId
		,ld.NickName as PICNickName
		,dept.DepartmentId
        ,dept.Code
        ,dept.[Name]
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.Employee AS ld WITH (NOLOCK) ON ld.EmpId = g.PICEmpId
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

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Unit_Update]
(
	@UnitId INT
	,@Code VARCHAR(20)
	,@Name VARCHAR(100)
	,@GroupUnitId INT
	,@PICEmpId INT = NULL
	,@Category VARCHAR(150) = ''
	,@Type VARCHAR(150) = ''
	,@AccountableArea VARCHAR(150) = ''
	,@IsActive BIT = NULL
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
	Created: 20200521@Patsy.Doan
	Task: Update Unit.
	DB: HRM

	Revisions:
		- 20250410@Henry: remove company_id + update field [Redmine: #221569]
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
		SELECT 1
		FROM dbo.Unit WITH (NOLOCK)
		WHERE GroupUnitId = @GroupUnitId
			AND UnitId <> @UnitId
			AND IsDeleted = 0
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Business Unit ID ' + CAST(@GroupUnitId AS NVARCHAR(10)) + ' has already exists'

		RETURN
	END

	IF EXISTS (
		SELECT 1
		FROM dbo.Unit WITH (NOLOCK)
		WHERE Code = @Code
			AND UnitId <> @UnitId
			AND IsDeleted = 0
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Business Unit code ' + @Code + ' has already exists'

		RETURN
	END

	UPDATE dbo.Unit WITH (ROWLOCK, UPDLOCK)
	SET [Code] = @Code
		,[Name] = @Name
		,[GroupUnitId] = @GroupUnitId
		,[PICEmpId] = @PICEmpId
		,[Category] = @Category
		,[Type] = @Type
		,[AccountableArea] = @AccountableArea
		,[IsActive] = @IsActive
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()
	WHERE UnitId = @UnitId
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Unit_Insert] 
(	@Code VARCHAR(20)
	,@Name VARCHAR(100)
	,@GroupUnitId INT
	,@PICEmpId INT = NULL
	,@Category VARCHAR(150) = ''
	,@Type VARCHAR(150) = ''
	,@AccountableArea VARCHAR(150) = ''
	,@IsActive BIT = 1
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
	Created: 20200521@Patsy.Doan
	Task: Insert Unit.
	DB: HRM

	Revisions:
		- 20250410@Henry: remove company_id + update field [Redmine: #221569]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
		SELECT 1
		FROM dbo.Unit WITH (NOLOCK)
		WHERE GroupUnitId = @GroupUnitId
            AND IsDeleted = 0
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Business Unit ID ' + CAST(@GroupUnitId AS NVARCHAR(10)) + ' has already exists'

		RETURN
	END

	IF EXISTS (
		SELECT 1
		FROM dbo.Unit WITH (NOLOCK)
		WHERE Code = @Code
            AND IsDeleted = 0
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Business Unit code ' + @Code + ' has already exists'

		RETURN
	END

	INSERT INTO dbo.Unit(
		[Code]
		,[Name]
		,[GroupUnitId]
		,[PICEmpId]
		,[Category]
		,[Type]
		,[AccountableArea]
		,[ModifiedBy]
		,[ModifiedDate]
		,[IsActive]
		,[IsDeleted]
		)
	VALUES (
		@Code
		,@Name
		,@GroupUnitId
		,@PICEmpId
		,@Category
		,@Type
		,@AccountableArea
		,@CreatedBy
		,GETDATE()
		,@IsActive
		,0
		)
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Unit_GetById]
(
	@UnitId INT
)
AS
/*
	Created: 20200520@Patsy.doan
	Task: Unit_GetById
	DB: HRM
	Original: 
	Revisions:  
		- 20250410@Henry: remove companyid param, update field [Redmine: #221569]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SELECT u.UnitId
		,u.Code
		,u.Name
		,u.GroupUnitId
		,u.PICEmpId
		,u.Category
		,u.Type
		,u.AccountableArea
		,u.IsActive
		,u.ModifiedDate
	FROM dbo.Unit as u
	WHERE u.UnitId =@UnitId
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeSupervisor_Get] @EmployeeId INT = NULL
	,@ActionType TINYINT = NULL
	,@TeamIds NVARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
AS
/*
Created: 20140717@Quinn.Vo
Task: Get list supervisors.
DB: SMS-HRM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblGroup (GroupId INT)

	CREATE TABLE #tblEmployeeSupervisor (EmpId INT)

	CREATE TABLE #tblEmployee (
		EmpId INT
		,OwnerId INT
		,ActionType TINYINT
		)

	IF ISNULL( @TeamIds, '') <> ''
	BEGIN		
		INSERT INTO #tblGroup (GroupId)
		SELECT val
		FROM fnc_strSplit( @TeamIds, ',')
	END

	INSERT INTO #tblEmployee (
		EmpId
		,OwnerId
		,ActionType
		)
	SELECT DISTINCT su.EmpId
		,su.OwnerId
		,su.ActionType
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS [owner] WITH (NOLOCK) ON su.OwnerId = [owner].EmpId
		AND ISNULL([owner].isDeleted, 0) = 0
		AND [owner].[Enabled] = 1
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON su.EmpId = emp.EmpId
		AND ISNULL(emp.isDeleted, 0) = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN #tblGroup AS tblgr WITH (NOLOCK) ON gr.GroupId = tblgr.GroupId
	WHERE ISNULL(su.IsDeleted, 0) = 0
		AND su.ActionType IN (2, 3, 8)
		AND (
			@ActionType IS NULL
			OR su.ActionType = @ActionType
			)
		AND ISNULL(@EmployeeId, emp.EmpId) = emp.EmpId
		AND ISNULL(@IsLocal, es.IsLocal) = es.IsLocal
		AND (
			 -- ISNULL( @TeamIds, '') = '' OR 
			tblgr.GroupId IS NOT NULL
			)

	INSERT INTO #tblEmployee (
		EmpId
		,OwnerId
		,ActionType
		)
	SELECT DISTINCT su.OwnerId
		,su.EmpId
		,su.ActionType
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS [owner] WITH (NOLOCK) ON su.EmpId = [owner].EmpId
		AND ISNULL([owner].isDeleted, 0) = 0
		AND [owner].[Enabled] = 1
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON su.OwnerId = emp.EmpId
		AND ISNULL(emp.isDeleted, 0) = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN #tblGroup AS tblgr WITH (NOLOCK) ON gr.GroupId = tblgr.GroupId
	WHERE ISNULL(su.IsDeleted, 0) = 0
		AND su.ActionType IN (4, 5)
		AND (
			@ActionType IS NULL
			OR su.ActionType = @ActionType
			)
		AND ISNULL(@EmployeeId, emp.EmpId) = emp.EmpId
		AND ISNULL(@IsLocal, es.IsLocal) = es.IsLocal
		AND (
			-- ISNULL( @TeamIds, '') = '' OR 
			tblgr.GroupId IS NOT NULL
			)

	INSERT INTO #tblEmployeeSupervisor(EmpId)
	SELECT DISTINCT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.EmployeeSupervisor AS su WITH (NOLOCK) ON e.EmpId = su.EmpId
		LEFT JOIN #tblGroup AS tblgr WITH (NOLOCK) ON e.GroupId = tblgr.GroupId
	WHERE (
			@ActionType IS NULL
			OR su.ActionType = @ActionType
			)
		AND ISNULL(@EmployeeId, e.EmpId) = e.EmpId
		AND ISNULL(@IsLocal, es.IsLocal) = es.IsLocal
		AND (
			--ISNULL( @TeamIds, '') = '' OR
			tblgr.GroupId IS NOT NULL
			)
		AND e.[Enabled] = 1
		AND ISNULL(e.IsDeleted, 0) = 0
		AND ISNULL(su.IsDeleted, 0) = 0
	ORDER BY e.EmpId

	SELECT DISTINCT e.EmpId
		,e.Code
		,e.NickName
		,e.FullName
		,dep.[Name] AS Department
		,g.GroupId AS TeamId
		,g.Code
		,g.[Name]
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN #tblEmployeeSupervisor AS esu WITH (NOLOCK) ON esu.EmpId = e.EmpId
		LEFT JOIN #tblGroup AS tblgr WITH (NOLOCK) ON g.GroupId = tblgr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
	WHERE ISNULL(e.isDeleted, 0) = 0
		AND ISNULL(e.[Enabled], 1) = 1
		AND ISNULL(@EmployeeId, e.EmpId) = e.EmpId
		AND ISNULL(@IsLocal, es.IsLocal) = es.IsLocal
		AND (
			--ISNULL( @TeamIds, '') = '' OR
			tblgr.GroupId IS NOT NULL
			)
	ORDER BY e.Code

	SELECT DISTINCT emRo.EmployeeId
		,emRo.RoleId
		,loDa.Code
		,loDa.[Name]
	FROM dbo.EmployeeRole AS emRo WITH (NOLOCK)
		INNER JOIN dbo.LookupData AS loDa WITH (NOLOCK) ON emRo.RoleId = loDa.Value
		INNER JOIN dbo.[Lookup] AS look WITH (NOLOCK) ON look.Id = loDa.LookupId
		AND look.Code = 'SR' -- System Role
		INNER JOIN #tblEmployeeSupervisor AS e WITH (NOLOCK) ON e.EmpId = emRo.EmployeeId;

	SELECT DISTINCT su.OwnerId
		,e.NickName
		,e.FullName
		,su.ActionType
		,su.EmpId
		,e1.NickName
		,e1.FullName
		,e1.Code
	FROM #tblEmployee AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.OwnerId = e.EmpId
		AND ISNULL(e.isDeleted, 0) = 0
		AND e.[Enabled] = 1
		INNER JOIN dbo.Employee AS e1 WITH (NOLOCK) ON su.EmpId = e1.EmpId
		AND ISNULL(e1.isDeleted, 0) = 0
		AND e1.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e1.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON e1.GroupId = gr.GroupId
	ORDER BY e1.Code
		,e.NickName
		,su.ActionType

	DROP TABLE #tblEmployee

	DROP TABLE #tblGroup
	
	DROP TABLE #tblEmployeeSupervisor
END




GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[GroupSupervisor_Get]
(
    @CompanyId SMALLINT
    ,@TeamIds VARCHAR(MAX) = ''
)
AS
/*
    Created: 20140723@Quinn.Vo
    Task: Get list supervisors by group ids.
    DB: bodb_HRM

    Revisions:
        20250409@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpTeam (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	SELECT gr.GroupId AS TeamId
		,gr.Code
		,gr.[Name]
        ,dep.Code AS DepartmentCode
		,dep.[Name] AS DepartmentName
	FROM dbo.[Group] AS gr WITH (NOLOCK)
		INNER JOIN #tmpTeam AS tblgr WITH (NOLOCK) ON gr.GroupId = tblgr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
	WHERE gr.CompanyId = @CompanyId
        AND ISNULL(gr.IsDeleted, 0) = 0
	ORDER BY gr.Code

	SELECT DISTINCT su.OwnerId
		,emp.NickName
		,emp.FullName
		,su.ActionType
		,su.GroupId AS TeamId
		,gr.Code
        ,gr.[Name]
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON su.GroupId = gr.GroupId
		AND ISNULL(gr.IsDeleted, 0) = 0
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON su.OwnerId = emp.EmpId
		AND ISNULL(emp.isDeleted, 0) = 0
		AND emp.[Enabled] = 1
	WHERE gr.CompanyId = @CompanyId
        AND su.ActionType IN (2, 3, 4, 5, 8)
		AND ISNULL(su.IsDeleted, 0) = 0

	DROP TABLE #tmpTeam
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_UnpaidLeaveSummary] @Year INT
	,@EmpId INT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@LeaveType VARCHAR(MAX) = ''
	,@CompanyId INT
AS
/*
	Created: 20151028@Quinn.Vo
	Task: Get unpaid leave report.
	DB: SMS-HRM
	Original:

	Revisions: 
		by Oliver.Dang on 20190531
		20250408@Hank: remove section [Redmine: #222886]

	Param's Explanation:
	LeaveType:
	- 1: UPL
	- 2: UPL Insurance
	- 3: Paternity
	- 4: Maternity
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromDate DATE = CAST(@year AS VARCHAR(5)) + '-01-01'
		,@toDate DATE = CAST(@year AS VARCHAR(5)) + '-12-31'
	DECLARE @tblLeaveTypes TABLE (LeaveTypeId INT)

	CREATE TABLE #tblRptGroupIds (GroupId INT)

	CREATE TABLE #tblRptEmployeeIds (EmpId INT)

	IF ISNULL(@LeaveType, '') <> ''
	BEGIN
		INSERT INTO @tblLeaveTypes (LeaveTypeId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@LeaveType, ',')
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblRptGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END
	ELSE
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.Employee AS e WITH (NOLOCK)
					INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON e.EmpId = er.EmployeeId
				WHERE EmpId = @SupervisorId
					AND er.RoleId IN (2, 3, 4, 5, 6, 7)
				)
		BEGIN
			SET @EmpId = @SupervisorId
		END
	END

	IF @EmpId IS NULL
	BEGIN
		INSERT INTO #tblRptEmployeeIds (EmpId)
		SELECT DISTINCT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 0, @CompanyId)
	END
	ELSE
	BEGIN
		INSERT INTO #tblRptEmployeeIds (EmpId)
		VALUES (@EmpId)
	END

	SELECT SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 1
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Jan
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 2
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Feb
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 3
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Mar
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 4
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Apr
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 5
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS May
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 6
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Jun
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 7
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Jul
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 8
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Aug
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 9
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Sep
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 10
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Oct
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 11
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS Nov
		,SUM((CASE 
				WHEN MONTH(empca.WorkDate) = 12
					AND lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS [Dec]
		,SUM((CASE 
				WHEN lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) AS [LeaveBalance]
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,g.GroupId AS TeamId
		,g.[Name] AS Team
		,dep.[Name] AS Department
	FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
		AND ISNULL(emp.isDeleted, 0) = 0
		AND ISNULL(emp.[Enabled], 0) = 1
		INNER JOIN EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = emp.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		LEFT JOIN @tblLeaveTypes AS lt ON lt.LeaveTypeId = empca.LeaveTypeId
		OR lt.LeaveTypeId = empca.LeaveTypeId2
	WHERE (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND empca.IsOffday = 0
		AND empca.IsHoliday = 0
		AND empca.IsLeaveDay = 1
		AND EXISTS (
			SELECT 1
			FROM #tblRptGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND EXISTS (
			SELECT 1
			FROM #tblRptEmployeeIds AS tbl WITH (NOLOCK)
			WHERE emp.EmpId = tbl.EmpId
			)
	GROUP BY emp.EmpId
		,emp.NickName
		,emp.FullName
		,g.GroupId
		,g.[Name]
		,dep.[Name]
	HAVING SUM((CASE 
				WHEN lt.LeaveTypeId IS NOT NULL THEN (CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay END
						)
				ELSE 0 END
				)) > 0
	ORDER BY g.[Name]

	DROP TABLE #tblRptGroupIds

	DROP TABLE #tblRptEmployeeIds
END


GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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
		,dep.[Name] AS Department
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
		,dep.[Name] AS Department
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

GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SyncEPA_EmployeeGroup_Get] 
(
	@CompanyId INT,
    @FromDate DATETIME = NULL
)
AS
/*
    Created: 20140320@Quinn.Vo
    Task: Get all groups from change date
    DB: bodb_HRM

    Revisions:
        20250409@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @FromDate IS NOT NULL
	BEGIN
		SELECT @FromDate = DATEADD(HH, - 1, @FromDate)
	END

	SELECT ISNULL(g.OldGroupId, g.GroupId) AS TeamId
		,g.DepartmentId
		,g.Code
		,g.[Name]
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
	FROM dbo.[Group] AS g WITH (NOLOCK)
	WHERE g.CompanyId = @CompanyId 
        AND (@FromDate IS NULL OR ISNULL(g.ModifiedDate, g.CreatedDate) > @FromDate)
	ORDER BY TeamId
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SyncEPA_GroupSupervisor_Get]
(
	@CompanyId INT,
    @FromDate DATETIME = NULL
)
AS
/*
    Created: 20150921@Quinn.Vo
    Task: Get all group supervisor from change date
    DB: bodb_HRM

    Revisions:  
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @FromDate IS NOT NULL
	BEGIN
		SELECT @FromDate = DATEADD(HH, -1, @FromDate)
	END

	SELECT DISTINCT ISNULL(e.OldEmpId, e.EmpId) AS OwnerId
		,ISNULL(g.OldGroupId, g.GroupId) AS GroupId
		,m.[ModifiedDate]
		,ISNULL(r.[IsDeleted], 0) AS IsDeleted
	FROM (
		SELECT OwnerId
			,GroupId
			,MAX(ModifiedDate) AS ModifiedDate
		FROM dbo.GroupSupervisor WITH (NOLOCK)
		WHERE ActionType IN (2, 3)
			AND (
				@FromDate IS NULL
				OR ModifiedDate > @FromDate
				)
		GROUP BY OwnerId
			,GroupId
		) AS m
		INNER JOIN dbo.[GroupSupervisor] r WITH (NOLOCK) ON r.OwnerId = m.OwnerId
		AND r.GroupId = m.GroupId
		AND r.ModifiedDate = m.ModifiedDate
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = r.GroupId AND g.CompanyId = @CompanyId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = r.OwnerId
	WHERE m.OwnerId > 0
	ORDER BY OwnerId, GroupId
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Auto_AnnualLeaveBalance_Get]
(
	@CompanyId SMALLINT
    ,@year INT
)
AS
/*
    Created: Tim.Trinh@25-07-2022
    Task: annual leave balance
    DB: bodb_HRM

    Revisions:
        - 20250409@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromdate DATETIME = CAST(@year AS VARCHAR(10)) + '/01/01'
		,@todate DATETIME

	SET @todate = DATEADD(yy, 1, @fromdate)

	SELECT e.EmpId
		,ISNULL(CreditDays, 0) AS CreditDays
		,SUM(ISNULL(DeductDays, 0)) AS DeductDays
	INTO #tmpCurrenBalance
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON c.EmpId = e.EmpId AND c.CompanyId = @CompanyId
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
			WHERE lt.FromDate >= @fromdate
				AND lt.FromDate < @todate
				AND ISNULL(lt.Deleted, 0) = 0
				AND lt.CreditDays > 0
				AND ISNULL(lt.Deleted, 0) = 0
			GROUP BY lt.EmpId
		) cred ON e.EmpId = cred.Empid
	WHERE e.[Enabled] = 1
		AND (
			e.isDeleted = 0
			OR YEAR(e.ResignedDate) >= year(@todate)
			)
	GROUP BY e.EmpId
		,ISNULL(cred.CreditDays, 0)

	SELECT ISNULL(CreditDays, 0) AS AnnualLeaveCurrentYear
		,ISNULL(CreditDays, 0) - ISNULL(cb.DeductDays, 0) AS LeaveBalance
		,cb.EmpId
		,e.Code
		,Nickname
		,FullName
		,Email
		,dept.DepartmentId
		,dept.[Name] AS DepartmentName
		,e.LetsTalk
		,esm.IsLocal
	INTO #tmpEmployeeLeaveBalance
	FROM #tmpCurrenBalance AS cb WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = cb.EmpId
		INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON c.EmpId = e.EmpId AND c.CompanyId = @CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId AND g.CompanyId = @CompanyId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON dept.DepartmentId = g.DepartmentId
		INNER JOIN dbo.EmployeeSummary AS esm WITH (NOLOCK) ON esm.EmpId = e.EmpId
	WHERE e.[Enabled] = 1
		AND e.isDeleted = 0
		AND ISNULL(CreditDays, 0) > 0
		AND ISNULL(CreditDays, 0) - ISNULL(cb.DeductDays, 0) > 0
		AND esm.IsTopManager = 0
	ORDER BY e.Nickname

	SELECT EmpId
		,Code
		,Nickname
		,FullName
		,Email
		,AnnualLeaveCurrentYear
		,LeaveBalance
		,DepartmentId
		,DepartmentName
		,LetsTalk
		,IsLocal
	FROM #tmpEmployeeLeaveBalance WITH (NOLOCK)

	SELECT DISTINCT tmpemp.EmpId
		,su.OwnerId
		,suemp.Code
		,suemp.FullName
		,suemp.Nickname
		,suemp.Email
		,dept.DepartmentId
		,dept.[Name] AS DepartmentName
		,suemp.LetsTalk
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON c.EmpId = su.EmpId AND c.CompanyId = @CompanyId
		INNER JOIN #tmpEmployeeLeaveBalance AS tmpemp WITH (NOLOCK) ON su.EmpId = tmpemp.EmpId
		INNER JOIN dbo.Employee AS suemp WITH (NOLOCK) ON su.OwnerId = suemp.EmpId
		INNER JOIN dbo.CompanyEmployee AS cu WITH (NOLOCK) ON cu.EmpId = suemp.EmpId AND cu.CompanyId = @CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = suemp.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON dept.DepartmentId = g.DepartmentId
		AND suemp.[Enabled] = 1
		AND suemp.isDeleted = 0
	WHERE su.RequestType = 6
		AND su.ActionType IN (2, 3)
		AND su.IsDeleted = 0
	
	UNION ALL
	SELECT DISTINCT tmpemp.EmpId
		,su.OwnerId
		,suemp.Code
		,suemp.FullName
		,suemp.Nickname
		,suemp.Email
		,dept.DepartmentId
		,dept.[Name] AS DepartmentName
		,suemp.LetsTalk
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.GroupId = e.GroupId
		INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON c.EmpId = e.EmpId AND c.CompanyId = @CompanyId
		INNER JOIN #tmpEmployeeLeaveBalance AS tmpemp WITH (NOLOCK) ON e.EmpId = tmpemp.EmpId
		INNER JOIN dbo.Employee AS suemp WITH (NOLOCK) ON su.OwnerId = suemp.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = suemp.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON dept.DepartmentId = g.DepartmentId
	WHERE su.RequestType = 6
		AND su.ActionType IN (2, 3)
		AND su.IsDeleted = 0
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSupervisor AS empsu WITH (NOLOCK)
			WHERE e.EmpId = empsu.EmpId
				AND empsu.IsDeleted = 0
				AND empsu.RequestType = 6
				AND empsu.ActionType IN (2, 3)
			)

	SELECT dep.DepartmentId
		,dep.[Name] AS DepartmentName
		,COUNT(*) AS TotalEmployee
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON c.EmpId = e.EmpId AND c.CompanyId = @CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
	WHERE e.[Enabled] = 1
		AND e.isDeleted = 0
	GROUP BY dep.DepartmentId
		,dep.[Name]
	ORDER BY dep.[Name]

	DROP TABLE #tmpCurrenBalance

	DROP TABLE #tmpEmployeeLeaveBalance
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeWorkFromHome_Get]
(
    @FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
)
AS
/*
    Created: 20210528@Quinn.Vo
    Task: Get Employee Work From Home by date.
    DB: bodb_HRM

    Revisions:
        - 20250409@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpTeam (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	SELECT ew.EmployeeWorkFromHomeId
		,ew.FromDate
		,ew.ToDate
		,e.EmpId
		,e.Code
		,e.NickName
		,e.FullName
		,g.[Name] AS TeamName
		,dep.[Name] AS DepartmentName
		,ew.ModifiedDate
		,ew.ModifiedBy
		,modifier.NickName AS Modifier
		,ew.Remark
	FROM dbo.EmployeeWorkFromHome AS ew WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ew.EmpId = e.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON e.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN #tmpTeam AS t WITH (NOLOCK) ON g.GroupId = t.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		LEFT JOIN dbo.Employee AS modifier WITH (NOLOCK) ON ew.ModifiedBy = modifier.EmpId
	WHERE (
			(
				ew.FromDate BETWEEN @FromDate
					AND @ToDate
				)
			OR (
				ew.ToDate BETWEEN @FromDate
					AND @ToDate
				)
			OR (
				@FromDate BETWEEN ew.FromDate
					AND ew.ToDate
				)
			OR (
				@ToDate BETWEEN ew.FromDate
					AND ew.ToDate
				)
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
	ORDER BY ew.FromDate
		,g.[Name]

    DROP TABLE #tmpTeam
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[tmpEmployeeCalendar_Insert]
(
    @CompanyId SMALLINT = NULL
    ,@fromDate DATE
	,@toDate DATE
	,@empIds VARCHAR(MAX) = NULL
	,@isEnable BIT = NULL
	,@isDelete BIT = NULL
	,@isUpdateRequestData BIT = 0
)
AS
/*
    Created: Tim.Trinh@2019-10-10
    Task: get employee calendar
    DB: bodb_HRM

    Revisions:
        - 20250409@Tim: remove update holiday
    Param's Explanation:
*/
BEGIN
	DECLARE @tempDate DATE = @fromDate
		,@GeneralLeaveId TINYINT = 0
		,@OffDayShiftId SMALLINT = - 1
		-- work type
		,@OffDay TINYINT = 1
		,@LeaveDay TINYINT = 2
		-- leave type
		,@MaternityLeaveId TINYINT = 12
		,@PaternityLeaveId TINYINT = 14
		-- request type
		,@ChangeShiftRequestTypeId TINYINT = 5
		,@LeaveRequestTypeId TINYINT = 6
		,@KeepInViewRequestTypeId TINYINT = 7
		-- change shift type
		,@ChangeShiftTypeId TINYINT = 1
		,@MoveOfDayTypeId TINYINT = 2
		-- kiv type
		,@KeepInViewByDayTypeId TINYINT = 1
		-- request status
		,@PendingStatusId TINYINT = 1
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7

	CREATE TABLE #tempEmployeeIds (
		EmpId INT PRIMARY KEY
        ,JoinedDate DATE
		,ResignedDate DATE
		)

	CREATE TABLE #tempEmployeeCalendar (
		EmpId INT
		,WorkDate DATE
		,ShiftId INT
		,IsOffDay BIT
		,IsHoliday BIT
		,PRIMARY KEY (EmpId, WorkDate)
		)

	IF ISNULL(@empIds, '') <> ''
	BEGIN
		INSERT INTO #tempEmployeeIds (
			EmpId
			,JoinedDate
			,ResignedDate
			)
		SELECT emp.EmpId
			,emp.JoinedDate
			,emp.ResignedDate
		FROM STRING_SPLIT(@empIds, ',') AS tmp
			INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON CAST(tmp.value AS INT) = emp.EmpId
	END
	ELSE
	BEGIN
		INSERT INTO #tempEmployeeIds (
			EmpId
			,JoinedDate
			,ResignedDate
			)
		SELECT EmpId
			,JoinedDate
			,ResignedDate
		FROM dbo.Employee WITH (NOLOCK)
		WHERE (
				@isEnable IS NULL
				OR [Enabled] = @isEnable
				)
			AND (
				@isDelete IS NULL
				OR isDeleted = @isDelete
				)
	END

	INSERT INTO #tempEmployeeCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsOffDay
		,IsHoliday
		)
	SELECT empca.EmpId
		,empca.WorkDate
		,empca.ShiftId
		,ISNULL(empca.IsOffDay, 0)
		,ISNULL(empca.IsHoliday, 0)
	FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
		INNER JOIN #tempEmployeeIds AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		--AND (
		--	empca.ShiftId IS NOT NULL
		--	OR empca.IsOffDay = 1
		--	OR empca.IsHoliday = 1
		--	)

	WHILE @tempDate <= @toDate
	BEGIN
		INSERT INTO #tempEmployeeCalendar (
			EmpId
			,WorkDate
			,ShiftId
			,IsOffDay
			,IsHoliday
			)
		SELECT emp.EmpId
			,@tempDate
			,CASE 
				WHEN DATEPART(dw, @tempDate) = 1 THEN empshift.SunShift
				WHEN DATEPART(dw, @tempDate) = 2 THEN empshift.MonShift
				WHEN DATEPART(dw, @tempDate) = 3 THEN empshift.TueShift
				WHEN DATEPART(dw, @tempDate) = 4 THEN empshift.WedShift
				WHEN DATEPART(dw, @tempDate) = 5 THEN empshift.ThuShift
				WHEN DATEPART(dw, @tempDate) = 6 THEN empshift.FriShift
				WHEN DATEPART(dw, @tempDate) = 7 THEN empshift.SatShift
				END
			,CASE 
				WHEN DATEPART(dw, @tempDate) = 1
					AND ISNULL(empshift.SunShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 2
					AND ISNULL(empshift.MonShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 3
					AND ISNULL(empshift.TueShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 4
					AND ISNULL(empshift.WedShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 5
					AND ISNULL(empshift.ThuShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 6
					AND ISNULL(empshift.FriShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 7
					AND ISNULL(empshift.SatShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				ELSE 0
				END
			,0
		FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
			AND empsum.IsDefaultSchedule = 1
			INNER JOIN dbo.EmployeeDefaultShift AS empshift WITH (NOLOCK) ON emp.EmpId = empshift.EmpId
		WHERE NOT EXISTS (
				SELECT 1
				FROM #tempEmployeeCalendar AS tbl WITH (NOLOCK)
				WHERE tbl.EmpId = emp.EmpId
					AND tbl.WorkDate = @tempDate
				)

		INSERT INTO #tempEmployeeCalendar (
			EmpId
			,WorkDate
			,ShiftId
			,IsOffDay
			,IsHoliday
			)
		SELECT emp.EmpId
			,@tempDate
			,empshift.ShiftId
			,0
			,0
		FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
			AND empsum.IsDefaultSchedule = 0
			OUTER APPLY (
			SELECT TOP 1 empshift.ShiftId
			FROM dbo.ScheduleArrangementDefaultShift AS empshift WITH (NOLOCK)
			WHERE empshift.EmployeeId = emp.EmpId
				--AND empshift.ShiftId > 0
				AND empshift.FromDate <= @tempDate
			ORDER BY empshift.FromDate DESC
			) AS empshift
		WHERE NOT EXISTS (
				SELECT 1
				FROM #tempEmployeeCalendar AS tbl WITH (NOLOCK)
				WHERE tbl.EmpId = emp.EmpId
					AND tbl.WorkDate = @tempDate
				)

		SET @tempDate = DATEADD(d, 1, @tempDate)
	END

	UPDATE empca
	SET empca.ShiftId = NULL
		,empca.IsOffDay = 0
		,empca.IsHoliday = 0
	FROM #tempEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
	WHERE (emp.JoinedDate > empca.WorkDate OR emp.ResignedDate <= empca.WorkDate)
		AND (empca.ShiftId IS NOT NULL OR empca.IsOffDay = 1 AND empca.IsHoliday = 1)

	UPDATE empca
	SET empca.ShiftId = tmp.ShiftId
		,empca.IsOffDay = tmp.IsOffDay
		,empca.IsHoliday = tmp.IsHoliday
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
		INNER JOIN #tempEmployeeCalendar AS tmp WITH (ROWLOCK) ON empca.EmpId = tmp.EmpId
		AND empca.WorkDate = tmp.WorkDate
	WHERE (
			empca.RequestId IS NULL
			OR (
				empca.RequestId IS NOT NULL
				AND (
					empca.RequestTypeId =  @LeaveRequestTypeId
					OR empca.RequestTypeId = @ChangeShiftRequestTypeId
					OR empca.RequestTypeId = @KeepInViewRequestTypeId
					)
				)
			)
		AND (
			ISNULL(empca.ShiftId, 0) != ISNULL(tmp.ShiftId, 0)
			OR empca.IsOffDay != tmp.IsOffDay
			OR empca.IsHoliday != tmp.IsHoliday
			)

	INSERT INTO dbo.tmpEmployeeCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsOffDay
		,IsHoliday
		,ModifiedDate
		)
	SELECT tmp.EmpId
		,tmp.WorkDate
		,tmp.ShiftId
		,tmp.IsOffDay
		,tmp.IsHoliday
		,CASE 
			WHEN emp.JoinedDate <= tmp.WorkDate
				AND (
					emp.ResignedDate IS NULL
					OR emp.ResignedDate > tmp.WorkDate
					) THEN GETDATE()
			ELSE NULL
			END
	FROM #tempEmployeeCalendar AS tmp WITH (ROWLOCK)
		INNER JOIN #tempEmployeeIds AS emp WITH (NOLOCK) ON tmp.EmpId = emp.EmpId
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
			WHERE empca.EmpId = tmp.EmpId
				AND empca.WorkDate = tmp.WorkDate
			)

	UPDATE dbo.tmpEmployeeCalendar WITH (ROWLOCK, UPDLOCK)
	SET IsOffDay = 0
		,ModifiedDate = GETDATE()
	WHERE WorkDate BETWEEN @fromDate
			AND @toDate
		AND IsOffDay = 1
		AND IsHoliday = 1

	IF @isUpdateRequestData = 0 RETURN

	-- overtime
	UPDATE empca
	SET empca.IsOvertime = (CASE 
			WHEN overtime.EmpId IS NOT NULL THEN 1
			ELSE 0 END
			)
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		LEFT JOIN dbo.OTDailyRequest AS overtime WITH (NOLOCK) ON empca.EmpId = overtime.EmpId
		AND empca.WorkDate = overtime.OvertimeDate
		AND overtime.[Status] NOT IN (@PendingStatusId, @NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.IsOvertime = 1
				AND overtime.EmpId IS NULL
				)
			OR (
				empca.IsOvertime = 0
				AND overtime.EmpId IS NOT NULL
				)
			)

	-- keep in view
	UPDATE empca
	SET empca.RequestId = kiv.RequestId
		,empca.RequestTypeId = kiv.RequestType
		,empca.IsKeepInView = CASE 
			WHEN kiv.RequestId IS NULL THEN 0
			ELSE 1
			END
		,empca.ShiftId = CASE 
			WHEN kiv.KeepInViewType = @KeepInViewByDayTypeId
				AND kiv.ShiftId IS NOT NULL THEN kiv.ShiftId
			ELSE empca.ShiftId
			END
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		OUTER APPLY (
		SELECT kiv.RequestId
			,kiv.KeepInViewType
			,kiv.ShiftId
			,r.RequestType
		FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON r.RequestId = kiv.RequestId
			AND empca.EmpId = kiv.EmpId
			AND empca.WorkDate = kiv.OnDate
			AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		) AS kiv
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.IsKeepInView = 1
				--AND empca.RequestTypeId = @KeepInViewRequestTypeId
				AND kiv.RequestId IS NULL
				)
			OR (
				empca.IsKeepInView = 0
				AND kiv.RequestId IS NOT NULL
				)
			)

	-- change shift
	UPDATE empca
	SET empca.RequestId = cs.RequestId
		,empca.RequestTypeId = cs.RequestType
		,empca.ShiftId = (CASE 
			WHEN cs.ToShift = @OffDayShiftId THEN NULL
			ELSE cs.ToShift END
			)
		,empca.IsOffDay = (CASE 
			WHEN cs.ToShift = @OffDayShiftId THEN 1
			ELSE empca.IsOffDay END
			)
		,empca.ChangeShiftTypeId = cs.ChangeShiftTypeId
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		OUTER APPLY (
		SELECT r.RequestId
			,r.RequestType
			,@ChangeShiftTypeId AS ChangeShiftTypeId
			,csdt.ToShift
		FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
			INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
			AND empca.EmpId = cs.EmpId
			AND empca.WorkDate = csdt.OnDate
			AND cs.TypeId = @ChangeShiftTypeId
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cs.RequestId = r.RequestId
			AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		) AS cs
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.RequestId IS NOT NULL
				AND empca.RequestTypeId = @ChangeShiftRequestTypeId
				AND empca.ChangeShiftTypeId = @ChangeShiftTypeId
				--AND cs.RequestId IS NULL
				)
			OR (
				empca.RequestId IS NULL
				AND cs.RequestId IS NOT NULL
				)
			)

	-- change shift - move off day
	UPDATE empca
	SET empca.RequestId = cs.RequestId
		,empca.RequestTypeId = cs.RequestType
		,empca.ShiftId = CASE 
			WHEN cs.RequestId IS NOT NULL THEN cs.ToShift
			ELSE NULL
			END
		,empca.IsOffDay = CASE 
			WHEN cs.RequestId IS NOT NULL THEN 0
			ELSE empca.IsOffDay
			END
		,empca.ChangeShiftTypeId = cs.ChangeShiftTypeId
		,empca.MoveOffFromDate = NULL
		,empca.MoveOffToDate = cs.ToDate
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		OUTER APPLY (
		SELECT r.RequestId
			,r.RequestType
			,@MoveOfDayTypeId AS ChangeShiftTypeId
			,csdt.FromShift
			,csdt.ToShift
			,csdt.ToDate
		FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
			INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
			AND empca.EmpId = cs.EmpId
			AND empca.WorkDate = csdt.OnDate
			AND cs.TypeId = @MoveOfDayTypeId
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cs.RequestId = r.RequestId
			AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		) AS cs
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.RequestId IS NOT NULL
				AND empca.RequestTypeId = @ChangeShiftRequestTypeId
				AND empca.ChangeShiftTypeId = @MoveOfDayTypeId
				AND empca.MoveOffToDate IS NOT NULL
				--AND cs.RequestId IS NULL
				)
			OR (
				empca.RequestId IS NULL
				AND cs.RequestId IS NOT NULL
				)
			)

	UPDATE empca
	SET empca.RequestId = cs.RequestId
		,empca.RequestTypeId = cs.RequestType
		,empca.ShiftId = CASE 
			WHEN cs.RequestId IS NOT NULL THEN NULL
			ELSE empca.ShiftId
			END
		,empca.IsOffDay = CASE 
			WHEN cs.RequestId IS NOT NULL THEN 1
			ELSE empca.IsOffDay
			END
		,empca.ChangeShiftTypeId = cs.ChangeShiftTypeId
		,empca.MoveOffFromDate = cs.OnDate
		,empca.MoveOffToDate = NULL
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		OUTER APPLY (
		SELECT r.RequestId
			,r.RequestType
			,@MoveOfDayTypeId AS ChangeShiftTypeId
			,csdt.OnDate
		FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
			INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
			AND empca.EmpId = cs.EmpId
			AND empca.WorkDate = csdt.ToDate
			AND cs.TypeId = @MoveOfDayTypeId
			AND (
				csdt.OnDate BETWEEN @fromDate
					AND @toDate
				OR csdt.ToDate BETWEEN @fromDate
					AND @toDate
				)
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cs.RequestId = r.RequestId
			AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		) AS cs
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.RequestId IS NOT NULL
				AND empca.RequestTypeId = @ChangeShiftRequestTypeId
				AND empca.ChangeShiftTypeId = @MoveOfDayTypeId
				AND empca.MoveOffFromDate IS NOT NULL
				--AND cs.RequestId IS NULL
				)
			OR (
				empca.RequestId IS NULL
				AND cs.RequestId IS NOT NULL
				)
			)

	-- leave request
	CREATE TABLE #tblLeaveRequest (
		RequestId BIGINT
		,EmpId INT
		,WorkDate DATE
		,RequestTypeId SMALLINT
		,LeaveTypeId INT
		,WorkType TINYINT
		)

	CREATE TABLE #tblHalfDayRequest (
		RequestId BIGINT
		,RequestTypeId SMALLINT
		,EmpId INT
		,WorkDate DATE
		,FromTime DATETIME
		,ToTime DATETIME
		,LeaveTypeId INT
		,WorkType TINYINT
		,LeaveDay DECIMAL(2, 1)
		)

	INSERT INTO #tblLeaveRequest (
		RequestId
		,EmpId
		,WorkDate
		,RequestTypeId
		,LeaveTypeId
		,WorkType
		)
	SELECT r.RequestId
		,empca.EmpId
		,empca.WorkDate
		,r.RequestType
		,lrdt.LeaveType
		,lrdt.WorkType
	FROM #tempEmployeeIds AS tblemp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
		INNER JOIN dbo.LeaveRequestDetail AS lrdt WITH (NOLOCK) ON lrdt.EmpId = tblemp.EmpId
		AND lrdt.OnDate = empca.WorkDate
		AND lrdt.WorkType IN (@OffDay, @LeaveDay)
		AND lrdt.IsHalfDay = 0
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lrdt.RequestId = r.RequestId
		AND empca.EmpId = r.EmpId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)

	INSERT INTO #tblLeaveRequest (
		RequestId
		,EmpId
		,WorkDate
		,RequestTypeId
		,LeaveTypeId
		,WorkType
		)
	SELECT r.RequestId
		,empca.EmpId
		,empca.WorkDate
		,r.RequestType
		,lr.LeaveType
		,@LeaveDay AS WorkType
	FROM #tempEmployeeIds AS tblemp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND empca.IsOffDay = 0
		AND empca.IsHoliday = 0
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON lr.EmpId = tblemp.EmpId
		AND empca.WorkDate BETWEEN lr.FromDate
			AND lr.ToDate
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lr.RequestId = r.RequestId
		AND tblemp.EmpId = r.EmpId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE NOT EXISTS (
			SELECT 1
			FROM #tblLeaveRequest AS tblreq WITH (NOLOCK)
			WHERE lr.RequestId = tblreq.RequestId
			)
		AND NOT EXISTS (
			SELECT ldt.RequestId
			FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			WHERE lr.RequestId = ldt.RequestId
			)

	UPDATE empca
	SET empca.RequestId = lr.RequestId
		,empca.RequestTypeId = lr.RequestTypeId
		,empca.LeaveTypeId = lr.LeaveTypeId
		,empca.IsOffDay = CASE 
			WHEN lr.WorkType = @OffDay THEN 1
			ELSE empca.IsOffDay
			END
		,empca.IsLeaveDay = CASE 
			WHEN lr.RequestId IS NOT NULL THEN 1
			ELSE 0
			END
		,empca.IsLeaveOffDay = CASE 
			WHEN lr.WorkType = @OffDay THEN 1
			ELSE 0
			END
		,empca.LeaveDay = CASE 
			WHEN lr.RequestId IS NOT NULL THEN 1
			ELSE 0
			END
		,empca.FromTime = NULL
		,empca.ToTime = NULL
		,empca.LeaveTypeId2 = NULL
		,empca.FromTime2 = NULL
		,empca.ToTime2 = NULL
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		LEFT JOIN #tblLeaveRequest AS lr ON empca.EmpId = lr.EmpId
		AND empca.WorkDate = lr.WorkDate
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.RequestId IS NOT NULL
				AND empca.RequestTypeId = @LeaveRequestTypeId
				--AND empca.LeaveDay = 1
				--AND lr.RequestId IS NULL
				)
			OR (
				empca.RequestId IS NULL
				AND lr.RequestId IS NOT NULL
				)
			)

	INSERT INTO #tblHalfDayRequest (
		RequestId
		,RequestTypeId
		,EmpId
		,WorkDate
		,FromTime
		,ToTime
		,LeaveTypeId
		,WorkType
		,LeaveDay
		)
	SELECT r.RequestId
		,r.RequestType
		,r.EmpId
		,lrdt.OnDate
		,lrdt.FromTime
		,lrdt.ToTime
		,lrdt.LeaveType
		,lrdt.WorkType
		,0.5 AS LeaveDay
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON r.EmpId = tblemp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON tblemp.EmpId = ce.EmpId
		INNER JOIN dbo.LeaveRequestDetail AS lrdt WITH (NOLOCK) ON r.RequestId = lrdt.RequestId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		AND lrdt.IsHalfDay = 1
		AND lrdt.WorkType = @LeaveDay
		AND lrdt.OnDate BETWEEN @fromDate
			AND @toDate
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.CompanyId = ce.CompanyId
        AND lrdt.LeaveType = lv.LeaveTypeId
	WHERE (@CompanyId IS NULL OR ce.CompanyId = @CompanyId)
        AND NOT EXISTS (
			SELECT 1
			FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
			WHERE r.EmpId = empca.EmpId
				AND lrdt.OnDate = empca.WorkDate
				AND (
					empca.LeaveDay = 1
					OR (
						empca.LeaveDay = 0.5
						AND (
							empca.LeaveTypeId = lrdt.LeaveType
							OR empca.LeaveTypeId2 = lrdt.LeaveType
							)
						)
					)
			)

	UPDATE empca
	SET empca.RequestId = rq.RequestId
		,empca.RequestTypeId = rq.RequestTypeId
		,empca.IsLeaveDay = 1
		,empca.LeaveDay = rq.LeaveDay
		,empca.LeaveTypeId = rq.LeaveTypeId
		,empca.FromTime = rq.FromTime
		,empca.ToTime = rq.ToTime
		,empca.LeaveTypeId2 = NULL
		,empca.FromTime2 = NULL
		,empca.ToTime2 = NULL
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblHalfDayRequest AS rq ON empca.EmpId = rq.EmpId
		AND empca.WorkDate = rq.WorkDate
	WHERE empca.LeaveTypeId IS NULL
		OR empca.LeaveDay = 0.5

	UPDATE empca
	SET empca.LeaveDay = CASE 
			WHEN empca.LeaveDay = 1 THEN 1
			ELSE empca.LeaveDay + rq.LeaveDay
			END
		,empca.IsLeaveDay = 1
		,empca.LeaveTypeId2 = rq.LeaveTypeId
		,empca.FromTime2 = rq.FromTime
		,empca.ToTime2 = rq.ToTime
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblHalfDayRequest AS rq ON empca.EmpId = rq.EmpId
		AND empca.WorkDate = rq.WorkDate
	WHERE empca.FromTime <> rq.FromTime
		AND empca.ToTime <> rq.ToTime

	DROP TABLE #tempEmployeeIds

	DROP TABLE #tblLeaveRequest

	DROP TABLE #tempEmployeeCalendar

	DROP TABLE #tblHalfDayRequest
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TimeRecord_Get]
(
    @EmpId INT = NULL
	,@SupervisorId INT = NULL
	,@FromDate DATETIME
	,@ToDate DATETIME
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@PageIndex INT = NULL
	,@ItemsPerPage INT = NULL
	,@TotalItem INT = 0 OUT
)
AS
/*
    Created: Quinn.Vo@2014-01-24
    Task: Get Time Record
    DB: bodb_HRM

    Revisions:
	    - 20200714@Merlin.Le: Get section code and department code
	    - 20250404@Jay.Do: remove section
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblGroupId (GroupId INT)

	CREATE CLUSTERED INDEX PK_tblGroupId ON #tblGroupId (GroupId);

	CREATE TABLE #tblTimeRecord (
		RecordTimeId INT
		,RecordTime DATETIME
		,InOutType TINYINT
		,EmpId INT
		,Code VARCHAR(20)
		,Nickname NVARCHAR(20)
		,FullName NVARCHAR(50)
		,Team NVARCHAR(150)
		,DepartmentCode NVARCHAR(50)
		,IsCheckInOutOnline BIT
		)

	CREATE CLUSTERED INDEX PK_tblTimeRecord ON #tblTimeRecord (RecordTimeId);

	INSERT INTO #tblGroupId (GroupId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TeamIds, ',')

	--IF @EmpId IS NULL
	--BEGIN
	--	INSERT INTO #tblEmployeeId (EmpId)
	--	SELECT EmpId
	--	FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 0)
	--END
	--ELSE
	--BEGIN
	--	INSERT INTO #tblEmployeeId (EmpId)
	--	VALUES (@EmpId)
	--END

	INSERT INTO #tblTimeRecord (
		RecordTimeId
		,RecordTime
		,InOutType
		,EmpId
		,Code
		,Nickname
		,FullName
		,Team
		,DepartmentCode
		,IsCheckInOutOnline
		)
	SELECT t.Id
		,t.RecordTime
		,t.InOutType
		,e.EmpId
		,e.Code
		,e.NickName
		,e.FullName
		,g.[Name]
		,dep.Code DepartmentCode
		,CASE
			WHEN tex.ID IS NOT NULL THEN 1
			ELSE 0
		END AS IsInOutOnline
	FROM dbo.TimeRecord AS t WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON t.EmpID = e.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON g.DepartmentId = dep.DepartmentId
		LEFT JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN dbo.TimeRecordExt AS tex WITH (NOLOCK) ON t.ID = tex.ID
	WHERE t.RecordTime BETWEEN @FromDate
			AND @ToDate
		AND (
			@EmpId IS NULL
			OR e.EmpId = @EmpId
			)
		AND (
			@IsLocal IS NULL
			OR es.IsLocal = @IsLocal
			)
		AND EXISTS(SELECT 1 FROM #tblGroupId AS tbl WITH (NOLOCK) WHERE g.GroupId = tbl.GroupId)
	ORDER BY e.EmpId
		,t.RecordTime DESC

	IF @PageIndex IS NOT NULL
		AND @ItemsPerPage IS NOT NULL
	BEGIN
		SELECT RecordTimeId
			,RecordTime
			,InOutType
			,EmpId
			,Code
			,Nickname
			,FullName
			,Team
			,DepartmentCode
			,IsCheckInOutOnline
		FROM #tblTimeRecord WITH (NOLOCK)
		ORDER BY RecordTime DESC OFFSET(@PageIndex * @ItemsPerPage) ROWS

		FETCH NEXT @ItemsPerPage ROWS ONLY;
	END
	ELSE
	BEGIN
		SELECT RecordTimeId
			,RecordTime
			,InOutType
			,EmpId
			,Code
			,Nickname
			,FullName
			,Team
			,DepartmentCode
			,IsCheckInOutOnline
		FROM #tblTimeRecord WITH (NOLOCK)
		ORDER BY RecordTime DESC
	END

	SELECT @TotalItem = COUNT(1)
	FROM #tblTimeRecord WITH (NOLOCK)

	DROP TABLE #tblGroupId

	--DROP TABLE #tblEmployeeId

	DROP TABLE #tblTimeRecord
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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
		LEFT JOIN dbo.HospitalizationLeaveTrans AS deduct WITH (NOLOCK) ON emp.EmpId = deduct.EmpId
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
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
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


GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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
		- 20250408@Hank: remove section [Redmine: #222886]
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
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
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


GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_EmployeeCalendarByWeekly] @empId INT = NULL
	,@fromtime DATE
	,@totime DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@JobTitleId VARCHAR(MAX) = ''
	,@isLocal BIT = NULL
	,@companyId INT
AS
/*
Created: Tom.Vo@2013-11-15
Task: view employee calendar by weekly
DB: HRM_SMS
Original:

Revisions:
	- 20200714@Merlin.Le: Get section and department code
	- 20250408@Hank: remove section [Redmine: #222886]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EmployeeIds VARCHAR(MAX)
	DECLARE @tblGroupIds TABLE (GroupId INT)
	DECLARE @tblJobTitleIds TABLE (JobTitleId INT)
	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	IF ISNULL(@TeamIds, '') <> ''
		INSERT INTO @tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	
	IF ISNULL(@JobTitleId, '') <> ''
		INSERT INTO @tblJobTitleIds (JobTitleId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@JobTitleId, ',')
	ELSE
	BEGIN
		INSERT INTO @tblJobTitleIds (JobTitleId)
		SELECT DISTINCT lk.Id
		FROM dbo.LookupData AS lk WITH (NOLOCK)
		WHERE lk.LookupId = 1
	END

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId AND ce.CompanyId = @companyId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		AND (
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND (
			@empId IS NULL
			OR emp.EmpId = @empId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tbl
			WHERE emp.GroupId = tbl.GroupId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblJobTitleIds AS tbl
			WHERE emp.JobTitleId = tbl.JobTitleId
			)

	SELECT @EmployeeIds = COALESCE(@EmployeeIds + ',', '') + CAST(EmployeeId AS VARCHAR(10))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @companyId
		,@fromDate = @fromtime
		,@toDate = @totime
		,@empIds = @EmployeeIds
		,@isEnable = 1
		,@isDelete = 0

	SELECT emp.EmpId AS EmployeeId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,gr.[Name] AS Team
		,dep.Code AS DepartmentCode
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmployeeId
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON emp.EmpId = esum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON gr.DepartmentId = dep.DepartmentId
	ORDER BY gr.[Name]
		,emp.Code

	SELECT emp.EmpId AS EmployeeId
		,emp.NickName
		,empca.WorkDate
		,empca.IsOvertime
		,empca.IsLeaveOffDay
		,empca.ChangeShiftTypeId
		,empca.MoveOffFromDate
		,empca.MoveOffToDate
		,empca.IsHoliday
		,empca.IsOffDay
		,empca.IsLeaveDay
		,empca.IsKeepInView
		,empca.LeaveDay
		,(CASE 
			WHEN offrep.EmployeeId IS NOT NULL THEN 1
			ELSE 0 END
			) AS IsOffDayReplacement
		,shift.ShiftId
		,shift.Code
		,shift.[Name]
		,shift.BeginCheckInTime AS CheckIn
		,shift.BeginCheckOutTime AS CheckOut
		,shift.IsInAfterDay
		,shift.IsOutAfterDay
		,lv1.LeaveTypeId
		,lv1.Code
		,lv1.[Name]
		,empca.FromTime
		,empca.ToTime
		,lv2.LeaveTypeId AS LeaveTypeId2
		,lv2.Code
		,lv2.[Name]
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmployeeId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca ON emp.EmpId = empca.EmpId
		AND empca.WorkDate BETWEEN @fromTime
			AND @toTime
		LEFT JOIN dbo.Shift AS shift WITH (NOLOCK) ON shift.ShiftId = empca.ShiftId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId AND lv1.CompanyId = @companyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId AND lv2.CompanyId = @companyId
		LEFT JOIN dbo.ScheduleArrangementOffDayReplacement AS offrep WITH (NOLOCK) ON emp.EmpId = offrep.EmployeeId
		AND empca.WorkDate = offrep.WorkDate
	ORDER BY emp.NickName
		,empca.WorkDate

	DROP TABLE #tblEmployeeIds
END

GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ScheduleArrangement_SyncWorkingShift] @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@EmployeeIds NVARCHAR(MAX) = ''
	,@WorkingShiftXml NVARCHAR(MAX) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20220106@Tim.Trinh
Task: sync working shift from OWP
DB: HRM

Revisions:
Param's Explanation:
- @WorkingShiftXml: "<Root>
		<Row EmployeeID={1} ShiftCode={2} ShiftDate={3} IsOffDay={4} IsPublicHoliday={5} ModifiedDate={6} />
	</Root>"
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SyncDate DATETIME = GETDATE()
		,@Today DATE = GETDATE()
		,@EmpId INT
		,@WorkDate DATE
		,@DocHandler INT

	CREATE TABLE #tmpWorkingShift (
		EmployeeID VARCHAR(20)
		,ShiftCode VARCHAR(20)
		,ShiftDate DATE
		,IsOffDay BIT
		,IsHoliday BIT
		,ModifiedDate DATETIME
		)

	CREATE TABLE #tmpEmployeeIds (EmpId INT PRIMARY KEY)

	CREATE TABLE #tmpEmployeeCalendar (
		EmpId INT
		,WorkDate DATE
		,ShiftId INT
		,IsOffDay BIT
		,IsHoliday BIT
		)

	IF ISNULL(@EmployeeIds, '') <> ''
	BEGIN
		INSERT INTO #tmpEmployeeIds (EmpId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@EmployeeIds, ',')
		WHERE ISNUMERIC(value) = 1
	END

	BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@WorkingShiftXml

	INSERT INTO #tmpWorkingShift (
		EmployeeID
		,ShiftCode
		,ShiftDate
		,IsOffDay
		,IsHoliday
		,ModifiedDate
		)
	SELECT EmployeeID
		,ShiftCode
		,ShiftDate
		,IsOffDay
		,IsPublicHoliday
		,ModifiedDate
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (EmployeeID VARCHAR(20), ShiftCode VARCHAR(20), ShiftDate DATE, IsOffDay BIT, IsPublicHoliday BIT, ModifiedDate DATETIME) AS Data

	EXEC sp_xml_removedocument @DocHandler

	UPDATE ec
	SET ec.ShiftId = s.ShiftID
		,ec.IsOffDay = CASE 
			WHEN tmpca.IsLeaveDay = 0
				AND tmpca.IsKeepInView = 0
				AND tmpca.ChangeShiftTypeId IS NULL THEN
					CASE
						WHEN tmpws.IsOffDay = 0 AND s.ShiftID IS NULL AND ISNULL(tmpws.ShiftCode, '') != '' THEN ec.IsOffDay
						ELSE tmpws.IsOffDay END
			ELSE ec.IsOffDay
			END
		,ec.IsHoliday = CASE 
			WHEN tmpws.IsHoliday = 1
				AND h.Id IS NOT NULL THEN 1
			ELSE 0
			END
		,ec.ModifiedBy = @ActorId
		,ec.ModifiedDate = @SyncDate
		,ec.OWPSyncDate = @SyncDate
	OUTPUT INSERTED.EmpId
		,INSERTED.WorkDate
		,INSERTED.ShiftId
		,INSERTED.IsOffDay
		,INSERTED.IsHoliday
	INTO #tmpEmployeeCalendar(EmpId, WorkDate, ShiftId, IsOffDay, IsHoliday)
	FROM dbo.EmployeeCalendar AS ec WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ec.EmpId = e.EmpId
		INNER JOIN #tmpEmployeeIds AS tmpemp WITH (NOLOCK) ON e.EmpId = tmpemp.EmpId
		INNER JOIN #tmpWorkingShift AS tmpws WITH (NOLOCK) ON e.Code = tmpws.EmployeeID
		INNER JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON ec.EmpId = tmpca.EmpId
		AND ec.WorkDate = tmpca.WorkDate
		AND CAST(ec.WorkDate AS DATE) = CAST(tmpws.ShiftDate AS DATE)
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.CompanyId = @CompanyId
        AND s.Code = tmpws.ShiftCode
		LEFT JOIN dbo.Holiday AS h WITH (NOLOCK) ON h.CompanyId = @CompanyId
        AND tmpws.ShiftDate BETWEEN h.FromDate
			AND h.ToDate
	WHERE tmpca.ChangeShiftTypeId IS NULL
		AND tmpca.IsLeaveDay = 0
		AND tmpca.IsKeepInView = 0
		AND (
			(
				s.ShiftID IS NULL
				AND (
					s.ShiftID IS NULL
				AND (
						tmpws.IsOffDay = 1
					OR (
						tmpws.IsHoliday = 1
						AND h.Id IS NOT NULL
						)
					)
					)
				)
			OR (
				s.ShiftID IS NOT NULL
				AND (
					tmpca.ShiftId IS NULL
					OR tmpca.ShiftId != s.ShiftID
					)
				)
			)

	INSERT INTO dbo.EmployeeCalendar (
		WorkDate
		,EmpId
		,ShiftId
		,IsOffDay
		,IsHoliday
		,ModifiedBy
		,ModifiedDate
		,OWPSyncDate
		)
	OUTPUT INSERTED.EmpId
		,INSERTED.WorkDate
		,INSERTED.ShiftId
		,INSERTED.IsOffDay
		,INSERTED.IsHoliday
	INTO #tmpEmployeeCalendar(EmpId, WorkDate, ShiftId, IsOffDay, IsHoliday)
	SELECT DISTINCT tmpws.ShiftDate
		,e.EmpId
		,s.ShiftID
		,CASE 
			WHEN tmpca.EmpId IS NULL
				OR (
					tmpca.EmpId IS NOT NULL
					AND tmpca.IsLeaveDay = 0
					AND tmpca.IsKeepInView = 0
					AND tmpca.ChangeShiftTypeId IS NULL
					) THEN tmpws.IsOffDay
			ELSE 0
			END
		,CASE 
			WHEN tmpws.IsHoliday = 1
				AND h.Id IS NOT NULL THEN 1
			ELSE 0
			END
		,@ActorId
		,@SyncDate
		,@SyncDate
	FROM #tmpWorkingShift AS tmpws WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.Code = tmpws.EmployeeID
		INNER JOIN #tmpEmployeeIds AS tmpemp WITH (NOLOCK) ON e.EmpId = tmpemp.EmpId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.CompanyId = @CompanyId
        AND s.Code = tmpws.ShiftCode
		LEFT JOIN dbo.Holiday AS h WITH (NOLOCK) ON h.CompanyId = @CompanyId
        AND tmpws.ShiftDate BETWEEN h.FromDate
			AND h.ToDate
		LEFT JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON e.EmpId = tmpca.EmpId
		AND CAST(tmpws.ShiftDate AS DATE) = CAST(tmpca.WorkDate AS DATE)
	WHERE (
			(
				s.ShiftID IS NULL
				AND (
					tmpws.IsOffDay = 1
					OR (
						tmpws.IsHoliday = 1
						AND h.Id IS NOT NULL
						)
					)
				)
			OR s.ShiftID IS NOT NULL
			)
		AND NOT EXISTS (
			SELECT ec.EmpId
			FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
			WHERE ec.EmpId = e.EmpId
				AND CAST(tmpws.ShiftDate AS DATE) = CAST(ec.WorkDate AS DATE)
			)

	IF EXISTS (
			SELECT 1
			FROM #tmpEmployeeCalendar WITH (NOLOCK)
			)
	BEGIN
		EXEC dbo.ScheduleArrangement_UpdateOffDayReplacement @CompanyId = @CompanyId
            ,@ActorId = @ActorId
			,@EmployeeIds = @EmployeeIds
			,@FromDate = @FromDate
			,@ToDate = @ToDate
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT

		DECLARE @xml NVARCHAR(MAX)

		SET @xml = CAST((
					SELECT EmpId AS '@EmpId'
						,WorkDate AS '@WorkDate'
						,ShiftId AS '@ShiftId'
						,IsOffDay AS '@IsOffDay'
						,IsHoliday AS '@IsHoliday'
					FROM #tmpEmployeeCalendar WITH (NOLOCK)
					FOR XML PATH('Row')
						,ROOT('Root')
					) AS NVARCHAR(MAX))

		EXEC dbo.Log_WriteLog @LogActionId = 1004
			,@LogDate = @SyncDate
			,@Description = 'Sync working shift from OWP'
			,@TrackingValue = @xml
			,@UserId = @ActorId
	END

	DELETE
	FROM #tmpEmployeeCalendar WITH (ROWLOCK, UPDLOCK)
	WHERE WorkDate > @Today

	WHILE EXISTS (
			SELECT 1
			FROM #tmpEmployeeCalendar WITH (NOLOCK)
			)
	BEGIN
		SELECT TOP 1 @EmpId = EmpId
			,@WorkDate = WorkDate
		FROM #tmpEmployeeCalendar WITH (NOLOCK)

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
			,@WorkDate
			,@WorkDate
			,1

		DELETE
		FROM #tmpEmployeeCalendar WITH (ROWLOCK, UPDLOCK)
		WHERE EmpId = @EmpId
			AND WorkDate = @WorkDate
	END
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = ERROR_MESSAGE()
	END CATCH

	DROP TABLE #tmpEmployeeIds

	DROP TABLE #tmpWorkingShift

	DROP TABLE #tmpEmployeeCalendar
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeAttendance_GetByType] @fromtime DATE
	,@totime DATE
	,@EmpId INT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@excludeUserDelete INT = 1
	,@isLocal BIT = NULL
	,@SupervisorId INT = NULL
	,@type SMALLINT
	,@isRealDate BIT = 0
	,@companyId INT
AS
/*
Created: Tom.Vo@2013-10-31
Task: get attentance list of employees by type
DB: HRM_SMS
Original:

Revisions:
	- Merlin.Le@20200713: Get section and department - Redmine Id: 110683
	- 20250408@Hank: remove section [Redmine: #222886]

Param's Explanation:
	@type: 0-all, 1-missing checkin; 2-missing check out, 3: latein; 4-earlyout, 5- not work
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @today DATETIME
		,@now DATETIME
		,@StartDate DATETIME
		,@EndDate DATETIME
		,@employeeIds VARCHAR(MAX)
		-- request type
		,@LateInRequestTypeId TINYINT = 3
		,@EarlyOutRequestTypeId TINYINT = 4
		,@ChangeShiftRequestTypeId TINYINT = 5
		,@LeaveRequestTypeId TINYINT = 6
		,@KeepInViewRequestTypeId TINYINT = 7
		-- request status
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7
	CREATE TABLE #tmpGroup (GroupId INT PRIMARY KEY)

	CREATE TABLE #tmpEmployee (EmpId INT PRIMARY KEY)

	IF (@isRealDate = 1)
	BEGIN
		SET @fromtime = DATEADD(d, - 1, @fromtime)
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpGroup (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END
	ELSE
	BEGIN
		INSERT INTO #tmpGroup (GroupId)
		SELECT GroupId
		FROM dbo.[Group] WITH (NOLOCK)
		WHERE ISNULL(IsDeleted, 0) = 0
	END

	IF @EmpId IS NULL
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		SELECT DISTINCT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, @excludeUserDelete, 1, @companyId)
	END
	ELSE
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		VALUES (@EmpId)
	END

	SET @now = dateadd(hh, 7, GETUTCDATE())
	SET @today = convert(VARCHAR(10), @now, 111) -- use UTC because the server use GMT-4

	CREATE TABLE #tmpDailyRequest (
		RequestId BIGINT
		,EmpId INT
		,WorkDate DATE
		,RequestType INT
		,InOutMins INT
		,RequestDate DATETIME
		,FromDate DATETIME
		,ToDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 2)
		,CurrentStatus TINYINT
		,KeepInViewTypeId TINYINT
		,Remark NVARCHAR(2000)
		,CreatedDate DATETIME
		,LeaveTypeId INT
		)

	SELECT @employeeIds = COALESCE(@employeeIds + ',', '') + CAST(EmpId AS VARCHAR(20))
	FROM #tmpEmployee WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @companyId
		,@fromDate = @fromtime
		,@toDate = @totime
		,@empIds = @employeeIds

	-- check in/out
	INSERT INTO #tmpDailyRequest (
		RequestDate
		,RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,CurrentStatus
		,Remark
		,CreatedDate
		)
	SELECT cio.RequestTime
		,r.RequestId
		,r.EmpId
		,r.RequestType
		,cio.OnDate
		,cio.OnDate
		,0
		,r.CurrentStatus
		,r.Remark
		,r.CreatedDate
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequest AS cio WITH (NOLOCK) ON r.RequestId = cio.RequestId
		AND cio.OnDate BETWEEN @fromtime
			AND @totime
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)

	-- late in/early out
	INSERT INTO #tmpDailyRequest (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,CurrentStatus
		,Remark
		,CreatedDate
		)
	SELECT r.RequestId
		,r.EmpId
		,r.RequestType
		,lieo.OnDate
		,lieo.OnDate
		,0
		,(CASE 
			WHEN r.RequestType = @LateInRequestTypeId THEN lieo.LateInMins
			ELSE lieo.EarlyOutMins END
			)
		,r.CurrentStatus
		,r.Remark
		,r.CreatedDate
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK) ON r.RequestId = lieo.RequestId
		AND lieo.OnDate BETWEEN @fromtime
			AND @totime
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)

	-- keep in view
	INSERT INTO #tmpDailyRequest (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,CurrentStatus
		,KeepInViewTypeId
		,Remark
		,CreatedDate
		)
	SELECT r.RequestId
		,r.EmpId
		,r.RequestType
		,kiv.OnDate
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,(CASE 
			WHEN kiv.IsHalfDay = 1 THEN 0.5
			ELSE 1 END
			)
		,r.CurrentStatus
		,kiv.KeepInViewType
		,r.Remark
		,r.CreatedDate
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
		AND kiv.OnDate BETWEEN @fromtime
			AND @totime
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)

	-- Leave request
	INSERT INTO #tmpDailyRequest (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,CurrentStatus
		,Remark
		,CreatedDate
		,LeaveTypeId
		)
	SELECT DISTINCT r.RequestId
		,r.EmpId
		,r.RequestType
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,CurrentStatus
		,r.Remark
		,r.CreatedDate
		,lr.LeaveType
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE (
			(
				lr.FromDate BETWEEN @fromtime
					AND @totime
				AND lr.ToDate >= @totime
				)
			OR (
				lr.FromDate <= @fromtime
				AND lr.ToDate >= @totime
				)
			OR lr.ToDate BETWEEN @fromtime
				AND @totime
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			WHERE lr.RequestId = ldt.RequestId
			)

	-- Leave request
	INSERT INTO #tmpDailyRequest (
		RequestId
		,EmpId
		,WorkDate
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromTime
		,ToTime
		,CurrentStatus
		,Remark
		,CreatedDate
		,LeaveTypeId
		)
	SELECT DISTINCT r.RequestId
		,r.EmpId
		,ldt.OnDate
		,r.RequestType
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,CASE WHEN ldt.IsHalfDay = 1 THEN ldt.FromTime ELSE NULL END
		,CASE WHEN ldt.IsHalfDay = 1 THEN ldt.ToTime ELSE NULL END
		,r.CurrentStatus
		,r.Remark
		,r.CreatedDate
		, ldt.LeaveType
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN [dbo].LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		INNER JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
		AND ldt.WorkType IN (1, 2) -- off, leave
	WHERE (
			(
				datediff(d, @fromtime, lr.FromDate) <= 0
				AND datediff(d, @totime, lr.ToDate) >= 0
				)
			OR (
				datediff(d, @fromtime, lr.FromDate) >= 0
				AND datediff(d, @totime, lr.FromDate) <= 0
				)
			OR (
				datediff(d, @fromtime, lr.ToDate) >= 0
				AND datediff(d, @totime, lr.ToDate) <= 0
				)
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)

	-- change shift
	INSERT INTO #tmpDailyRequest (
		RequestId
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		,CurrentStatus
		,Remark
		,CreatedDate
		)
	SELECT r.RequestId
		,r.EmpId
		,r.RequestType
		,cs.FromDate
		,cs.ToDate
		,COUNT(1) TotalDays
		,MAX(csd.FromShift) FromShift
		,MAX(csd.ToShift) ToShift
		,r.CurrentStatus
		,r.Remark
		,r.CreatedDate
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		INNER JOIN dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK) ON csd.RequestId = cs.RequestId
	WHERE (
			(
				cs.FromDate BETWEEN @fromtime
					AND @totime
				AND cs.ToDate >= @totime
				)
			OR (
				cs.FromDate <= @fromtime
				AND cs.ToDate >= @totime
				)
			OR cs.ToDate BETWEEN @fromtime
				AND @totime
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS emp WITH (NOLOCK)
			WHERE r.EmpId = emp.EmpId
			)
	GROUP BY r.CreatedDate
		,r.RequestId
		,r.EmpId
		,r.RequestType
		,cs.FromDate
		,cs.ToDate
		,r.CurrentStatus
		,r.Remark

	IF (@isRealDate = 1)
	BEGIN
		SET @fromtime = DATEADD(d, 1, @fromtime)
	END

	SET @StartDate = @fromtime
	SET @EndDate = @totime

	WHILE DATEPART(dw, @StartDate) <> 2
	BEGIN
		SET @StartDate = DATEADD(d, - 1, @StartDate)
	END

	WHILE DATEPART(dw, @EndDate) <> 1
	BEGIN
		SET @EndDate = DATEADD(d, 1, @EndDate)
	END

	DECLARE @OutOffDay TABLE (
		WorkDate DATETIME
		,EmpId INT
		)
	DECLARE @StartDate_tmp DATETIME
		,@EndDate_tmp DATETIME

	WHILE @StartDate <= @EndDate
	BEGIN
		SET @StartDate_tmp = @StartDate
		SET @EndDate_tmp = DATEADD(d, 6, @StartDate)
		SET @StartDate = DATEADD(d, 7, @StartDate)

		INSERT INTO @OutOffDay (
			WorkDate
			,EmpId
			)
		SELECT WorkDate
			,cl.EmpId
		FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
			INNER JOIN (
			SELECT c.EmpId
			FROM dbo.EmployeeCalendar AS c WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON c.EmpId = es.EmpId
			WHERE WorkDate BETWEEN @StartDate_tmp
					AND @EndDate_tmp
				AND c.IsOffDay = 1
				AND (
					@EmpId IS NULL
					OR c.EmpId = @EmpId
					)
			GROUP BY c.EmpId
				,es.OffDaysbyWeek
			HAVING COUNT(c.EmpId) > es.OffDaysbyWeek
			) AS a ON cl.EmpId = a.EmpId
		WHERE WorkDate BETWEEN @StartDate_tmp
				AND @EndDate_tmp
			AND cl.IsOffDay = 1
			AND (
				@EmpId IS NULL
				OR cl.EmpId = @EmpId
				)
	END

	SELECT T.Code
		,T.EmpId
		,T.FullName
		,T.NickName
		,T.[Team]
		,T.[TeamCode]
		,T.[Rank]
		,T.AttendanceDate
		,T.ShiftId
		,COALESCE(T.ShiftCode, CASE 
				WHEN ISNULL(T.IsHoliday, 0) = 0
					AND (T.ShiftId IS NULL OR T.ShiftId = -1)
					AND isOffday = 1 THEN 'Off day'
				WHEN ISNULL(T.IsHoliday, 0) = 1
					AND (
						T.InFixed IS NULL
						AND T.OutFixed IS NULL
						) THEN 'PH'
				ELSE ''
				END, '') ShiftCode
		,T.ExpectedInTime
		,T.ExpectedOutTime
		,CASE 
			WHEN T.IsShiftCrossDay = 1
				AND ISNULL(T.IsHoliday, 0) = 0
				AND T.ShiftId IS NULL
				AND isOffday = 1 THEN NULL
			ELSE T.InFixed
			END InFixed
		,CASE 
			WHEN T.IsShiftCrossDay = 1
				AND ISNULL(T.IsHoliday, 0) = 0
				AND T.ShiftId IS NULL
				AND isOffday = 1 THEN NULL
			ELSE T.OutFixed
			END OutFixed
		,T.LateIn
		,T.EarlyOut
		,CASE 
			WHEN T.IsShiftCrossDay = 1
				AND ISNULL(T.IsHoliday, 0) = 0
				AND T.ShiftId IS NULL
				AND isOffday = 1 THEN NULL
			ELSE T.TotalWorkHours
			END TotalWorkHours
		,T.Absence
		,T.isNotWork
		,T.isOffday
		,T.IsHoliday AS IsPublicHoliday
		,(CASE 
			WHEN (
					(
						od.EmpId IS NOT NULL
						OR (
							AttendanceDate1 IS NOT NULL
							AND isMissingCheckin = 1
							)
						OR (
							AttendanceDate1 IS NOT NULL
							AND isMissingCheckOut = 1
							)
						)
					AND CONVERT(NVARCHAR(20), T.AttendanceDate1, 111) < CONVERT(NVARCHAR(20), GETDATE(), 111)
					) THEN 1
			ELSE 0 END
			) AS IsWarning
		,T.IsOvertime
		,T.OvertimeHours
		,T.OvertimeStatus
		,ISNULL(stuff((CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND (
							isLateIn = 1
							AND LateIn > 0
							) THEN (', Late In')
					ELSE '' END
					) + (CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND (
							isEarlyOut = 1
							AND EarlyOut > 0
							) THEN ', Early Out'
					ELSE '' END
					) + (CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND isMissingCheckin = 1 THEN ', Missing Check-in'
					ELSE '' END
					) + (CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND isMissingCheckOut = 1
						AND CONVERT(NVARCHAR(20), T.AttendanceDate1, 111) < CONVERT(NVARCHAR(20), GETDATE(), 111) THEN ', Missing Check-out'
					ELSE '' END
					) + (CASE 
					WHEN AttendanceDate1 IS NOT NULL
						AND IsKeepInView = 1 THEN ', CL day' + CASE 
							WHEN LeaveDay = 0.5 THEN ' (Half day)'
							ELSE ''
							END
					ELSE '' END
					) + (CASE 
					WHEN ISNULL(T.IsHoliday, 0) = 0
						AND isOffday = 1
						AND (ShiftId IS NULL OR ShiftId = -1) THEN (CASE 
							WHEN od.EmpId IS NULL THEN ', Off day'
							ELSE ', Off day no match' END
							)
					ELSE '' END
					) + (CASE 
					WHEN ISNULL(T.IsHoliday, 0) = 0
						AND isOffday = 1
						AND ShiftId IS NOT NULL
						AND ShiftId != -1
						AND od.EmpId IS NOT NULL THEN ', Off day no match'
					ELSE '' END
					) + (CASE 
					WHEN ISNULL(T.IsHoliday, 0) = 1
						AND ShiftId IS NULL THEN ', PH'
					ELSE '' END
					) + (CASE 
					WHEN isNotWork = 1
						AND T.LeaveTypeId IS NULL THEN ', Absent'
					ELSE (
							(CASE 
								WHEN lv.[Name] IS NULL THEN ''
								ELSE ', ' + lv.[Name] + (CASE 
										WHEN lv2.[Name] IS NULL THEN ''
										ELSE ' & ' + lv2.[Name] END
										) + (CASE 
										WHEN LeaveDay = 0.5 THEN ' (Half day)'
										ELSE '' END
										) END
								) + CASE 
							WHEN LeaveDay = 0.5
								AND isNotWork = 1 THEN ', Absent'
							ELSE '' END
							) END
					), 1, 2, ''), CASE 
				WHEN AttendanceDate1 IS NULL THEN 'No Data'
				ELSE NULL
				END) AS Notes
		,T.DepartmentCode
	FROM (
		SELECT e.Code
			,e.EmpId
			,FullName
			,NickName
			,g.[Name] [Team]
			,g.Code [TeamCode]
			,g.[Rank]
			,c.WorkDate AS AttendanceDate
			,a.AttendanceDate AS AttendanceDate1
			,c.ShiftId
			,s.code AS ShiftCode
			,s.BeginCheckInTime AS ExpectedInTime
			,s.BeginCheckOutTime AS ExpectedOutTime
			,a.InFixed
			,a.OutFixed
			,a.LateIn
			,a.EarlyOut
			,TotalWorkHours
			,c.IsKeepInView
			,c.LeaveDay
			,ISNULL(a.LeaveTypeId, c.LeaveTypeId) AS LeaveTypeId
			,ISNULL(a.LeaveTypeId2, c.LeaveTypeId2) AS LeaveTypeId2
			,Absence
			,(CASE 
				WHEN isnull(a.Absence, 0) = 0
					AND isnull(a.LateIn, 0) > 0 THEN 1
				ELSE 0 END
				) AS isLateIn
			,(CASE 
				WHEN isnull(a.Absence, 0) = 0
					AND isnull(a.EarlyOut, 0) > 15 THEN 1
				ELSE 0 END
				) AS isEarlyOut
			,(CASE 
				WHEN (
						isnull(a.Absence, 0) = 0
						AND a.InFixed IS NULL
						AND @now > (
							(CASE 
								WHEN s.IsInAfterDay = 1 THEN DATEADD(DD, 1, a.AttendanceDate)
								ELSE a.AttendanceDate END
								) + ' ' + s.EndCheckInTime
							)
						) THEN 1
				ELSE 0 END
				) AS isMissingCheckin
			,(CASE 
				WHEN (
						isnull(a.Absence, 0) = 0
						AND a.OutFixed IS NULL
						AND @now > (
							(CASE 
								WHEN s.IsOutAfterDay = 1 THEN DATEADD(DD, 1, a.AttendanceDate)
								ELSE a.AttendanceDate END
								) + ' ' + s.EndCheckOutTime
							)
						) THEN 1
				ELSE 0 END
				) AS isMissingCheckOut
			,(CASE 
				WHEN (
						a.ShiftId IS NOT NULL
						AND a.InFixed IS NULL
						AND a.OutFixed IS NULL
						AND a.TotalWorkHours IS NULL
						AND @now > (
							(CASE 
								WHEN s.IsInAfterDay = 1 THEN DATEADD(DD, 1, a.AttendanceDate)
								ELSE a.AttendanceDate END
								) + ' ' + s.EndCheckInTime
							)
						) THEN 1
				ELSE 0 END
				) AS isNotWork
			,c.isOffday
			,CONVERT(BIT, CASE 
					WHEN ot.EmpId IS NULL THEN 0
					ELSE 1
					END) IsOvertime
			,(ISNULL(ot.NormalHours, 0) + ISNULL(ot.OffHours, 0) + ISNULL(ot.PublicHours, 0) + ISNULL(ot.SpecialHours, 0)) OvertimeHours
			,ot.[Status] AS OvertimeStatus
			,c.IsHoliday
			,(CASE 
				WHEN ISNULL(s_CrossDay.IsOutAfterDay, 0) = 1 THEN 1
				ELSE 0 END
				) AS IsShiftCrossDay
			,de.Code AS DepartmentCode
		FROM dbo.Employee AS e WITH (NOLOCK)
			INNER JOIN dbo.tmpEmployeeCalendar AS c WITH (NOLOCK) ON c.EmpId = e.EmpId
			AND c.WorkDate BETWEEN @fromtime
				AND @totime
			INNER JOIN #tmpEmployee AS tblemp ON e.EmpId = tblemp.EmpId
			LEFT JOIN dbo.EmployeeSummary AS e_s WITH (NOLOCK) ON e_s.EmpId = e.EmpId
			LEFT JOIN dbo.EmployeeCalendar AS c_CrossDay WITH (NOLOCK) ON c_CrossDay.WorkDate = DATEADD(D, - 1, c.WorkDate)
			AND c_CrossDay.EmpId = e.EmpId
			LEFT JOIN dbo.[Shift] AS s_CrossDay WITH (NOLOCK) ON s_CrossDay.ShiftId = c_CrossDay.ShiftId
			LEFT JOIN dbo.EmployeeCalendar AS c_CurDay WITH (NOLOCK) ON c_CurDay.WorkDate = DATEADD(D, - 1, c.WorkDate)
			AND c_CurDay.EmpId = e.EmpId
			LEFT JOIN dbo.[Shift] AS s_CurDay WITH (NOLOCK) ON s_CurDay.ShiftId = c_CurDay.ShiftId
			AND (
				(
					s_CrossDay.IsInAfterDay = 0
					OR @isRealDate = 0
					)
				OR (
					(
						s_CrossDay.IsInAfterDay = 1
						OR s_CurDay.IsInAfterDay = 1
						)
					AND @isRealDate = 1
					AND c.WorkDate = c_CrossDay.WorkDate
					)
				)
			LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = c.ShiftId
			LEFT JOIN dbo.EmployeeAttendance AS a WITH (NOLOCK) ON a.AttendanceDate = c.WorkDate
			AND a.empid = e.empid
			LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.groupid = g.groupid
			INNER JOIN dbo.[Department] AS de WITH (NOLOCK) ON de.DepartmentId = g.DepartmentId
			INNER JOIN #tmpGroup AS tmpgr ON g.GroupId = tmpgr.GroupId
			LEFT JOIN dbo.OTDailyRequest AS ot WITH (NOLOCK) ON a.attendancedate = ot.OvertimeDate
			AND a.EmpId = ot.EmpId
		WHERE @isLocal IS NULL
			OR e_s.IsLocal = @isLocal
		) AS T
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeId = T.LeaveTypeId AND lv.CompanyId = @companyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON lv2.LeaveTypeId = T.LeaveTypeId2 AND lv.CompanyId = @companyId
		LEFT JOIN @OutOffDay AS od ON t.AttendanceDate = od.WorkDate
		AND t.EmpId = od.EmpId
	WHERE @type = 0
		OR (
			@type = 1
			AND ISNULL(T.isMissingCheckin, 1) = 1
			)
		OR (
			@type = 2
			AND T.isMissingCheckout = 1
			)
		OR (
			@type = 3
			AND T.isLateIn = 1
			)
		OR (
			@type = 4
			AND T.isEarlyOut = 1
			)
		OR (
			@type = 5
			AND T.isNotWork = 1
			)
	ORDER BY attendancedate DESC
		,[Rank]
		,TeamCode
		,T.code

	SELECT c.WorkDate
		,rd.EmpId
		,rd.RequestDate
		,rd.FromDate
		,rd.ToDate
		,rd.FromTime
		,rd.ToTime
		,rd.TotalDays
		,rd.CurrentStatus
		,rd.KeepInViewTypeId
		,rd.Remark
		,rd.CreatedDate
		,(CASE 
			WHEN rd.RequestType = 5
				OR rd.RequestType = 7 THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShift
		,(CASE 
			WHEN s2.ShiftID IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShift
		,rd.InOutMins AS TotalMins
		,rd.RequestType
		,rd.LeaveTypeId
		,l.[Name] AS LeaveTypeName
	FROM #tmpDailyRequest AS rd WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS c WITH (NOLOCK) ON (
			(
				rd.WorkDate IS NOT NULL AND rd.WorkDate = c.WorkDate) 
				OR (rd.WorkDate IS NULL AND c.WorkDate BETWEEN CAST(rd.FromDate AS DATE) AND CAST(rd.ToDate AS DATE))
			)
		AND c.EmpId = rd.EmpId
		AND (
			(
				rd.RequestType = @LeaveRequestTypeId
				--AND rd.RequestId = c.RequestId
				AND c.IsHoliday = 0
				AND c.IsOffDay = 0
				--AND c.IsKeepInView = 0
				)
			OR rd.RequestType <> @LeaveRequestTypeId
			)
		LEFT JOIN dbo.LeaveType AS l WITH (NOLOCK) ON l.LeaveTypeId = rd.LeaveTypeId AND l.CompanyId = @companyId
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftId = rd.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftId = rd.ToShift
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftId = c.ShiftId

	DROP TABLE #tmpGroup

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpDailyRequest
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TimeRecord_InsertCheckInOutTime]
(
    @EmpId INT
	,@RecordTime DATETIME
    ,@ClientRecordTime DATETIME
	,@InOutType TINYINT
	,@Platform VARCHAR(255)
	,@IPAddress VARCHAR(50)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20210527@Quinn.Vo
    Task: Insert Check In/Out Time.
    DB: bodb_HRM

    Revisions:
        20250408@Tim: fix bug failed to retrieve the Attendance Report data [Redmine: #222721]
    Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FromDate DATETIME
        ,@ToDate DATETIME
        ,@TimeRecoredId INT

	INSERT INTO [dbo].[TimeRecord] (
		EmpId
		,RecordTime
		,InOutType
		,InsertDate
		)
	VALUES (
		@EmpId
		,@RecordTime
		,CASE WHEN @InOutType = 0 THEN 0 ELSE 1 END
		,GETDATE()
		)

	SELECT @TimeRecoredId = CAST(SCOPE_IDENTITY() AS INT)

	INSERT INTO dbo.TimeRecordExt(ID, IPAddress, [Platform])
	VALUES (@TimeRecoredId, @IPAddress, @Platform)

	SET @FromDate = CONVERT(VARCHAR(10), DATEADD(d, - 2, @ClientRecordTime), 111)
	SET @ToDate = CONVERT(VARCHAR(10), @ClientRecordTime, 111)

	EXEC EmployeeAttendance_ProcessingAndInsert @EmpId = @EmpId
		,@fromTime = @FromDate
		,@toTime = @ToDate
		,@onlyUpdate = 0
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkFromHome_MealAllowanceDetailReport]
(
    @CompanyId SMALLINT
    ,@FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@IsLocal BIT = NULL
)
AS
/*
    Created: 20211109@Quinn.Vo
    Task: Get meal allowance report
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tmpToDate DATETIME = DATEADD(SECOND, -1, DATEADD(DAY, 2, CONVERT(DATETIME, @ToDate)))
        ,@serverTimeZone SMALLINT = -4
        ,@clientTimeZone REAL

    SELECT @clientTimeZone = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'TimeZone'

    SET @clientTimeZone = ISNULL(@clientTimeZone, @serverTimeZone)

	CREATE TABLE #tmpEmployee (EmpId INT)

	CREATE TABLE #tmpTeam (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	INSERT INTO #tmpEmployee (EmpId)
	SELECT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE ce.CompanyId = @CompanyId
        AND (
			@EmployeeId IS NULL
			OR e.EmpId = @EmployeeId
			)
		AND (
			ISNULL(@TeamIds, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tmpTeam AS tbl WITH (NOLOCK)
				WHERE e.GroupId = tbl.GroupId
				)
			)
		AND (
			@IsLocal IS NULL
			OR es.IsLocal = @IsLocal
			)

	CREATE TABLE #tmpInOut (
		EmpId INT
		,RecordTime DATETIME
		)

	CREATE CLUSTERED INDEX ix_tmpInOut ON #tmpInOut (
		EmpId
		,RecordTime
		)

	INSERT INTO #tmpInOut (
		EmpId
		,RecordTime
		)
	SELECT tr.EmpId
		,RecordTime
	FROM dbo.TimeRecord AS tr WITH (NOLOCK)
		INNER JOIN dbo.TimeRecordExt AS te WITH (NOLOCK) ON tr.ID = te.ID
		INNER JOIN #tmpEmployee AS tmpemp WITH (NOLOCK) ON tr.EmpId = tmpemp.EmpId
	WHERE DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), tr.RecordTime)) BETWEEN DATEADD(DAY, - 1, @FromDate)
			AND @tmpToDate

	CREATE TABLE #tmpEmpAttandance (
		EmpId INT
		,WorkDate DATE
		,ShiftId INT
		,InFixed DATETIME
		,OutFixed DATETIME
		,TotalWorkHours DECIMAL(18, 2)
		,TotalDays DECIMAL(18, 2)
		)

	INSERT INTO #tmpEmpAttandance (
		EmpId
		,WorkDate
		,ShiftId
		,InFixed
		,OutFixed
		,TotalWorkHours
		,TotalDays
		)
	SELECT att.EmpId
		,att.AttendanceDate AS WorkDate
		,att.ShiftId
		,att.InFixed
		,att.OutFixed
		,att.TotalWorkHours
		,CASE 
			WHEN DATEDIFF(HOUR, att.ExpectedInTime, att.ExpectedOutTime) >= 9 THEN CASE 
					WHEN ISNULL(att.TotalWorkHours, 0) >= 8 THEN 1
					ELSE CASE 
							WHEN ISNULL(att.TotalWorkHours, 0) >= 3.5 THEN 0.5
							ELSE 0
							END
					END
			ELSE CASE 
					WHEN ISNULL(att.TotalWorkHours, 0) >= 7 THEN 1
					ELSE CASE 
							WHEN ISNULL(att.TotalWorkHours, 0) >= 3.5 THEN 0.5
							ELSE 0
							END
					END
			END AS TotalDays
	FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
		INNER JOIN #tmpEmployee AS e WITH (NOLOCK) ON att.EmpId = e.EmpId
		INNER JOIN dbo.tmpEmployeeCalendar AS tcl WITH (NOLOCK) ON att.EmpId = tcl.EmpId
		AND att.AttendanceDate = tcl.WorkDate
	WHERE ISNULL(att.TotalWorkHours, 0) > 3
		AND tcl.LeaveDay <> 1
		AND att.AttendanceDate BETWEEN @FromDate
			AND @ToDate
		AND EXISTS (
			SELECT 1
			FROM #tmpInOut AS tblinout WITH (NOLOCK)
			WHERE att.EmpId = tblinout.EmpId
				AND (
					att.InFixed = tblinout.RecordTime
					OR att.OutFixed = tblinout.RecordTime
					)
			)

	SELECT a.WorkDate
		,a.ShiftId
		,s.Code AS ShiftCode
		,a.InFixed
		,a.OutFixed
		,a.TotalWorkHours
		,a.TotalDays
		,e.EmpId
		,e.Code
		,e.FullName
		,e.NickName
		,g.GroupId AS TeamId
        ,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dep.Code AS DepartmentCode
		,dep.[Name] AS DepartmentName
	FROM #tmpEmpAttandance AS a WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON a.EmpId = e.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = a.ShiftId
        AND s.CompanyId = @CompanyId
	ORDER BY dep.Code
		,dep.[Name]
		,g.[Name]
		,e.Code
		,a.WorkDate

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpTeam

	DROP TABLE #tmpEmpAttandance

	DROP TABLE #tmpInOut
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkFromHome_MealAllowanceSummaryReport]
(
    @CompanyId SMALLINT
    ,@FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@IsLocal BIT = NULL
)
AS
/*
    Created: 20211109@Quinn.Vo
    Task: Get meal allowance report
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tmpToDate DATETIME = DATEADD(SECOND, -1, DATEADD(DAY, 2, CONVERT(DATETIME, @ToDate)))
        ,@serverTimeZone SMALLINT = -4
        ,@clientTimeZone REAL

    SELECT @clientTimeZone = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'TimeZone'

    SET @clientTimeZone = ISNULL(@clientTimeZone, @serverTimeZone)

	CREATE TABLE #tmpEmployee (EmpId INT)

	CREATE TABLE #tmpTeam (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	INSERT INTO #tmpEmployee (EmpId)
	SELECT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
        INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
        AND es.IsTopManager = 0
	WHERE ce.CompanyId = @CompanyId
        AND (
			@EmployeeId IS NULL
			OR e.EmpId = @EmployeeId
			)
		AND (
			ISNULL(@TeamIds, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tmpTeam AS tbl WITH (NOLOCK)
				WHERE e.GroupId = tbl.GroupId
				)
			)
		AND (
			@IsLocal IS NULL
			OR es.IsLocal = @IsLocal
			)

	CREATE TABLE #tmpInOut (
		EmpId INT
		,RecordTime DATETIME
		)

	CREATE CLUSTERED INDEX ix_tmpInOut ON #tmpInOut (
		EmpId
		,RecordTime
		)

	INSERT INTO #tmpInOut (
		EmpId
		,RecordTime
		)
	SELECT tr.EmpId
		,RecordTime
	FROM dbo.TimeRecord AS tr WITH (NOLOCK)
		INNER JOIN dbo.TimeRecordExt AS te WITH (NOLOCK) ON tr.ID = te.ID
		INNER JOIN #tmpEmployee AS tmpemp WITH (NOLOCK) ON tr.EmpId = tmpemp.EmpId
	WHERE DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), tr.RecordTime)) BETWEEN DATEADD(DAY, - 1, @FromDate)
			AND @tmpToDate

	CREATE TABLE #tmpEmpAttandance (
		EmpId INT
		,TotalDays DECIMAL(18, 2)
		)

	INSERT INTO #tmpEmpAttandance (
		EmpId
		,TotalDays
		)
	SELECT att.EmpId
		,CASE 
			WHEN DATEDIFF(HOUR, att.ExpectedInTime, att.ExpectedOutTime) >= 9 THEN CASE 
					WHEN ISNULL(att.TotalWorkHours, 0) >= 8 THEN 1
					ELSE CASE 
							WHEN ISNULL(att.TotalWorkHours, 0) >= 3.5 THEN 0.5
							ELSE 0
							END
					END
			ELSE CASE 
					WHEN ISNULL(att.TotalWorkHours, 0) >= 7 THEN 1
					ELSE CASE 
							WHEN ISNULL(att.TotalWorkHours, 0) >= 3.5 THEN 0.5
							ELSE 0
							END
					END
			END AS TotalDays
	FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
		INNER JOIN #tmpEmployee AS e WITH (NOLOCK) ON att.EmpId = e.EmpId
		INNER JOIN dbo.tmpEmployeeCalendar AS tcl WITH (NOLOCK) ON att.EmpId = tcl.EmpId
		AND att.AttendanceDate = tcl.WorkDate
	WHERE ISNULL(att.TotalWorkHours, 0) > 3
		AND tcl.LeaveDay <> 1
		AND att.AttendanceDate BETWEEN @FromDate
			AND @ToDate
		AND EXISTS (
			SELECT 1
			FROM #tmpInOut AS tblinout WITH (NOLOCK)
			WHERE att.EmpId = tblinout.EmpId
				AND (
					att.InFixed = tblinout.RecordTime
					OR att.OutFixed = tblinout.RecordTime
					)
			)

	SELECT att.TotalDays
		,att.EmpId
		,e.Code
		,e.FullName
		,e.NickName
		,g.GroupId AS TeamId
        ,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dep.Code AS DepartmentCode
		,dep.[Name] AS DepartmentName
	FROM (
		SELECT EmpId
			,SUM(TotalDays) AS TotalDays
		FROM #tmpEmpAttandance WITH (NOLOCK)
		GROUP BY EmpId
		) AS att
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON att.EmpId = e.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
	ORDER BY dep.[Name]
		,g.[Name]
		,e.Code

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpTeam

	DROP TABLE #tmpEmpAttandance

	DROP TABLE #tmpInOut
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_ManpowerCategory]
(
    @CompanyId SMALLINT
    ,@Year INT
)
AS
/*
    Created: 20151103@Quinn.Vo
    Task: Get data for manpower category report.
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FromDate DATETIME
		,@ToDate DATETIME

	SELECT @FromDate = CAST(@Year AS VARCHAR(4)) + '/01/01'
		,@ToDate = CAST(@Year AS VARCHAR(4)) + '/12/31'

	SELECT g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dept.Code AS DepartmentCode
		,dept.[Name] AS DepartmentName
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Total
		,SUM(CASE 
				WHEN es.IsLocal = 0
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS TotalExpat
		,SUM(CASE 
				WHEN es.IsLocal = 1
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS TotalLocal
		,SUM(CASE 
				WHEN job.Value = '5'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Management
		,SUM(CASE 
				WHEN job.Value = '4'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS ExecutiveWithPosition
		,SUM(CASE 
				WHEN job.Value = '3'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Executive
		,SUM(CASE 
				WHEN job.Value = '2'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Staff
		,SUM(CASE 
				WHEN job.Value = '1'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Worker
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
        INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.LookupData AS job WITH (NOLOCK) ON e.JobTitleId = job.Id
        AND job.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId
        AND g.IsDeleted = 0
		AND (e.ResignedDate IS NULL OR YEAR(e.ResignedDate) >= @Year)
	GROUP BY g.GroupId
		,g.Code
		,g.[Name]
		,dept.Code
		,dept.[Name]
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_Manpower]
(
    @CompanyId SMALLINT
    ,@Year INT
)
AS
/*
    Created: 20151030@Quinn.Vo
    Task: Get data for manpower report.
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Jan DATETIME
		,@Feb DATETIME
		,@Mar DATETIME
		,@Apr DATETIME
		,@May DATETIME
		,@Jun DATETIME
		,@Jul DATETIME
		,@Aug DATETIME
		,@Sep DATETIME
		,@Oct DATETIME
		,@Nov DATETIME
		,@Dec DATETIME

	SELECT @Jan = CAST(@Year AS VARCHAR(4)) + '/01/01'
		,@Feb = DATEADD(MM, 1, @Jan)
		,@Mar = DATEADD(MM, 2, @Jan)
		,@Apr = DATEADD(MM, 3, @Jan)
		,@May = DATEADD(MM, 4, @Jan)
		,@Jun = DATEADD(MM, 5, @Jan)
		,@Jul = DATEADD(MM, 6, @Jan)
		,@Aug = DATEADD(MM, 7, @Jan)
		,@Sep = DATEADD(MM, 8, @Jan)
		,@Oct = DATEADD(MM, 9, @Jan)
		,@Nov = DATEADD(MM, 10, @Jan)
		,@Dec = DATEADD(MM, 11, @Jan)

	SELECT g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dept.Code as DepartmentCode
		,dept.[Name] as DepartmentName
		,SUM(CASE 
				WHEN DATEDIFF(MM, @Jan, e.ResignedDate) >= 0
					AND DATEDIFF(MM, e.ResignedDate, @Dec) >= 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResigned
		,SUM(CASE 
				WHEN DATEDIFF(MM, @Jan, e.ResignedDate) >= 0
					AND DATEDIFF(MM, e.ResignedDate, @Dec) >= 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResigned
		,SUM(CASE 
				WHEN DATEDIFF(MM, @Jan, e.JoinedDate) >= 0
					AND DATEDIFF(MM, e.JoinedDate, @Dec) >= 0 THEN 1
				ELSE 0
				END) AS NewHire
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Dec) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUser
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jan) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedJan
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jan) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedJan
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jan) = 0 THEN 1
				ELSE 0
				END) AS NewHireJan
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jan) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserJan
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Feb) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedFeb
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Feb) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedFeb
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Feb) = 0 THEN 1
				ELSE 0
				END) AS NewHireFeb
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Feb) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserFeb
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Mar) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedMar
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Mar) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedMar
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Mar) = 0 THEN 1
				ELSE 0
				END) AS NewHireMar
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Mar) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserMar
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Apr) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedApr
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Apr) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedApr
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Apr) = 0 THEN 1
				ELSE 0
				END) AS NewHireApr
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Apr) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserApr
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @May) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedMay
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @May) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedMay
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @May) = 0 THEN 1
				ELSE 0
				END) AS NewHireMay
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @May) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserMay
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jun) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedJun
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jun) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedJun
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jun) = 0 THEN 1
				ELSE 0
				END) AS NewHireJun
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jun) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserJun
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jul) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedJul
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jul) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedJul
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jul) = 0 THEN 1
				ELSE 0
				END) AS NewHireJul
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jul) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserJul
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Aug) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedAug
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Aug) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedAug
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Aug) = 0 THEN 1
				ELSE 0
				END) AS NewHireAug
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Aug) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserAug
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Sep) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedSep
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Sep) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedSep
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Sep) = 0 THEN 1
				ELSE 0
				END) AS NewHireSep
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Sep) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserSep
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Oct) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedOct
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Oct) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedOct
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Oct) = 0 THEN 1
				ELSE 0
				END) AS NewHireOct
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Oct) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserOct
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Nov) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedNov
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Nov) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedNov
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Nov) = 0 THEN 1
				ELSE 0
				END) AS NewHireNov
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Nov) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserNov
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Dec) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedDec
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Dec) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedDec
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Dec) = 0 THEN 1
				ELSE 0
				END) AS NewHireDec
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Dec) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserDec
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
        INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
	WHERE ce.CompanyId = @CompanyId
        AND g.IsDeleted = 0
		AND (e.ResignedDate IS NULL 
			OR
			YEAR(e.ResignedDate) >= @Year) 
	GROUP BY g.GroupId
		,g.Code
		,g.[Name]
		,dept.Code
		,dept.[Name]
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_EmployeeCalendarByDateRange]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
)
AS
/*
    Created: 20250310@Tim
    Task: get employee calendar by date range.
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @employeeIds VARCHAR(MAX)
        -- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
	DECLARE @tblGroupIds TABLE (GroupId INT)
	DECLARE @tblEmployeeIds TABLE (EmpId INT)

	IF ISNULL(@TeamIds, '') <> ''
    BEGIN
		INSERT INTO @tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
        WHERE ISNUMERIC(value) = 1
    END

	INSERT INTO @tblEmployeeIds (EmpId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN (
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)
		) AS [member] ON emp.EmpId = [member].EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId AND empsum.IsTopManager = 0
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
		AND EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tblgr
			WHERE tblgr.GroupId = emp.GroupId
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)

	SELECT @employeeIds = COALESCE(@employeeIds + ',', '') + CAST(EmpId AS VARCHAR(20))
	FROM @tblEmployeeIds

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
        ,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @employeeIds

	SELECT emp.EmpId AS EmployeeId
		,emp.Code
		,emp.NickName
		,emp.FullName
        ,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dept.Code as DepartmentCode
		,dept.[Name] as DepartmentName
		,empca.WorkDate
		,empca.IsOffDay
		,empca.IsHoliday
		,empca.IsLeaveOffDay
		,empca.IsLeaveDay
		,empca.LeaveDay
		,empca.ShiftId
		,[shift].Code
		,[shift].[Name]
		,empca.LeaveTypeId
		,lv1.Code
		,lv1.[Name]
		,lv2.LeaveTypeId AS LeaveTypeId2
		,lv2.Code
		,lv2.[Name]
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN @tblEmployeeIds AS member ON emp.EmpId = member.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON emp.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		LEFT JOIN dbo.[Shift] AS [shift] WITH (NOLOCK) ON [shift].ShiftId = empca.ShiftId
        AND [shift].CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId
        AND lv1.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId
        AND lv2.CompanyId = @CompanyId
    WHERE empca.WorkDate BETWEEN @fromDate
		AND @toDate
	ORDER BY emp.NickName
		,empca.WorkDate
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_WorkingHoursSummary]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = NULL
	,@isLocal BIT = NULL
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
)
AS
/*
    Created: 20250307@Tim
    Task: Working Hours Summary Report
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
*/
BEGIN
	DECLARE @employeeIds VARCHAR(MAX)
		-- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- leave type
		,@AnnualLeaveTypeId SMALLINT = 2
		,@UnpaidLeaveTypeId SMALLINT = 25
		,@UnpaidLeaveInsuranceTypeId SMALLINT = 41
		,@PaternityLeaveTypeId SMALLINT = 14
		,@MaternityLeaveTypeId SMALLINT = 12
		,@BusinessTripTypeId SMALLINT = 9
		,@BereavementLeaveTypeId SMALLINT = 21
		,@OffsetLeaveTypeId SMALLINT = 27
		,@WeddingLeaveTypeId SMALLINT = 6
		,@SuspendWorkLeaveTypeId SMALLINT = 3
		,@HospitalizationLeaveTypeId SMALLINT = 9
		,@CompanyEventLeaveTypeId SMALLINT = 38
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6
	CREATE TABLE #tblGroupIds (GroupId INT PRIMARY KEY)
	CREATE TABLE #tblEmployeeIds (EmployeeId INT PRIMARY KEY)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
		WHERE ISNUMERIC(value) = 1
	END

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT DISTINCT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		AND empsum.IsTopManager = 0
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
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE tbl.GroupId = emp.GroupId
			)

	SELECT @employeeIds = COALESCE(@employeeIds + ',', '') + CAST(EmployeeId AS VARCHAR(20))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
        ,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @employeeIds

	SELECT emp.EmpId
		,emp.Code
		,emp.FullName
		,emp.NickName
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,dept.Code AS DepartmentCode
		,dept.[Name] AS DepartmentName
		,empsum.WorkingDays
		,empsum.WorkingHours
		,SUM(ISNULL(empatt.TotalWorkHours, 0)) AS TotalWorkingHours
		,SUM(CASE 
				WHEN empca.IsHoliday = 1
					OR empca.IsOffDay = 1
					--OR ISNULL(empatt.TotalWorkHours, 0) = 0
					OR (
						empca.IsLeaveDay = 1
						AND empca.LeaveDay = 1
						) THEN 0
				WHEN empca.IsLeaveDay = 0 THEN 1
				WHEN empca.LeaveDay < 1 THEN 0.5
				ELSE 0
				END) AS PaymentWorkingDays
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @AnnualLeaveTypeId
						OR empca.LeaveTypeId2 = @AnnualLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS AnnualLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @BusinessTripTypeId
						OR empca.LeaveTypeId2 = @BusinessTripTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS BusinessTrip
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @BereavementLeaveTypeId
						OR empca.LeaveTypeId2 = @BereavementLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS BereavementLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @OffsetLeaveTypeId
						OR empca.LeaveTypeId2 = @OffsetLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS OffsetLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @WeddingLeaveTypeId
						OR empca.LeaveTypeId2 = @WeddingLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS WeddingLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @SuspendWorkLeaveTypeId
						OR empca.LeaveTypeId2 = @SuspendWorkLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS SuspendWork
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @HospitalizationLeaveTypeId
						OR empca.LeaveTypeId2 = @HospitalizationLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS HospitalizationLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @UnpaidLeaveTypeId
						OR empca.LeaveTypeId2 = @UnpaidLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS UnpaidLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @UnpaidLeaveInsuranceTypeId
						OR empca.LeaveTypeId2 = @UnpaidLeaveInsuranceTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS UnpaidLeaveInsurance
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @PaternityLeaveTypeId
						OR empca.LeaveTypeId2 = @PaternityLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS PaternityLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @MaternityLeaveTypeId
						OR empca.LeaveTypeId2 = @MaternityLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS MaternityLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @CompanyEventLeaveTypeId
						OR empca.LeaveTypeId2 = @CompanyEventLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS CompanyEvent
		,SUM(ISNULL(ot.NormalHours, 0)) AS NormalOvertimeHours
		,SUM(ISNULL(ot.OffHours, 0)) AS OffOvertimeHours
		,SUM(ISNULL(ot.PublicHours, 0)) AS PublicOvertimeHours
		,SUM(ISNULL(ot.SpecialHours, 0)) AS SpecialOvertimeHours
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid WITH (NOLOCK) ON emp.EmpId = empid.EmployeeId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON gr.DepartmentId = dept.DepartmentId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		AND empca.WorkDate BETWEEN @FromDate
			AND @ToDate
		INNER JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON emp.EmpId = empatt.EmpId
		AND empatt.AttendanceDate = empca.WorkDate
		LEFT JOIN dbo.OTDailyRequest AS ot WITH (NOLOCK) ON ot.EmpId = emp.EmpId
		AND empca.WorkDate = ot.OvertimeDate
		AND ot.[Status] IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
	GROUP BY emp.EmpId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,empsum.WorkingDays
		,empsum.WorkingHours
        ,gr.Code
		,gr.[Name]
        ,dept.Code
		,dept.[Name]
	ORDER BY emp.NickName

	DROP TABLE #tblGroupIds
	
	DROP TABLE #tblEmployeeIds
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_DailyOvertime]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@fromDate DATE
	,@toDate DATE
	,@TeamIds VARCHAR(MAX) = NULL
	,@isLocal BIT = NULL
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
)
AS
/*
    Created: 20250307@Tim
    Task: Get daily overtime details report 
    DB: bodb_HRM
    Original:

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE
		-- employee status
		@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3

	CREATE TABLE #tmpGroupIds (GroupId INT PRIMARY KEY)
	CREATE TABLE #tmpMembers (EmpId INT PRIMARY KEY)

	INSERT INTO #tmpGroupIds (GroupId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TeamIds, ',')
	WHERE ISNUMERIC(value) = 1

	INSERT INTO #tmpMembers (EmpId)
	SELECT DISTINCT EmpId
	FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)

	SELECT emp.EmpId
		,emp.NickName
		,emp.FullName
		,emp.Code
		,gr.GroupId
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,ot.OvertimeDate AS WorkDate
		,s.ShiftId
		,s.Code AS ShiftCode
		,ot.TimeIn
		,ot.[TimeOut]
		,ot.TotalHours AS ActualWorkingHours
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.Remark
		,empca.IsHoliday
		,empca.IsOffDay
		,ot.[Status] AS StatusId
		,dept.Code AS DepartmentCode
	    ,dept.[Name] AS DepartmentName
	FROM dbo.OTDailyRequest AS ot WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = ot.EmpId
		INNER JOIN #tmpMembers AS member WITH (NOLOCK) ON emp.EmpId = member.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = emp.EmpId
        AND empsum.IsTopManager = 0
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON gr.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		AND ot.OvertimeDate = empca.WorkDate
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
        AND s.CompanyId = @CompanyId
	WHERE ot.OvertimeDate BETWEEN @fromDate
			AND @toDate
		AND (
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
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		AND (
			ISNULL(@TeamIds, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tmpGroupIds AS tbl WITH (NOLOCK)
				WHERE emp.GroupId = tbl.GroupId
				)
			)
	ORDER BY ot.OvertimeDate
		,emp.NickName

	DROP TABLE #tmpGroupIds
	DROP TABLE #tmpMembers
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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
		,e.EmployeeCard
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

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_MonthlyOvertimeDetails] @CompanyId SMALLINT
    ,@EmpId INT
	,@FromDate DATE
	,@ToDate DATE
AS
/*
Created: 20250307@Tim
Task: Get monthly overtime details.
DB: HRM

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tempDate DATE = @fromDate
	DECLARE @tblDate TABLE (WorkDate DATE)

	WHILE @tempDate <= @toDate
	BEGIN
		INSERT INTO @tblDate (WorkDate)
		VALUES (@tempDate)

		SET @tempDate = DATEADD(DAY, 1, @tempDate)
	END

	SELECT emp.EmpId
		,emp.NickName
		,emp.FullName
		,tmp.WorkDate
		,COALESCE(sc.Code, scl.Code, s.Code) AS ShiftCode
		,empatt.InFixed AS [TimeIn]
		,empatt.OutFixed [TimeOut]
		,empatt.TotalWorkHours AS ActualWorkingHours
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.[Remark]
		,empca.IsHoliday
		,empca.IsOffDay
		,ot.[Status] AS StatusId
	FROM @tblDate AS tmp
		CROSS JOIN dbo.Employee AS emp WITH (NOLOCK)
		LEFT JOIN [dbo].OTDailyRequest AS ot WITH (NOLOCK) ON tmp.WorkDate = ot.OvertimeDate
		AND ot.EmpId = emp.EmpId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
        AND s.CompanyId = @CompanyId
		LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON empatt.AttendanceDate = tmp.WorkDate
		AND empatt.EmpId = emp.EmpId
		LEFT JOIN dbo.[Shift] AS sc WITH (NOLOCK) ON sc.ShiftId = empatt.ShiftId
        AND sc.CompanyId = @CompanyId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON empca.WorkDate = tmp.WorkDate
		AND empca.EmpId = emp.EmpId
		LEFT JOIN dbo.[Shift] AS scl WITH (NOLOCK) ON scl.ShiftId = empca.ShiftId
        AND scl.CompanyId = @CompanyId
	WHERE emp.EmpId = @EmpId
	ORDER BY tmp.WorkDate
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_MonthlyOvertime] @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
AS
/*
Created: 20250307@Tim
Task: monthly overtime
DB: HRM

Revisions:
    20250403@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromDatetmp DATE = @FromDate
		-- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- request status
		,@VerifyStatusId TINYINT = 2
		,@ApproveStatusId TINYINT = 4
		,@ProcessStatusId TINYINT = 6
	DECLARE @tblEmployeeId TABLE (EmpId INT)
	DECLARE @tblDate TABLE (
		WorkDate DATE
		,IsHoliday BIT
		)
	DECLARE @tblGroupIds TABLE (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO @tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	WHILE @fromDatetmp <= @ToDate
	BEGIN
		INSERT INTO @tblDate (
			WorkDate
			,IsHoliday
			)
		VALUES (
			@fromDatetmp
			,CASE 
				WHEN EXISTS (
						SELECT 1
						FROM dbo.Holiday WITH (NOLOCK)
						WHERE CompanyId = @CompanyId
                            AND @fromDatetmp BETWEEN FromDate
								AND ToDate
						) THEN 1
				ELSE 0
				END
			)

		SET @fromDatetmp = DATEADD(DAY, 1, @fromDatetmp)
	END

	SELECT WorkDate AS [Date]
		,IsHoliday
	FROM @tblDate
	ORDER BY WorkDate

	INSERT INTO @tblEmployeeId (EmpId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
        AND empsum.IsTopManager = 0
		INNER JOIN @tblGroupIds AS tblgr ON emp.GroupId = tblgr.GroupId
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

	SELECT emp.EmpId
		,emp.Code
		,emp.NickName
		,emp.FullName
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,tmp.WorkDate
		,s.ShiftId
		,s.Code AS ShiftCode
		,ot.TimeIn
		,ot.[TimeOut]
		,ot.TotalHours AS ActualWorkingHours
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.Remark
		,empca.IsHoliday
		,empca.IsOffDay
		,ot.[Status] AS StatusId
	FROM @tblDate AS tmp
		INNER JOIN dbo.OTDailyRequest AS ot WITH (NOLOCK) ON tmp.WorkDate = ot.OvertimeDate
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ot.EmpId = emp.EmpId
		INNER JOIN @tblEmployeeId AS empid ON emp.EmpId = empid.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId =  gr.DepartmentId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		AND ot.OvertimeDate = empca.WorkDate
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
    WHERE ot.[Status] IN (@VerifyStatusId, @ApproveStatusId, @ProcessStatusId)
	ORDER BY tmp.WorkDate
		,emp.NickName
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_MonthlyWorkingHours_EmployeeRequest] @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@Employee NVARCHAR(200) = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@EmployeeStatusId TINYINT = NULL
AS
/*
Created: Tim.Trinh@2019-08-20
Task: get employee request
DB: HRM

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE -- employee status
		@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- work type
		,@OffDay TINYINT = 1
		,@LeaveDay TINYINT = 2
		,@WorkDay TINYINT = 3
		-- request type
		,@CheckInRequestTypeId TINYINT = 1
		,@CheckOutRequestTypeId TINYINT = 2
		,@LateInRequestTypeId TINYINT = 3
		,@EarlyOutRequestTypeId TINYINT = 4
		,@ChangeShiftRequestTypeId TINYINT = 5
		,@LeaveRequestTypeId TINYINT = 6
		,@KeepInViewRequestTypeId TINYINT = 7
		,@OvertimeRequestTypeId TINYINT = 8
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7

	CREATE TABLE #tblGroupIds (GroupId INT)

	CREATE TABLE #tblEmployeeIds (EmpId INT)

	CREATE TABLE #tblRequestIds (RequestId INT)

	CREATE TABLE #tblRequestInDaily (
		RequestId BIGINT
		,EmpId INT
		,RequestType TINYINT
		,InOutMins INT
		,ActualInOutMins INT
		,RequestedTime DATETIME
		,FromDate DATE
		,ToDate DATE
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 1)
		,IsHalfDay BIT
		,KeepInViewType TINYINT
		)

	CREATE TABLE #tblGeneralLeaveDetail (
		RequestId BIGINT
		,LeaveCountDetails NVARCHAR(MAX)
		)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
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
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl
			WHERE tbl.GroupId = emp.GroupId
			)

	SELECT @FromDate = CONVERT(VARCHAR(10), @FromDate, 111)
		,@ToDate = DATEADD(ms, - 2, DATEADD(d, 1, CONVERT(VARCHAR(10), @ToDate, 111)))

	INSERT INTO #tblRequestIds (RequestId)
	SELECT req.RequestId
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON req.EmpId = empid.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = empid.EmpId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON req.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS leavereq WITH (NOLOCK) ON req.RequestId = leavereq.RequestId
		LEFT JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON req.RequestId = kiv.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS mio WITH (NOLOCK) ON req.RequestId = mio.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON req.RequestId = cs.RequestId
	WHERE (
			req.RequestType IN (@LateInRequestTypeId, @EarlyOutRequestTypeId)
			AND inout.OnDate BETWEEN @FromDate
					AND @ToDate
			)
		OR (
			req.RequestType = @LeaveRequestTypeId
			AND (
				(
					leavereq.FromDate BETWEEN @FromDate
						AND @ToDate
					AND leavereq.ToDate >= @ToDate
					)
				OR (
					leavereq.FromDate <= @FromDate
					AND leavereq.ToDate >= @ToDate
					)
				OR leavereq.ToDate BETWEEN @FromDate
					AND @ToDate
				)
			)
		OR (
			req.RequestType = @KeepInViewRequestTypeId
			AND kiv.OnDate BETWEEN @FromDate
				AND @ToDate
			)
		OR (
			req.RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId)
			AND mio.OnDate BETWEEN @FromDate
				AND @ToDate
			)
		OR (
			req.RequestType = @ChangeShiftRequestTypeId
			AND (
				(
					cs.FromDate BETWEEN @FromDate
						AND @ToDate
					AND cs.ToDate >= @ToDate
					)
				OR (
					cs.FromDate <= @FromDate
					AND cs.FromDate <= @ToDate
					AND cs.ToDate >= @ToDate
					)
				OR cs.ToDate BETWEEN @FromDate
					AND @ToDate
				)
			)

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,ActualInOutMins
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,inout.OnDate
		,inout.OnDate
		,0
		,CASE 
			WHEN req.RequestType = @LateInRequestTypeId THEN inout.LateInMins
			ELSE inout.EarlyOutMins
			END
		,CASE 
			WHEN req.RequestType = @LateInRequestTypeId THEN att.LateIn
			ELSE att.EarlyOut
			END
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON req.RequestId = inout.RequestId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON inout.EmpId = att.EmpId
		AND CAST(inout.OnDate AS DATETIME) = att.AttendanceDate

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,lr.FromDate
		,lr.ToDate
		,CASE 
			WHEN ldt.FromTime IS NULL THEN lr.FromDate
			ELSE ldt.FromTime
			END
		,CASE 
			WHEN ldt.ToTime IS NULL THEN lr.ToDate
			ELSE ldt.ToTime
			END
		,lr.TotalDays
		,1
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON req.RequestId = lr.RequestId
		LEFT JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
	WHERE lr.TotalDays = 0.5
		AND ldt.IsHalfDay = 1

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,IsHalfDay
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,lr.FromDate
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,0
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON req.RequestId = lr.RequestId
	WHERE lr.TotalDays <> 0.5

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		,KeepInViewType
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,kiv.OnDate
		,kiv.OnDate
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,CASE 
			WHEN kiv.IsHalfDay = 0 THEN 1
			ELSE 0.5
			END TotalDays
		,kiv.IsHalfDay
		,kiv.KeepInViewType
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON req.RequestId = kiv.RequestId

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,mio.RequestTime
		,mio.OnDate
		,mio.OnDate
		,1 AS TotalDays
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.CheckInOutRequest AS mio WITH (NOLOCK) ON req.RequestId = mio.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = mio.OnDate
		AND ec.EmpId = mio.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON mio.OnDate = att.AttendanceDate
		AND mio.EmpId = att.EmpId
	WHERE req.CurrentStatus = @ApprovedStatusId

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,mio.RequestTime
		,mio.OnDate
		,mio.OnDate
		,1 AS TotalDays
		,ec.ShiftID
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.CheckInOutRequest AS mio WITH (NOLOCK) ON req.RequestId = mio.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = mio.OnDate
		AND ec.EmpId = mio.EmpId
	WHERE req.CurrentStatus <> @ApprovedStatusId

	INSERT INTO #tblRequestInDaily (
		RequestId
		,EmpId
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		)
	SELECT req.RequestId
		,req.EmpId
		,req.RequestType
		,cs.FromDate
		,cs.ToDate
		,COUNT(1) AS TotalDays
		,MAX(csdt.FromShift) AS FromShift
		,MAX(csdt.ToShift) AS ToShift
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON req.RequestId = cs.RequestId
		INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON csdt.RequestId = cs.RequestId
	GROUP BY req.RequestId
		,req.EmpId
		,req.RequestType
		,cs.FromDate
		,cs.ToDate

	INSERT INTO #tblGeneralLeaveDetail (
		RequestId
		,LeaveCountDetails
		)
	SELECT DISTINCT wt.RequestId
		,STUFF((
				SELECT ', ' + CAST(SUM(LeaveDay) AS NVARCHAR(100)) + CASE 
						WHEN SUM(LeaveDay) > 1 THEN ' days '
						ELSE ' day '
						END + Code
				FROM (
					SELECT RequestId
						,CASE 
							WHEN IsOffDay = 1 THEN 'Off'
							ELSE CASE 
									WHEN IsHoliday = 1 THEN 'PH'
									ELSE Code
									END
							END AS Code
						,CASE 
							WHEN IsOffDay <> 1
								AND IsHoliday <> 1 THEN LeaveDay
							ELSE 1
							END AS LeaveDay
					FROM (
						SELECT ldt.RequestId
							,lt1.Code
							,CASE 
								WHEN ldt.IsHalfDay = 0 THEN 1
								ELSE 0.5
								END AS LeaveDay
							,CASE 
								WHEN ldt.WorkType = 1
									OR (
										WorkType IN (0, 3)
										AND cl.IsOffDay = 1
										) THEN 1
								ELSE 0
								END AS IsOffDay
							,CASE 
								WHEN ldt.WorkType = 1
									OR (
										WorkType IN (0, 3)
										AND cl.IsHoliday = 1
										) THEN 1
								ELSE 0
								END AS IsHoliday
						FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							INNER JOIN #tblRequestIds AS r ON r.RequestId = ldt.RequestId
							LEFT JOIN dbo.LeaveType AS lt1 WITH (NOLOCK) ON lt1.LeaveTypeId = ldt.LeaveType
                            AND lt1.CompanyId = @CompanyId
							LEFT JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON ldt.OnDate = cl.WorkDate
							AND ldt.EmpId = cl.EmpId
						WHERE ldt.WorkType <> 3
						) AS a
					) AS b
				WHERE b.RequestId = wt.RequestId
				GROUP BY b.RequestId
					,b.Code
				FOR XML PATH('')
				), 1, 2, '') AS LeaveCountDetails
	FROM (
		SELECT req.RequestId
			,req.CreatedDate
			,req.EmpId
		FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
			INNER JOIN #tblRequestIds AS reqid ON req.RequestId = reqid.RequestId
		) AS wt

	SELECT r.RequestId
		,r.RequestType AS RequestTypeId
		,r.Currentstatus AS RequestStatusId
		,r.CreatedDate
		,rd.RequestedTime AS RequestedDate
		,rd.FromDate
		,rd.ToDate
		,rd.TotalDays
		,rd.IsHalfDay
		,rd.FromTime
		,rd.ToTime
		,rd.KeepInViewType AS KeepInViewTypeId
		,gdt.LeaveCountDetails
		,r.Remark
		,rd.InOutMins AS TotalMinutes
		,rd.ActualInOutMins
		,(CASE 
			WHEN r.RequestType IN (@CheckInRequestTypeId, @CheckOutRequestTypeId, @ChangeShiftRequestTypeId, @KeepInViewRequestTypeId) THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShift
		,(CASE 
			WHEN s2.ShiftId IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShift
		,lv.LeaveTypeId
		,lv.[Name] AS LeaveType
		,e.EmpId AS EmployeeId
		,e.NickName
		,e.FullName
        ,g.Code AS TeamCode
		,g.[Name] AS TeamName
        ,dep.Code AS DepartmentCode
		,dep.[Name] AS DepartmentName
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = r.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK ) ON dep.DepartmentId = g.DepartmentId
		INNER JOIN #tblRequestIds AS rq ON r.RequestId = rq.RequestId
		INNER JOIN #tblRequestInDaily AS rd ON r.RequestId = rd.RequestID
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS c WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftId = rd.FromShift
        AND s1.CompanyId = @CompanyId
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftId = rd.ToShift
        AND s2.CompanyId = @CompanyId
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftId = c.ShiftId
        AND s3.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeId = lr.LeaveType
        AND lv.CompanyId = @CompanyId
	ORDER BY r.CreatedDate DESC

	DROP TABLE #tblGroupIds

	DROP TABLE #tblEmployeeIds

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestIds
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ScheduleArrangement_GetWeekly] @ActorId INT
	,@fromtime DATE
	,@totime DATE
	,@EmpId INT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsIFrame BIT = 0
	,@isLocal BIT = NULL
	,@CompanyId SMALLINT
    ,@IsEditScheduleUnlimited BIT = 0
AS
/*
Created: Tim.Trinh@2019-04-12
Task: Get weekly schedules
DB: HRM

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATE = GETDATE()
		,@EmployeeIds VARCHAR(MAX)
		,@ShiftManagerRoleId TINYINT = 4
		,@GeneralLeaveId TINYINT = 0
		,@OffDayShiftId SMALLINT = - 1
		-- request status
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7
	DECLARE @tblGroupIds TABLE (GroupId INT)
	DECLARE @tblDefaultShift TABLE (
		EmployeeId INT
		,ShiftId INT
		)
	CREATE TABLE #tblEmployeeIds (EmpId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO @tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT OwnerId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
	WHERE EmpId = @ActorId
		AND (
			@EmpId IS NULL
			OR es.OwnerId = @EmpId
			)
		AND ActionType = @ShiftManagerRoleId
		AND ISNULL(IsDeleted, 0) = 0
		AND EXISTS (
			SELECT 1
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN @tblGroupIds AS gr ON emp.GroupId = gr.GroupId
			WHERE emp.[Enabled] = 1
				AND emp.isDeleted = 0
				AND es.OwnerId = emp.EmpId
			)

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT emp.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
	WHERE gs.OwnerId = @ActorId
		AND gs.ActionType = @ShiftManagerRoleId
		AND ISNULL(gs.IsDeleted, 0) = 0
		AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND (
			@EmpId IS NULL
			OR emp.EmpId = @EmpId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblGroupIds AS gr
			WHERE emp.GroupId = gr.GroupId
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblEmployeeIds AS tbl WITH (NOLOCK)
			WHERE tbl.EmpId = emp.EmpId
			)

	IF @IsIFrame = 1
		OR @IsEditScheduleUnlimited = 1
	BEGIN
		INSERT INTO #tblEmployeeIds (EmpId)
		SELECT EmpId
		FROM dbo.Employee AS emp WITH (NOLOCK)
		WHERE [Enabled] = 1
			AND isDeleted = 0
			AND (
				@EmpId IS NULL
				OR emp.EmpId = @EmpId
				)
			AND EXISTS (
				SELECT 1
				FROM @tblGroupIds AS gr
				WHERE emp.GroupId = gr.GroupId
				)
			AND NOT EXISTS (
				SELECT 1
				FROM #tblEmployeeIds AS tbl WITH (NOLOCK)
				WHERE emp.EmpId = tbl.EmpId
				)
	END

	DELETE emp
	FROM #tblEmployeeIds AS emp
	WHERE EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS esum WITH (NOLOCK)
			WHERE emp.EmpId = esum.EmpId
				AND esum.IsTopManager = 1
			)

	SELECT @EmployeeIds = COALESCE(@EmployeeIds + ',', '') + CAST(EmpId AS VARCHAR(10))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
		,@fromDate = @fromtime
		,@toDate = @totime
		,@empIds = @EmployeeIds
		,@isEnable = 1
		,@isDelete = 0

	SELECT emp.EmpId
		,tmpca.WorkDate
		,tmpca.ShiftId
		,tmpca.IsOvertime
		,tmpca.IsOffDay
		,tmpca.IsHoliday
		,tmpca.IsKeepInView
		,tmpca.IsLeaveOffDay
		,tmpca.IsLeaveDay
		,tmpca.LeaveTypeId
		,tmpca.FromTime
		,tmpca.ToTime
		,tmpca.LeaveTypeId2
		,tmpca.LeaveDay
		,empca.IsFixedOffDay
		,empca.IsPublic
		,empca.ModifiedBy
		,empca.ModifiedDate
		,(CASE 
			WHEN offrep.EmployeeId IS NOT NULL THEN 1
			ELSE 0 END
			) AS IsOffDayReplacement
		,tmpca.ChangeShiftTypeId
		,tmpca.MoveOffFromDate
		,tmpca.MoveOffToDate
	INTO #tblEmployeeCalendar
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON emp.EmpId = tmpca.EmpId
		AND tmpca.WorkDate BETWEEN @fromTime
			AND @toTime
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		AND tmpca.WorkDate = empca.WorkDate
		LEFT JOIN dbo.ScheduleArrangementOffDayReplacement AS offrep WITH (NOLOCK) ON emp.EmpId = offrep.EmployeeId
		AND tmpca.WorkDate = offrep.WorkDate
	WHERE @IsIFrame = 0
		OR (
			@IsIFrame = 1
			AND ISNULL(empca.IsPublic, 0) = 1
			)

	IF @IsIFrame = 1
	BEGIN
		DELETE emp
		FROM #tblEmployeeIds AS emp WITH (NOLOCK)
		WHERE NOT EXISTS (
				SELECT 1
				FROM #tblEmployeeCalendar AS empca WITH (NOLOCK)
				WHERE emp.EmpId = empca.EmpId
				)
	END

	INSERT INTO @tblDefaultShift (
		EmployeeId
		,ShiftId
		)
	SELECT emp.EmpId
		,defaultshift.ShiftId
	FROM #tblEmployeeIds AS emp WITH (NOLOCK)
		INNER JOIN dbo.ScheduleArrangementDefaultShift AS defaultshift WITH (NOLOCK) ON emp.EmpId = defaultshift.EmployeeId
	WHERE defaultshift.FromDate = @fromtime

	INSERT INTO @tblDefaultShift (
		EmployeeId
		,ShiftId
		)
	SELECT data.EmployeeId
		,defaultshift.ShiftId
	FROM (
		SELECT EmployeeId
			,MAX(FromDate) AS FromDate
		FROM dbo.ScheduleArrangementDefaultShift WITH (NOLOCK)
		WHERE FromDate < @fromtime
		GROUP BY EmployeeId
		) data
		INNER JOIN dbo.ScheduleArrangementDefaultShift AS defaultshift WITH (NOLOCK) ON data.EmployeeId = defaultshift.EmployeeId
		AND data.FromDate = defaultshift.FromDate
	WHERE NOT EXISTS (
			SELECT 1
			FROM @tblDefaultShift AS tbl
			WHERE defaultshift.EmployeeId = tbl.EmployeeId
			)

	SELECT emp.EmpId AS EmployeeId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,ISNULL(esum.OffDaysbyWeek, 0) AS OffDaysbyWeek
		,emp.PickupRemark
		,arrange.Remark
		,arrange.DisplayOrder
		,esum.IsDefaultSchedule AS IsUsedWeeklyDefaultShift
		,modifier.NickName AS Modifier
		,ec.ModifiedDate
		,gr.GroupId AS TeamId
		,gr.Code
		,gr.[Name]
		,[shift].ShiftId AS DefaultShiftId
		,[shift].Code
		,[shift].[Name]
		,[shift].BeginCheckInTime AS CheckIn
		,[shift].BeginCheckOutTime AS CheckOut
		,[shift].IsInAfterDay
		,[shift].IsOutAfterDay
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		LEFT JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON emp.EmpId = esum.EmpId
		LEFT JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN dbo.ScheduleArrangement AS arrange WITH (NOLOCK) ON emp.EmpId = arrange.EmployeeId
		LEFT JOIN dbo.ScheduleArrangementGroupOrder AS gorder WITH (NOLOCK) ON gr.GroupId = gorder.GroupId
		LEFT JOIN @tblDefaultShift AS defaultshift ON emp.EmpId = defaultshift.EmployeeId
		LEFT JOIN dbo.[Shift] AS [shift] WITH (NOLOCK) ON defaultshift.ShiftId = [shift].ShiftId
		AND ISNULL([shift].IsDisabled, 0) = 0
		OUTER APPLY (
		SELECT TOP 1 ec.ModifiedBy
			,ec.ModifiedDate
		FROM #tblEmployeeCalendar AS ec
		WHERE ec.EmpId = emp.EmpId
			AND ec.ModifiedBy IS NOT NULL
			AND ec.ModifiedDate IS NOT NULL
			AND ec.ModifiedDate = (
				SELECT MAX(ec1.ModifiedDate)
				FROM #tblEmployeeCalendar AS ec1 WITH (NOLOCK)
				WHERE ec.EmpId = ec1.EmpId
				)
		) AS ec
		LEFT JOIN dbo.Employee AS modifier WITH (NOLOCK) ON ec.ModifiedBy = modifier.EmpId
	WHERE EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tblgr
			WHERE emp.GroupId = tblgr.GroupId
			)
			AND (
			@isLocal IS NULL
			OR esum.IsLocal = @isLocal
			)
	ORDER BY ISNULL(gorder.DisplayOrder, 0)
		,gr.Code
		,ISNULL(arrange.DisplayOrder, 0)
		,emp.NickName

	SELECT emp.EmpId AS EmployeeId
		,empca.WorkDate
		,empca.IsOvertime
		,empca.IsLeaveOffDay
		,empca.ChangeShiftTypeId
		,empca.MoveOffFromDate
		,empca.MoveOffToDate
		,empca.IsHoliday
		,empca.IsOffDay
		,empca.IsFixedOffDay
		,empca.IsLeaveDay
		,empca.IsKeepInView
		,empca.LeaveDay
		,empca.IsPublic
		,empca.IsOffDayReplacement
		,(CASE 
			WHEN empca.ModifiedBy IS NOT NULL OR empca.IsPublic = 1 THEN 1
			WHEN @fromTime <= @Today THEN 1
			ELSE 0 END
			) AS IsModified
		,[shift].ShiftId
		,[shift].Code
		,[shift].[Name]
		,[shift].BeginCheckInTime AS CheckIn
		,[shift].BeginCheckOutTime AS CheckOut
		,[shift].IsInAfterDay
		,[shift].IsOutAfterDay
		,lv1.LeaveTypeId
		,lv1.Code
		,lv1.[Name]
		,empca.FromTime
		,empca.ToTime
		,lv2.LeaveTypeId AS LeaveTypeId2
		,lv2.Code
		,lv2.[Name]
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		INNER JOIN #tblEmployeeCalendar AS empca ON emp.EmpId = empca.EmpId
		AND empca.WorkDate BETWEEN @fromTime
			AND @toTime
		LEFT JOIN dbo.[Shift] AS [shift] WITH (NOLOCK) ON [shift].ShiftId = empca.ShiftId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId
        AND lv1.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId
        AND lv2.CompanyId = @CompanyId
	WHERE EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tblgr
			WHERE emp.GroupId = tblgr.GroupId
			)
	ORDER BY emp.NickName
		,empca.WorkDate

	SELECT emp.EmpId AS EmployeeId
		,ISNULL(monshift.ShiftId, @OffDayShiftId) AS MonShiftId
		,ISNULL(tueshift.ShiftId, @OffDayShiftId) AS TueShiftId
		,ISNULL(wedshift.ShiftId, @OffDayShiftId) AS WedShiftId
		,ISNULL(thushift.ShiftId, @OffDayShiftId) AS ThuShiftId
		,ISNULL(frishift.ShiftId, @OffDayShiftId) AS FriShiftId
		,ISNULL(satshift.ShiftId, @OffDayShiftId) AS SatShiftId
		,ISNULL(sunshift.ShiftId, @OffDayShiftId) AS SunShiftId
	FROM #tblEmployeeIds AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
		LEFT JOIN dbo.EmployeeDefaultShift AS eds WITH (NOLOCK) ON eds.EmpId = emp.EmpId
		LEFT JOIN dbo.[Shift] AS monshift WITH (NOLOCK) ON eds.MonShift = monshift.ShiftId
		AND ISNULL(monshift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS tueshift WITH (NOLOCK) ON eds.TueShift = tueshift.ShiftId
		AND ISNULL(tueshift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS wedshift WITH (NOLOCK) ON eds.WedShift = wedshift.ShiftId
		AND ISNULL(wedshift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS thushift WITH (NOLOCK) ON eds.ThuShift = thushift.ShiftId
		AND ISNULL(thushift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS frishift WITH (NOLOCK) ON eds.FriShift = frishift.ShiftId
		AND ISNULL(frishift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS satshift WITH (NOLOCK) ON eds.SatShift = satshift.ShiftId
		AND ISNULL(satshift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS sunshift WITH (NOLOCK) ON eds.SunShift = sunshift.ShiftId
		AND ISNULL(sunshift.IsDisabled, 0) = 0
	WHERE ce.CompanyId = @CompanyId

	DROP TABLE #tblEmployeeIds
	DROP TABLE #tblEmployeeCalendar
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_MonthlyWorkingHours] @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@Employee NVARCHAR(200) = NULL
	,@IsLocal BIT = NULL
	,@EmployeeStatusId TINYINT = NULL
AS
/*
Created: Tim@2019-06-24
Task: monthly working hours
DB: HRM

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATE = GETDATE()
		,@EmployeeIds VARCHAR(MAX) = ''
		-- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- leave type 
		,@KIVByHourLeaveType INT = 48
	CREATE TABLE #tblGroupIds (GroupId INT PRIMARY KEY)
	CREATE TABLE #tblEmployeeIds (EmployeeId INT PRIMARY KEY)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
		WHERE ISNUMERIC(value) = 1
	END

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
        INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		AND empsum.IsTopManager = 0
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
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE tbl.GroupId = emp.GroupId
			)

	SELECT @EmployeeIds = COALESCE(@EmployeeIds + ',', '') + CAST(EmployeeId AS VARCHAR(20))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
        ,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @EmployeeIds

	SELECT emp.EmpId AS EmployeeId
		,empca.WorkDate
		,(CASE 
			WHEN empatt.TotalWorkHours > 0 THEN empatt.TotalWorkHours
			ELSE (
				SELECT DATEDIFF(mi, min(t.RequestTime), max(t.RequestTime)) / 60.0
				FROM (
					SELECT cio.EmpId, cio.OnDate, cio.RequestTime
					FROM dbo.CheckInOutRequest AS cio WITH (NOLOCK)
						INNER JOIN dbo.WorkingTimeRequest AS w WITH (NOLOCK) ON cio.RequestId = w.RequestId
					WHERE cio.EmpId = emp.EmpId
                        AND cio.OnDate = empca.WorkDate
                        AND w.CurrentStatus NOT IN (3, 5, 7)
				) AS t
			)
			END) AS TotalWorkingHours
		,empca.IsHoliday
		,empca.IsOffDay
		,(CASE 
			WHEN empca.IsLeaveDay = 1
				AND (empca.LeaveTypeId = @KIVByHourLeaveType OR empca.LeaveTypeId2 = @KIVByHourLeaveType) THEN 0
			ELSE empca.IsLeaveDay END
			) AS IsLeaveDay
		,(CASE 
			WHEN empca.LeaveTypeId = @KIVByHourLeaveType AND empca.LeaveTypeId2 = @KIVByHourLeaveType THEN empca.LeaveDay - 1
			WHEN empca.LeaveTypeId = @KIVByHourLeaveType OR empca.LeaveTypeId2 = @KIVByHourLeaveType THEN empca.LeaveDay - 0.5
			ELSE empca.LeaveDay END
			) AS LeaveDay
		,(CASE 
			WHEN empca.WorkDate < DATEADD(DAY, -1, @Today)
				AND empatt.ShiftId IS NOT NULL
				AND empatt.InFixed IS NULL
				AND empatt.OutFixed IS NOT NULL
				AND empatt.TotalWorkHours IS NULL THEN 1
			ELSE 0 END
			) AS IsMissingCheckIn
		,(CASE 
			WHEN empca.WorkDate < DATEADD(DAY, -1, @Today)
				AND empatt.ShiftId IS NOT NULL
				AND empatt.OutFixed IS NULL
				AND empatt.InFixed IS NOT NULL
				AND empatt.TotalWorkHours IS NULL THEN 1
			ELSE 0 END
			) AS IsMissingCheckOut
		,(CASE 
			WHEN empca.WorkDate < DATEADD(DAY, -1, @Today)
				AND empca.ShiftId IS NOT NULL
				AND (
					empsum.IsDefaultSchedule = 0
					OR (
						empsum.IsLocal = 1
						AND empsum.IsDefaultSchedule = 1
						AND NOT (
							empca.IsHoliday = 1
							OR empca.IsOffDay = 1
							)
						)
					)
				AND empatt.InFixed IS NULL
				AND empatt.OutFixed IS NULL
				AND empatt.TotalWorkHours IS NULL THEN 1
			ELSE 0 END
			) AS IsAbsent
		,r.CurrentStatus AS RequestStatusId
		,empca.LeaveTypeId
		,lv.Code
		,lv.[Name]
		,empca.FromTime
		,empca.ToTime
		,empca.LeaveTypeId2
		,lv2.Code AS LeaveCode
		,lv2.[Name] AS LeaveName
	INTO #tblEmployeeCalendar
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid WITH (NOLOCK) ON emp.EmpId = empid.EmployeeId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON emp.EmpId = empatt.EmpId
		AND CAST(empatt.AttendanceDate AS DATE) = empca.WorkDate
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON empca.LeaveTypeId = lv.LeaveTypeId
        AND lv.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId
        AND lv2.CompanyId = @CompanyId
		LEFT JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON empca.RequestId = r.RequestId
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate

	SELECT emp.EmpId AS EmployeeId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,empsum.WorkingDays
		,dep.Code AS DepartmentCode
		,dep.[Name] AS DepartmentName
		,gr.GroupId AS Id
		,gr.Code
		,gr.[Name]
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid WITH (NOLOCK) ON emp.EmpId = empid.EmployeeId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
	ORDER BY gr.[Name]
		,emp.Code

	SELECT EmployeeId
		,WorkDate
		,TotalWorkingHours
		,IsHoliday
		,IsOffDay
		,IsLeaveDay
		,LeaveDay
		,IsMissingCheckIn
		,IsMissingCheckOut
		,IsAbsent
		,RequestStatusId
		,LeaveTypeId
		,Code
		,[Name]
		,FromTime
		,ToTime
		,LeaveTypeId2
		,LeaveCode
		,LeaveName
	FROM #tblEmployeeCalendar WITH (NOLOCK)
	ORDER BY EmployeeId
		,WorkDate

	DROP TABLE #tblGroupIds
	DROP TABLE #tblEmployeeIds
	DROP TABLE #tblEmployeeCalendar
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ScheduleArrangement_GetEmployee] @ActorId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@Query NVARCHAR(256) = ''
	,@IsIFrame BIT = 0
    ,@IsEditScheduleUnlimited BIT = 0
AS
/*
Created: Tim.Trinh@2019-05-02
Task: get employee
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ShiftManagerRoleId TINYINT = 4
		,@q NVARCHAR(258) = '%' + ISNULL(@Query, '') + '%'

	CREATE TABLE #tblGroupIds (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	SELECT e.EmpId AS EmployeeId
		,e.FullName
		,e.NickName
	FROM dbo.Employee AS e WITH (NOLOCK)
	WHERE e.[Enabled] = 1
		AND e.isDeleted = 0
		AND (
			e.NickName LIKE @q
			OR e.FullName LIKE @q
			)
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS esum WITH (NOLOCK)
			WHERE esum.EmpId = e.EmpId
				AND esum.IsTopManager = 1
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tblgr
			WHERE e.GroupId = tblgr.GroupId
			)
		AND (
			@IsIFrame = 1
			OR @IsEditScheduleUnlimited = 1
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
				WHERE es.EmpId = @ActorId
					AND ISNULL(es.IsDeleted, 0) = 0
					AND es.ActionType = @ShiftManagerRoleId
					AND es.OwnerId = e.EmpId
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
				WHERE gs.OwnerId = @ActorId
					AND ISNULL(gs.IsDeleted, 0) = 0
					AND gs.ActionType = @ShiftManagerRoleId
					AND e.GroupId = gs.GroupId
				)
			)
	ORDER BY e.NickName

	DROP TABLE #tblGroupIds
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_DisciplineSummaryPerYear] @CompanyId SMALLINT
    ,@FromDate DATE
	,@ToDate DATE
	,@ApproverId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@IsLocal BIT = NULL
	,@IsShowAll BIT = 0
    ,@RoleIds VARCHAR(1000) = ''
AS
/*
Created: 20220720@Tim.Trinh
Task: discipline summary by year
DB: HRM

Revisions:
    20250404@Tim: add param @RoleIds, remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpTeam (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	CREATE TABLE #tmpEmployeeDiscipline (
		WorkDate DATE
		,EmpId INT
		,ApproverSubtractScore FLOAT
		,OtherDisciplineScore DECIMAL(5, 2)
		)

	INSERT INTO #tmpEmployeeDiscipline (
		EmpId
		,WorkDate
		,ApproverSubtractScore
		,OtherDisciplineScore
		)
	SELECT emp.EmpId
		,ISNULL(dis.WorkDate, otherdis.WorkDate)
		,CASE 
			WHEN dis.EmpId IS NOT NULL THEN (CASE 
					WHEN dis.IsChangeShift = 1
						AND ignored.IsIgnoredChangeShift = 0 THEN dbo.fncGetDisciplineScoreById(1)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsMissingCheckInOut = 1
						AND ignored.IsIgnoredMissingCheckInOut = 0 THEN dbo.fncGetDisciplineScoreById(2)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsLateIn = 1
						AND ignored.IsIgnoredLateIn = 0 THEN dbo.fncGetDisciplineScoreById(3)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsEarlyOut = 1
						AND ignored.IsIgnoredEarlyOut = 0 THEN dbo.fncGetDisciplineScoreById(4)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsAbsent = 1
						AND ignored.IsIgnoredAbsent = 0 THEN dbo.fncGetDisciplineScoreById(5)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnplannedLeave = 1
						AND ignored.IsIgnoredUnplannedLeave = 0 THEN dbo.fncGetDisciplineScoreById(9)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnpaidLeave = 1
						AND ignored.IsIgnoredUnpaidLeave = 0 THEN dbo.fncGetDisciplineScoreById(6)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsWorkingUndertime = 1
						AND ignored.IsIgnoredWorkingUndertime = 0 THEN dbo.fncGetDisciplineScoreById(7)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnpaidLeaveAbsent = 1
						AND ignored.IsIgnoredUnpaidLeaveAbsent = 0 THEN dbo.fncGetDisciplineScoreById(8)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsWeekendLeave = 1
						AND ignored.IsIgnoredWeekendLeave = 0 THEN dbo.fncGetDisciplineScoreById(10)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsSevenDaysLeave = 1
						AND ignored.IsIgnoredSevenDaysLeave = 0 THEN dbo.fncGetDisciplineScoreById(11)
					ELSE 0 END
					)
			ELSE 0
			END
		,CASE 
			WHEN otherdis.EmpId IS NOT NULL THEN otherdis.Score
			ELSE 0
			END
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        INNER JOIN dbo.EmployeeSummary AS empSum WITH (NOLOCK) ON emp.EmpId = empSum.EmpId AND empSum.IsTopManager = 0
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		AND gr.IsDeleted = 0
		LEFT JOIN dbo.Discipline AS dis WITH (NOLOCK) ON dis.EmpId = emp.EmpId
		AND dis.IsDeleted = 0
		AND dis.WorkDate BETWEEN @FromDate
			AND @ToDate
		LEFT JOIN dbo.DisciplineIgnore AS ignored WITH (NOLOCK) ON dis.EmpId = ignored.EmpId
		AND dis.WorkDate = ignored.WorkDate
		LEFT JOIN dbo.OtherDiscipline AS otherdis WITH (NOLOCK) ON otherdis.EmpId = emp.EmpId
		AND otherdis.IsDeleted = 0
		AND otherdis.WorkDate BETWEEN @FromDate
			AND @ToDate
		AND dis.WorkDate = otherdis.WorkDate
	WHERE ce.CompanyId = @CompanyId
        AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		AND (
			dis.EmpId IS NOT NULL
			OR otherdis.EmpId IS NOT NULL
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpTeam AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (
			@EmployeeId IS NULL
			OR emp.EmpId = @EmployeeId
			)
		AND (
			@IsLocal IS NULL
			OR empSum.IsLocal = @IsLocal
			)

	DECLARE @Is_HR_SA BIT
	DECLARE @tblRole TABLE (RoleId INT)

	INSERT INTO @tblRole (RoleId)
	SELECT value
	FROM STRING_SPLIT(@RoleIds, ',')

	SET @Is_HR_SA = CASE 
			WHEN EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId IN (6, 7) -- HR, SA
					) THEN 1
			ELSE 0
			END

	DELETE
	FROM #tmpEmployeeDiscipline WITH (ROWLOCK, UPDLOCK)
	WHERE ApproverSubtractScore = 0
		AND OtherDisciplineScore = 0

	SELECT emp.EmpId AS EmployeeId
		,emp.NickName
		,emp.FullName
		,emp.Code
		,emp.JoinedDate
		,empsum.CompanyDate
		,empsum.IsLocal
		,empsum.MilitaryFromDate
		,empsum.MilitaryToDate
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
        ,dept.Code AS DepartmentCode
		,dept.[Name] AS DepartmentName
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		AND gr.IsDeleted = 0
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON gr.DepartmentId = dept.DepartmentId
		AND dept.IsDeleted = 0
	WHERE ce.CompanyId = @CompanyId
        AND emp.[Enabled] = 1
		AND emp.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tmpTeam AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (
			@EmployeeId IS NULL
			OR emp.EmpId = @EmployeeId
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND (
			@IsShowAll = 1
			OR (
				@IsShowAll = 0
				AND EXISTS (
					SELECT 1
					FROM #tmpEmployeeDiscipline WITH (NOLOCK)
					WHERE emp.EmpId = EmpId
					)
				)
			)
		AND (
			@Is_HR_SA = 1 -- SA, HR can view all member of company
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = emp.EmpId
					AND empS.ActionType = 8 -- edit discipline
					AND empS.EmpId <> @ApproverId
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE gr.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType = 8 -- edit discipline
					AND emp.EmpId != @ApproverId
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId != @ApproverId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType = 8
							AND ISNULL(emps.IsDeleted, 0) = 0
						)
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = emp.EmpId
					AND empS.ActionType IN (2, 3) -- Approver and Verifier
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE gr.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType IN (2, 3) -- Approver and Verifier
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId != @ApproverId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType IN (2, 3)
							AND ISNULL(emps.IsDeleted, 0) = 0
						)
				)
			OR (
				EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId = 1 -- Employee
					)
				AND emp.EmpId = @ApproverId
				)
			)
	ORDER BY gr.[Name] ASC

	SELECT dis.EmpId AS EmployeeId
		,YEAR(dis.WorkDate) AS [Year]
		,SUM(dis.OtherDisciplineScore + dis.ApproverSubtractScore) AS ApproverSubtractScore
	FROM #tmpEmployeeDiscipline AS dis WITH (NOLOCK)
	GROUP BY dis.EmpId
		,YEAR(dis.WorkDate)
	ORDER BY dis.EmpId
		,YEAR(dis.WorkDate)

	DROP TABLE #tmpEmployeeDiscipline

	DROP TABLE #tmpTeam
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_DisciplineDetail] @FromDate DATE
	,@ToDate DATE
	,@ApproverId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@ReasonId INT = NULL
	,@IsLocal BIT = NULL
	,@HasIgnored BIT = NULL
	,@CompanyId SMALLINT
    ,@RoleIds VARCHAR(1000) = ''
AS
/*
Created: 20191204@Tim.Trinh
Task: get discipline detail
DB: HRM

Revisions:
    20250404@Tim: add param @RoleIds [Redmine: #222886]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblGroupIds (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	DECLARE @HasEditDisciplineRole INT = 0
	--request type
	DECLARE @ChangeShift TINYINT = 5
		,@CheckIn TINYINT = 1
		,@CheckOut TINYINT = 2
		,@LateIn TINYINT = 3
		,@EarlyOut TINYINT = 4
		,@Leave TINYINT = 6
	-- discipline type
	DECLARE @ChangeShiftId TINYINT = 1
		,@MissingCheckInOutId TINYINT = 2
		,@LateInId TINYINT = 3
		,@EarlyOutId TINYINT = 4
		,@AbsentId TINYINT = 5
		,@UnpaidLeaveId TINYINT = 6
		,@WorkingUnderTimeId TINYINT = 7
		,@UnpaidLeaveAbsentId TINYINT = 8
		,@UnplannedLeaveId TINYINT = 9
		,@WeekendLeaveId TINYINT = 10
		,@SevenDaysLeaveId TINYINT = 11
	DECLARE @tblRole TABLE (RoleId INT)

	CREATE TABLE #tblDisciplineDetail (
		EmployeeId INT
		,WorkDate DATE
		,ChangeShiftId INT
		,ChangeShiftValue INT
		,ChangeShiftScore DECIMAL(5, 2)
		,ChangeShiftHasViolated BIT
		,ChangeShiftHasIgnored BIT
		,ChangeShiftHasApprovedBy BIT
		,MissingCheckInOutId INT
		,MissingCheckInOutValue INT
		,MissingCheckInOutScore DECIMAL(5, 2)
		,MissingCheckInOutHasViolated BIT
		,MissingCheckInOutHasIgnored BIT
		,MissingCheckInOutHasApprovedBy BIT
		,LateInId INT
		,LateInValue INT
		,LateInScore DECIMAL(5, 2)
		,LateInHasViolated BIT
		,LateInHasIgnored BIT
		,LateInHasApprovedBy BIT
		,EarlyOutId INT
		,EarlyOutValue INT
		,EarlyOutScore DECIMAL(5, 2)
		,EarlyOutHasViolated BIT
		,EarlyOutHasIgnored BIT
		,EarlyOutHasApprovedBy BIT
		,AbsentId INT
		,AbsentValue INT
		,AbsentScore DECIMAL(5, 2)
		,AbsentHasViolated BIT
		,AbsentHasIgnored BIT
		,AbsentHasApprovedBy BIT
		,UnplannedLeaveId INT
		,UnplannedLeaveValue INT
		,UnplannedLeaveScore DECIMAL(5, 2)
		,UnplannedLeaveHasViolated BIT
		,UnplannedLeaveHasIgnored BIT
		,UnplannedLeaveHasApprovedBy BIT
		,UnpaidLeaveId INT
		,UnpaidLeaveValue INT
		,UnpaidLeaveScore DECIMAL(5, 2)
		,UnpaidLeaveHasViolated BIT
		,UnpaidLeaveHasIgnored BIT
		,UnpaidLeaveHasApprovedBy BIT
		,WorkingUnderTimeId INT
		,WorkingUnderTimeValue INT
		,WorkingUnderTimeScore DECIMAL(5, 2)
		,WorkingUnderTimeHasViolated BIT
		,WorkingUnderTimeHasIgnored BIT
		,WorkingUnderTimeHasApprovedBy BIT
		,UnpaidLeaveAbsentId INT
		,UnpaidLeaveAbsentValue INT
		,UnpaidLeaveAbsentScore DECIMAL(5, 2)
		,UnpaidLeaveAbsentHasViolated BIT
		,UnpaidLeaveAbsentHasIgnored BIT
		,UnpaidLeaveAbsentHasApprovedBy BIT
		,WeekendLeaveId INT
		,WeekendLeaveValue INT
		,WeekendLeaveScore DECIMAL(5, 2)
		,WeekendLeaveHasViolated BIT
		,WeekendLeaveHasIgnored BIT
		,WeekendLeaveHasApprovedBy BIT
		,SevenDaysLeaveId INT
		,SevenDaysLeaveValue INT
		,SevenDaysLeaveScore DECIMAL(5, 2)
		,SevenDaysLeaveHasViolated BIT
		,SevenDaysLeaveHasIgnored BIT
		,SevenDaysLeaveHasApprovedBy BIT
		,EmployeeComment NVARCHAR(MAX)
		,ApproverComment NVARCHAR(MAX)
		,IsOutOfControlReason BIT
		)

	INSERT INTO @tblRole (RoleId)
	SELECT value
	FROM STRING_SPLIT(@RoleIds, ',')

	SELECT @HasEditDisciplineRole = 1
	FROM @tblRole
	WHERE RoleId = 8 -- edit discipline

	INSERT INTO #tblDisciplineDetail
	SELECT DISTINCT emp.EmpId
		,dis.WorkDate
		,@ChangeShiftId AS ChangeShiftId
		,dis.IsChangeShift AS ChangeShiftValue
		,dbo.fncGetDisciplineScoreById(@ChangeShiftId) AS ChangeShiftScore
		,(CASE 
			WHEN dis.IsChangeShift = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @ChangeShiftId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS ChangeShiftHasViolated
		,ignored.IsIgnoredChangeShift AS ChangeShiftHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS ChangeShiftHasApprovedBy
		,@MissingCheckInOutId AS MissingCheckInOutId
		,dis.IsMissingCheckInOut AS MissingCheckInOutValue
		,dbo.fncGetDisciplineScoreById(@MissingCheckInOutId) AS MissingCheckInOutScore
		,(CASE 
			WHEN dis.IsMissingCheckInOut = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @MissingCheckInOutId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS MissingCheckInOutHasViolated
		,ignored.IsIgnoredMissingCheckInOut AS MissingCheckInOutHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND (dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1) THEN 1
			ELSE 0 END
			) AS MissingCheckInOutHasApprovedBy
		,@LateInId AS LateInId
		,dis.IsLateIn AS LateInValue
		,dbo.fncGetDisciplineScoreById(@LateInId) AS LateInScore
		,(CASE 
			WHEN dis.IsLateIn = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @LateInId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS LateInHasViolated
		,ignored.IsIgnoredLateIn AS LateInHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS LateInHasApprovedBy
		,@EarlyOutId AS EarlyOutId
		,dis.IsEarlyOut AS EarlyOutValue
		,dbo.fncGetDisciplineScoreById(@EarlyOutId) AS EarlyOutScore
		,(CASE 
			WHEN dis.IsEarlyOut = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @EarlyOutId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS EarlyOutHasViolated
		,ignored.IsIgnoredEarlyOut AS EarlyOutHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS EarlyOutHasApprovedBy
		,@AbsentId AS AbsentId
		,dis.IsAbsent AS AbsentValue
		,dbo.fncGetDisciplineScoreById(@AbsentId) AS AbsentScore
		,(CASE 
			WHEN dis.IsAbsent = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @AbsentId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS AbsentHasViolated
		,ignored.IsIgnoredAbsent AS AbsentHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS AbsentHasApprovedBy
		,@UnplannedLeaveId AS UnplannedLeaveId
		,dis.IsUnplannedLeave AS UnplannedLeaveValue
		,dbo.fncGetDisciplineScoreById(@UnplannedLeaveId) AS UnplannedLeaveScore
		,(CASE 
			WHEN dis.IsUnplannedLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @UnplannedLeaveId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS UnplannedLeaveHasViolated
		,ignored.IsIgnoredUnplannedLeave AS UnplannedLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnplannedLeaveHasApprovedBy
		,@UnpaidLeaveId AS UnpaidLeaveId
		,dis.IsUnpaidLeave AS UnpaidLeaveValue
		,dbo.fncGetDisciplineScoreById(@UnpaidLeaveId) AS UnpaidLeaveScore
		,(CASE 
			WHEN dis.IsUnpaidLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @UnpaidLeaveId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS UnpaidLeaveHasViolated
		,ignored.IsIgnoredUnpaidLeave AS UnpaidLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnpaidLeaveHasApprovedBy
		,@WorkingUnderTimeId AS WorkingUnderTimeId
		,dis.IsWorkingUnderTime AS WorkingUnderTimeValue
		,dbo.fncGetDisciplineScoreById(@WorkingUnderTimeId) AS WorkingUnderTimeScore
		,(CASE 
			WHEN dis.IsWorkingUndertime = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @WorkingUnderTimeId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS WorkingUnderTimeHasViolated
		,ignored.IsIgnoredWorkingUndertime AS WorkingUnderTimeHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS WorkingUnderTimeHasApprovedBy
		,@UnpaidLeaveAbsentId AS UnpaidLeaveAbsentId
		,dis.IsUnpaidLeaveAbsent AS UnpaidLeaveAbsentValue
		,dbo.fncGetDisciplineScoreById(@UnpaidLeaveAbsentId) AS UnpaidLeaveAbsentScore
		,(CASE 
			WHEN dis.IsUnpaidLeaveAbsent = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @UnpaidLeaveAbsentId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS UnpaidLeaveAbsentHasViolated
		,ignored.IsIgnoredUnpaidLeaveAbsent AS UnpaidLeaveAbsentHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnpaidLeaveAbsentHasApprovedBy
		,@WeekendLeaveId AS WeekendLeaveId
		,dis.IsWeekendLeave AS WeekendLeaveValue
		,dbo.fncGetDisciplineScoreById(@WeekendLeaveId) AS WeekendLeaveScore
		,(CASE 
			WHEN dis.IsWeekendLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @WeekendLeaveId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS WeekendLeaveHasViolated
		,ignored.IsIgnoredWeekendLeave AS WeekendLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS WeekendLeaveHasApprovedBy
		,@SevenDaysLeaveId AS SevenDaysLeaveId
		,dis.IsSevenDaysLeave AS SevenDaysLeaveValue
		,dbo.fncGetDisciplineScoreById(@SevenDaysLeaveId) AS SevenDaysLeaveScore
		,(CASE 
			WHEN dis.IsSevenDaysLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @SevenDaysLeaveId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS SevenDaysLeaveHasViolated
		,ignored.IsIgnoredSevenDaysLeave AS SevenDaysLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS SevenDaysLeaveHasApprovedBy
		,dis.EmployeeComment
		,dis.ApproverComment
		,dis.IsOutOfControlReason
	FROM dbo.Discipline AS dis WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON dis.EmpId = emp.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.EmployeeSummary AS empSum WITH (NOLOCK) ON emp.EmpId = empSum.EmpId
		INNER JOIN dbo.DisciplineIgnore AS ignored WITH (NOLOCK) ON dis.EmpId = ignored.EmpId
		AND dis.WorkDate = ignored.WorkDate
	WHERE emp.[Enabled] = 1
		AND emp.IsDeleted = 0
		AND dis.IsDeleted = 0
		AND dis.WorkDate BETWEEN @FromDate
			AND @ToDate
		AND (@EmployeeId IS NULL OR emp.EmpId = @EmployeeId)
		AND (
			dis.IsChangeShift = 1
			OR dis.IsMissingCheckInOut = 1
			OR dis.IsLateIn = 1
			OR dis.IsEarlyOut = 1
			OR dis.IsAbsent = 1
			OR dis.IsUnplannedLeave = 1
			OR dis.IsUnpaidLeave = 1
			OR dis.IsWorkingUnderTime = 1
			OR dis.IsUnpaidLeaveAbsent = 1
			OR dis.IsWeekendLeave = 1
			OR dis.IsSevenDaysLeave = 1
			)
		AND (
			@ReasonId IS NULL
			OR (
				@ReasonId = @ChangeShiftId
				AND dis.IsChangeShift = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @ChangeShiftId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @MissingCheckInOutId
				AND dis.IsMissingCheckInOut = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @MissingCheckInOutId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @LateInId
				AND dis.IsLateIn = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @LateInId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @EarlyOutId
				AND dis.IsEarlyOut = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @EarlyOutId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @AbsentId
				AND dis.IsAbsent = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @AbsentId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @UnplannedLeaveId
				AND dis.IsUnplannedLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @UnplannedLeaveId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @UnpaidLeaveId
				AND dis.IsUnpaidLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @UnpaidLeaveId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @WorkingUnderTimeId
				AND dis.IsWorkingUndertime = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @WorkingUnderTimeId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @UnpaidLeaveAbsentId
				AND dis.IsUnpaidLeaveAbsent = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @UnpaidLeaveAbsentId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @WeekendLeaveId
				AND dis.IsWeekendLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @WeekendLeaveId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @SevenDaysLeaveId
				AND dis.IsSevenDaysLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @SevenDaysLeaveId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (
			EXISTS (
				SELECT 1
				FROM @tblRole
				WHERE RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = emp.EmpId
					AND empS.ActionType = 8 -- edit discipline
					AND empS.EmpId <> @ApproverId
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE gr.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType = 8 -- edit discipline
					AND emp.EmpId <> @ApproverId
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType = 8
							AND ISNULL(empS.IsDeleted, 0) = 0
						)
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = emp.EmpId
					AND empS.ActionType IN (2, 3)
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE emp.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType IN (2, 3)
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType IN (2, 3)
							AND ISNULL(empS.IsDeleted, 0) = 0
						)
				)
			OR (
				EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId = 1 -- Employee
					)
				AND emp.EmpId = @ApproverId
				)
			)
		AND (
			@IsLocal IS NULL
			OR empSum.IsLocal = @IsLocal
			)
		AND (
			@HasIgnored IS NULL
			OR (
				@HasIgnored = 1
				AND (
					(
						dis.IsChangeShift = 1
						AND ignored.IsIgnoredChangeShift = 1
						)
					OR (
						dis.IsMissingCheckInOut = 1
						AND ignored.IsIgnoredMissingCheckInOut = 1
						)
					OR (
						dis.IsLateIn = 1
						AND ignored.IsIgnoredLateIn = 1
						)
					OR (
						dis.IsEarlyOut = 1
						AND ignored.IsIgnoredEarlyOut = 1
						)
					OR (
						dis.IsAbsent = 1
						AND ignored.IsIgnoredAbsent = 1
						)
					OR (
						dis.IsUnplannedLeave = 1
						AND ignored.IsIgnoredUnplannedLeave = 1
						)
					OR (
						dis.IsUnpaidLeave = 1
						AND ignored.IsIgnoredUnpaidLeave = 1
						)
					OR (
						dis.IsWorkingUnderTime = 1
						AND ignored.IsIgnoredWorkingUndertime = 1
						)
					OR (
						dis.IsUnpaidLeaveAbsent = 1
						AND ignored.IsIgnoredUnpaidLeaveAbsent = 1
						)
					OR (
						dis.IsWeekendLeave = 1
						AND ignored.IsIgnoredWeekendLeave = 1
						)
					OR (
						dis.IsSevenDaysLeave = 1
						AND ignored.IsIgnoredSevenDaysLeave = 1
						)
					)
				)
			OR (
				@HasIgnored = 0
				AND (
					(
						dis.IsChangeShift = 1
						AND ignored.IsIgnoredChangeShift = 0
						)
					OR (
						dis.IsMissingCheckInOut = 1
						AND ignored.IsIgnoredMissingCheckInOut = 0
						)
					OR (
						dis.IsLateIn = 1
						AND ignored.IsIgnoredLateIn = 0
						)
					OR (
						dis.IsEarlyOut = 1
						AND ignored.IsIgnoredEarlyOut = 0
						)
					OR (
						dis.IsAbsent = 1
						AND ignored.IsIgnoredAbsent = 0
						)
					OR (
						dis.IsUnplannedLeave = 1
						AND ignored.IsIgnoredUnplannedLeave = 0
						)
					OR (
						dis.IsUnpaidLeave = 1
						AND ignored.IsIgnoredUnpaidLeave = 0
						)
					OR (
						dis.IsWorkingUnderTime = 1
						AND ignored.IsIgnoredWorkingUndertime = 0
						)
					OR (
						dis.IsUnpaidLeaveAbsent = 1
						AND ignored.IsIgnoredUnpaidLeaveAbsent = 0
						)
					OR (
						dis.IsWeekendLeave = 1
						AND ignored.IsIgnoredWeekendLeave = 0
						)
					OR (
						dis.IsSevenDaysLeave = 1
						AND ignored.IsIgnoredSevenDaysLeave = 0
						)
					)
				)
			)
	ORDER BY dis.WorkDate DESC

	SELECT emp.EmpId AS EmployeeId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,empsum.IsLocal
		,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,shift.Code AS ShiftName
		,empatt.InFixed AS CheckIn
		,empatt.OutFixed AS CheckOut
		,empatt.LateIn
		,empatt.EarlyOut
		,empatt.TotalWorkHours AS TotalHours
		,dis.*
	FROM #tblDisciplineDetail AS dis WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON dis.EmployeeId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON dis.EmployeeId = empatt.EmpId
		AND dis.WorkDate = empatt.AttendanceDate
		LEFT JOIN dbo.[Shift] AS shift WITH (NOLOCK) ON empatt.ShiftId = shift.ShiftId
	ORDER BY dis.WorkDate DESC

	SELECT did.EmpId AS EmployeeId
		,e.NickName AS IgnoreBy
		,did.WorkDate
		,did.DisciplineTypeId
		,did.IgnoreDate
	FROM dbo.DisciplineIgnoreDetail AS did WITH (NOLOCK)
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = did.IgnoreBy
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
	WHERE did.EmpId = @EmployeeId AND did.WorkDate BETWEEN @FromDate AND @ToDate
		AND ce.CompanyId = @CompanyId

	DROP TABLE #tblDisciplineDetail

	DROP TABLE #tblGroupIds
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_DisciplineSummary] @FromDate DATE
	,@ToDate DATE
	,@ApproverId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@ReasonId INT = NULL
	,@IsLocal BIT = NULL
	,@IsShowAll BIT = 0
	,@CompanyId SMALLINT
    ,@RoleIds VARCHAR(1000) = ''
AS
/*
Created: 20191204@Tim.Trinh
Task: get discipline summary
DB: HRM

Revisions:
    20250404@Tim: add param @RoleIds [Redmine: #222886]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblGroupIds (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	CREATE TABLE #tblEmployeeDiscipline (
		WorkDate DATE
		,EmpId INT
		,ChangeShift INT
		,MissingCheckInOut INT
		,LateIn INT
		,EarlyOut INT
		,[Absent] INT
		,UnplannedLeave INT
		,WeekendLeave INT
		,UnpaidLeave INT
		,WorkingUnderTime INT
		,UnpaidLeaveAbsent INT
		,SevenDaysLeave INT
		,VerbalWarning INT
		,WrittenWarning INT
		,OtherDiscipline INT
		,OtherDisciplineScore DECIMAL(5, 2)
		)

	INSERT INTO #tblEmployeeDiscipline (
		WorkDate
		,EmpId
		,ChangeShift
		,MissingCheckInOut
		,LateIn
		,EarlyOut
		,[Absent]
		,UnplannedLeave
		,WeekendLeave
		,UnpaidLeave
		,WorkingUnderTime
		,UnpaidLeaveAbsent
		,SevenDaysLeave
		,VerbalWarning
		,WrittenWarning
		,OtherDiscipline
		,OtherDisciplineScore
		)
	SELECT d.WorkDate
		,d.EmpId
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 1 -- change shift
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsChangeShift
			ELSE 0 END
			) AS ChangeShift
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 2 -- missing check in / out
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsMissingCheckInOut
			ELSE 0 END
			) AS MissingCheckInOut
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 3 -- late in
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsLateIn
			ELSE 0 END
			) AS LateIn
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 4 -- early out
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsEarlyOut
			ELSE 0 END
			) AS EarlyOut
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 5 -- absent
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsAbsent
			ELSE 0 END
			) AS [Absent]
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 9 -- unplanned leave
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsUnplannedLeave
			ELSE 0 END
			) AS UnplannedLeave
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 10 -- weekend leave
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsWeekendLeave
			ELSE 0 END
			) AS WeekendLeave
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 6 -- unpaid leave
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsUnpaidLeave
			ELSE 0 END
			) AS UnpaidLeave
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 7 -- working under time
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsWorkingUndertime
			ELSE 0 END
			) AS WorkingUnderTime
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 8 -- unpaid leave absent
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsUnpaidLeaveAbsent
			ELSE 0 END
			) AS UnpaidLeaveAbsent
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 11 -- seven days leave
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsSevenDaysLeave
			ELSE 0 END
			) AS SevenDaysLeave
		,0 AS VerbalWarning
		,0 AS WrittenWarning
		,0 AS OtherDiscipline
		,0 AS OtherDisciplineScore
	FROM dbo.Discipline AS d WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON d.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
	WHERE d.WorkDate BETWEEN @FromDate
			AND @ToDate
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
        AND d.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR emp.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)
	
	UNION ALL
	SELECT dis.WorkDate
		,dis.EmpId
		,0 AS ChangeShift
		,0 AS MissingCheckInOut
		,0 AS LateIn
		,0 AS EarlyOut
		,0 AS [Absent]
		,0 AS UnplannedLeave
		,0 AS WeekendLeave
		,0 AS UnpaidLeave
		,0 AS WorkingUnderTime
		,0 AS UnpaidLeaveAbsent
		,0 AS SevenDaysLeave
		,(CASE 
			WHEN dis.DisciplineTypeId = - 1 THEN 1
			ELSE 0 END
			) AS VerbalWarning
		,(CASE 
			WHEN dis.DisciplineTypeId = - 2 THEN 1
			ELSE 0 END
			) AS WrittenWarning
		,(CASE 
			WHEN dis.DisciplineTypeId = - 3 THEN 1
			ELSE 0 END
			) AS OtherDiscipline
		,dis.Score AS OtherDisciplineScore
	FROM dbo.OtherDiscipline AS dis WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON dis.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
	WHERE dis.WorkDate BETWEEN @FromDate
			AND @ToDate
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
        AND dis.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR emp.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)

	CREATE TABLE #tblEmployeeDisciplineFinalScore (
		WorkDate DATE
		,EmpId INT
		,SystemSubtractScore FLOAT
		,ApproverSubtractScore FLOAT
		)

	INSERT INTO #tblEmployeeDisciplineFinalScore (
		WorkDate
		,EmpId
		,SystemSubtractScore
		,ApproverSubtractScore
		)
	SELECT tbldis.WorkDate
		,tbldis.EmpId
		,(tbldis.ChangeShift * dbo.fncGetDisciplineScoreById(1)
		  + tbldis.MissingCheckInOut * dbo.fncGetDisciplineScoreById(2)
		  + tbldis.LateIn * dbo.fncGetDisciplineScoreById(3)
		  + tbldis.EarlyOut * dbo.fncGetDisciplineScoreById(4)
		  + tbldis.[Absent] * dbo.fncGetDisciplineScoreById(5)
		  + tbldis.UnpaidLeave * dbo.fncGetDisciplineScoreById(6)
		  + tbldis.WorkingUnderTime * dbo.fncGetDisciplineScoreById(7)
		  + tbldis.UnpaidLeaveAbsent * dbo.fncGetDisciplineScoreById(8)
		  + tbldis.UnplannedLeave * dbo.fncGetDisciplineScoreById(9)
		  + tbldis.WeekendLeave * dbo.fncGetDisciplineScoreById(10)
		  + tbldis.SevenDaysLeave * dbo.fncGetDisciplineScoreById(11)) AS SystemSubtractScore
		,CASE 
			WHEN ignored.ApproverSubtractScore IS NOT NULL THEN ignored.ApproverSubtractScore
			ELSE 0
			END
	FROM #tblEmployeeDiscipline AS tbldis WITH (NOLOCK)
		OUTER APPLY (
		SELECT dis.EmpId
			,dis.WorkDate
			,(
				(CASE 
					WHEN dis.IsChangeShift = 1
						AND ignored.IsIgnoredChangeShift = 0 THEN dbo.fncGetDisciplineScoreById(1)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsMissingCheckInOut = 1
						AND ignored.IsIgnoredMissingCheckInOut = 0 THEN dbo.fncGetDisciplineScoreById(2)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsLateIn = 1
						AND ignored.IsIgnoredLateIn = 0 THEN dbo.fncGetDisciplineScoreById(3)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsEarlyOut = 1
						AND ignored.IsIgnoredEarlyOut = 0 THEN dbo.fncGetDisciplineScoreById(4)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsAbsent = 1
						AND ignored.IsIgnoredAbsent = 0 THEN dbo.fncGetDisciplineScoreById(5)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnplannedLeave = 1
						AND ignored.IsIgnoredUnplannedLeave = 0 THEN dbo.fncGetDisciplineScoreById(9)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnpaidLeave = 1
						AND ignored.IsIgnoredUnpaidLeave = 0 THEN dbo.fncGetDisciplineScoreById(6)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsWorkingUndertime = 1
						AND ignored.IsIgnoredWorkingUndertime = 0 THEN dbo.fncGetDisciplineScoreById(7)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnpaidLeaveAbsent = 1
						AND ignored.IsIgnoredUnpaidLeaveAbsent = 0 THEN dbo.fncGetDisciplineScoreById(8)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsWeekendLeave = 1
						AND ignored.IsIgnoredWeekendLeave = 0 THEN dbo.fncGetDisciplineScoreById(10)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsSevenDaysLeave = 1
						AND ignored.IsIgnoredSevenDaysLeave = 0 THEN dbo.fncGetDisciplineScoreById(11)
					ELSE 0 END
					)
				) AS ApproverSubtractScore
		FROM dbo.Discipline AS dis WITH (NOLOCK)
			INNER JOIN dbo.DisciplineIgnore AS ignored WITH (NOLOCK) ON dis.EmpId = ignored.EmpId
			AND dis.WorkDate = ignored.WorkDate
		WHERE ignored.EmpId = tbldis.EmpId
			AND ignored.WorkDate = tbldis.WorkDate
		) AS ignored
	WHERE (
			tbldis.[Absent] > 0
			OR tbldis.UnplannedLeave > 0
			OR tbldis.WeekendLeave > 0
			OR tbldis.ChangeShift > 0
			OR tbldis.EarlyOut > 0
			OR tbldis.LateIn > 0
			OR tbldis.UnpaidLeave > 0
			OR tbldis.WorkingUnderTime > 0
			OR tbldis.UnpaidLeaveAbsent > 0
			OR tbldis.MissingCheckInOut > 0
			OR tbldis.SevenDaysLeave > 0
			)
		AND tbldis.OtherDisciplineScore = 0

	DECLARE @Is_HR_SA BIT
	DECLARE @tblRole TABLE (RoleId INT)

	INSERT INTO @tblRole (RoleId)
	SELECT value
	FROM STRING_SPLIT(@RoleIds, ',')

	SET @Is_HR_SA = CASE 
			WHEN EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
					) THEN 1
			ELSE 0
			END

	SELECT SUM(ISNULL(empD.ChangeShift, 0)) AS ChangeShift
		,SUM(ISNULL(empD.MissingCheckInOut, 0)) AS MissingCheckInOut
		,SUM(ISNULL(empD.LateIn, 0)) AS LateIn
		,SUM(ISNULL(empD.EarlyOut, 0)) AS EarlyOut
		,SUM(ISNULL(empD.[Absent], 0)) AS [Absent]
		,SUM(ISNULL(empD.UnplannedLeave, 0)) AS UnplannedLeave
		,SUM(ISNULL(empD.WeekendLeave, 0)) AS WeekendLeave
		,SUM(ISNULL(empD.UnpaidLeave, 0)) AS UnpaidLeave
		,SUM(ISNULL(empD.WorkingUnderTime, 0)) AS WorkingUnderTime
		,SUM(ISNULL(empD.UnpaidLeaveAbsent, 0)) AS UnpaidLeaveAbsent
		,SUM(ISNULL(empD.SevenDaysLeave, 0)) AS SevenDaysLeave
		,SUM(ISNULL(empD.OtherDisciplineScore, 0)) AS OtherDisciplineScore
		,SUM(ISNULL(empD.OtherDisciplineScore, 0) + ISNULL(empF.SystemSubtractScore, 0)) AS SystemSubtractScore
		,SUM(ISNULL(empD.OtherDisciplineScore, 0) + ISNULL(empF.ApproverSubtractScore, 0)) AS ApproverSubtractScore
		,Permission = (CASE 
			WHEN EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId = 8 -- edit discipline
					)
				AND (
					EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId = @ApproverId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType = 8 -- edit discipline
							AND empS.EmpId <> @ApproverId
							AND ISNULL(empS.IsDeleted, 0) = 0
						)
					OR EXISTS (
						SELECT 1
						FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
						WHERE gr.GroupId = grS.GroupId
							AND @ApproverId = grS.OwnerId
							AND grS.ActionType = 8 -- edit discipline
							-- AND emp.EmpId <> @ApproverId
							AND ISNULL(grS.IsDeleted, 0) = 0
							AND NOT EXISTS (
								SELECT 1
								FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
								WHERE empS.OwnerId <> @ApproverId
									AND empS.EmpId = emp.EmpId
									AND empS.ActionType = 8
									AND ISNULL(empS.IsDeleted, 0) = 0
								)
						)
					) THEN 2 -- Host
			ELSE 1 END
			)
		,emp.EmpId AS EmployeeId
		,emp.NickName
		,emp.FullName
		,emp.Code
		,empSum.IsLocal
		,gr.GroupId AS TeamId
		,gr.[Name] AS TeamName
		,gr.Code AS TeamCode
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN #tblEmployeeDiscipline AS empD WITH (NOLOCK) ON emp.EmpId = empD.EmpId
		LEFT JOIN #tblEmployeeDisciplineFinalScore AS empF WITH (NOLOCK) ON empF.WorkDate = empD.WorkDate
		AND empF.EmpId = empD.EmpId
	WHERE emp.[Enabled] = 1
		AND emp.IsDeleted = 0
		AND ce.CompanyId = @CompanyId
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR emp.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)
		AND (
			@IsShowAll = 1
			OR (
				@IsShowAll = 0
				AND EXISTS (
					SELECT 1
					FROM #tblEmployeeDiscipline WITH (NOLOCK)
					WHERE emp.EmpId = EmpId
					)
				)
			)
		AND (
			@Is_HR_SA = 1 -- SA, HR can view all member of company
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = emp.EmpId
					AND empS.ActionType = 8 -- edit discipline
					AND empS.EmpId <> @ApproverId
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE gr.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType = 8 -- edit discipline
					AND emp.EmpId <> @ApproverId
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType = 8
							AND ISNULL(emps.IsDeleted, 0) = 0
						)
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = emp.EmpId
					AND empS.ActionType IN (2, 3) -- Approver and Verifier
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE gr.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType IN (2, 3) -- Approver and Verifier
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType IN (2, 3)
							AND ISNULL(emps.IsDeleted, 0) = 0
						)
				)
			OR (
				EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId = 1 -- Employee
					)
				AND emp.EmpId = @ApproverId
				)
			)
		AND (
			ISNULL(@ReasonId, '') = ''
			OR (
				@ReasonId = 1
				AND empD.ChangeShift > 0
				)
			OR (
				@ReasonId = 2
				AND empD.MissingCheckInOut > 0
				)
			OR (
				@ReasonId = 3
				AND empD.LateIn > 0
				)
			OR (
				@ReasonId = 4
				AND empD.EarlyOut > 0
				)
			OR (
				@ReasonId = 5
				AND empD.[Absent] > 0
				)
			OR (
				@ReasonId = 9
				AND empD.UnplannedLeave > 0
				)
			OR (
				@ReasonId = 10
				AND empD.WeekendLeave > 0
				)
			OR (
				@ReasonId = 6
				AND empD.UnpaidLeave > 0
				)
			OR (
				@ReasonId = 7
				AND empD.WorkingUnderTime > 0
				)
			OR (
				@ReasonId = 8
				AND empD.UnpaidLeaveAbsent > 0
				)
			OR (
				@ReasonId = 11
				AND empD.SevenDaysLeave > 0
				)
			OR (
				@ReasonId = - 1
				AND empD.VerbalWarning > 0
				)
			OR (
				@ReasonId = - 2
				AND empD.WrittenWarning > 0
				)
			OR (
				@ReasonId = - 3
				AND empD.OtherDiscipline > 0
				)
			)
	GROUP BY empD.EmpId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,emp.Code
		,empSum.IsLocal
		,gr.GroupId
		,gr.[Name]
		,gr.Code
	ORDER BY Permission DESC
		,gr.[Name] ASC
		,emp.Code ASC

	DROP TABLE #tblEmployeeDiscipline

	DROP TABLE #tblEmployeeDisciplineFinalScore

	DROP TABLE #tblGroupIds
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetRequestByCreateDate_AllType] @SupervisorID INT = NULL
	,@empid INT = NULL
	,@TeamIds VARCHAR(max) = ''
	,@fromdate DATETIME
	,@todate DATETIME
	,@status VARCHAR(max) = NULL
	,@role VARCHAR(max) = ''
	,@isLocal BIT = NULL
	,@requestType INT = NULL
	,@leaveTypeId INT = NULL
	,@CompanyId SMALLINT
AS
/*
Created: Tom.Vo@2013-11-04
Task: Get Request By Date
DB: HRM

Revisions:
    20250403@Tim: remove section [Redmine: #222886]
Param's Explanation:
*/
BEGIN
	CREATE TABLE #tblstatus (Currentstatus TINYINT)

	CREATE TABLE #tblGroupsList (GroupId INT PRIMARY KEY)

	CREATE TABLE #tblEmployeeId (EmpId INT PRIMARY KEY)

	CREATE TABLE #tblRequestId (RequestId INT PRIMARY KEY)

	CREATE TABLE #tblTotalDaysRequestInMonth (
		EmpId INT
		,RequestType TINYINT
		,TotalDaysRequest INT
		)

	CREATE TABLE #tblRequestInDaily (
		RequestID BIGINT
		,EmpId INT
		,RequestType TINYINT
		,InOutMins INT
		,ActualInOutMins INT
		,RequestedTime DATETIME
		,FromDate DATETIME
		,ToDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 1)
		,IsHalfDay BIT
		,IsWarning BIT
		,KeepInViewType TINYINT
		)

	CREATE TABLE #tblGeneralLeaveDetail (
		RequestId BIGINT
		,LeaveCountDetails NVARCHAR(MAX)
		)

	IF ISNULL(@status, '') <> ''
	BEGIN
		INSERT INTO #tblstatus (Currentstatus)
		SELECT value
		FROM STRING_SPLIT(@status, ',')
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupsList (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empid IS NULL
	BEGIN
		IF @SupervisorID IS NULL
			OR @role LIKE '%6%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpID)
			SELECT e.EmpId
			FROM dbo.Employee AS e WITH (NOLOCK)
		END
		ELSE IF @role LIKE '%2%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			EXEC dbo.Request_GetMemberByActorId @EmpId = @SupervisorId
				,@ExcludeUserDelete = 1
				,@IsShowUserInTeam = 0
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 1, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeId (EmpID)
		VALUES (@empid)
	END

	INSERT INTO #tblRequestId (RequestId)
	SELECT r.RequestId
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS eid WITH (NOLOCK) ON r.EmpId = eid.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = eid.empID
		AND e.isDeleted = 0
		LEFT JOIN dbo.EmployeeSummary AS e_s WITH (NOLOCK) ON e_s.EmpId = eid.EmpId
	WHERE (
			@requestType = 0
			OR (
				@requestType = 1
				AND r.RequestType IN (1, 2)
				)
			OR (
				@requestType = 2
				AND r.RequestType IN (3, 4)
				)
			OR (
				@requestType = 3
				AND r.RequestType = 5
				)
			OR (
				@requestType = 4
				AND r.RequestType = 6
				)
			OR (
				@requestType = 5
				AND r.RequestType = 7
				)
			)
		AND (
			(
				@empid IS NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
						WHERE tblemp.EmpId = r.EmpId
						)
					OR r.VerifierId = @SupervisorID
					OR r.ApproverId = @SupervisorID
					)
				)
			OR (
				@empid IS NOT NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
						WHERE tblemp.EmpId = r.EmpId
						)
					)
				)
			)
		AND (
			ISNULL(@status, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tblstatus AS tblstatus WITH (NOLOCK)
				WHERE tblstatus.Currentstatus = r.CurrentStatus
				)
			)
		AND (
			e.GroupId IS NULL
			OR EXISTS (
				SELECT 1
				FROM #tblGroupsList AS tblgr WITH (NOLOCK)
				WHERE tblgr.GroupId = e.GroupId
				)
			)
		AND (
			@isLocal IS NULL
			OR e_s.IsLocal = @isLocal
			)
		AND r.CreatedDate BETWEEN @fromdate
			AND @todate

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND EXISTS (
			SELECT 1
			FROM #tblGroupsList AS tblgr WITH (NOLOCK)
			WHERE tblgr.GroupId = ee.GroupId
			)
		AND (
			DATEDIFF(MM, inout.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, inout.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND EXISTS (
			SELECT GroupId
			FROM #tblGroupsList AS tblgr WITH (NOLOCK)
			WHERE tblgr.GroupId = ee.GroupId
			)
		AND (
			DATEDIFF(MM, lr.FromDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(MM, cs.FromDate, @fromdate) = 0
			OR DATEDIFF(MM, cs.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT @empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE wt.EmpId = @empid
		AND wt.currentstatus = 6
		AND (
			DATEDIFF(MM, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND EXISTS (
			SELECT GroupId
			FROM #tblGroupsList AS tblgr WITH (NOLOCK)
			WHERE tblgr.GroupId = ee.GroupId
			)
		AND (
			DATEDIFF(MM, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,ActualInOutMins
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,inout.OnDate
		,inout.OnDate
		,0
		,CASE 
			WHEN wt.RequestType = 3 THEN inout.LateInMins
			ELSE inout.EarlyOutMins
			END
		,CASE 
			WHEN wt.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON inout.EmpId = att.EmpId
		AND inout.OnDate = att.AttendanceDate

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,CASE 
			WHEN ldt.FromTime IS NULL THEN lr.FromDate
			ELSE ldt.FromTime
			END
		,CASE 
			WHEN ldt.ToTime IS NULL THEN lr.ToDate
			ELSE ldt.ToTime
			END
		,lr.TotalDays
		,1
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
	WHERE lr.TotalDays = 0.5
		AND ldt.IsHalfDay = 1

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,0
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE lr.TotalDays <> 0.5

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,FromShift
		,ToShift
		,KeepInViewType
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.OnDate
		,lr.OnDate
		,lr.OnDate
		,lr.FromTime
		,lr.ToTime
		,CASE 
			WHEN lr.IsHalfDay = 0 THEN 1
			ELSE 0.5
			END TotalDays
		,NULL
		,NULL
		,lr.KeepInViewType
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,IsWarning
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftId
		,CASE 
			WHEN ISNULL(att.TotalWorkHours, 0) = 0 THEN 1
			ELSE 0
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON lr.OnDate = att.AttendanceDate
		AND lr.EmpId = att.EmpId
	WHERE wt.CurrentStatus = 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftId
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
	WHERE wt.CurrentStatus <> 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate
		,count(1) TotalDays
		,MAX(csd.FromShift) FromShift
		,MAX(csd.ToShift) ToShift
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
		INNER JOIN dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK) ON csd.RequestId = cs.RequestId
	GROUP BY wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate

	INSERT INTO #tblGeneralLeaveDetail (
		RequestId
		,LeaveCountDetails
		)
	SELECT DISTINCT wt.RequestId
		,STUFF((
				SELECT ', ' + (
						CAST(SUM(CASE 
									WHEN rd1.IsHalfDay = 0 THEN 1
									ELSE 0.5
									END) AS NVARCHAR(100)) + ' days ' + lt1.Code
						)
				FROM dbo.LeaveRequestDetail AS rd1 WITH (NOLOCK)
					INNER JOIN dbo.LeaveType AS lt1 WITH (NOLOCK) ON lt1.LeaveTypeId = rd1.LeaveType
                    AND lt1.CompanyId = @CompanyId
				WHERE rd1.RequestId = rd.RequestId
					AND rd1.LeaveType <> 0
				GROUP BY rd1.RequestId
					,rd1.LeaveType
					,lt1.Code
				FOR XML PATH('')
				), 1, 2, '') AS LeaveCountDetails
	FROM (
		SELECT rq.RequestId
			,CreatedDate
			,EmpId
		FROM dbo.WorkingTimeRequest AS rq WITH (NOLOCK)
			INNER JOIN #tblRequestId AS r WITH (NOLOCK) ON r.RequestId = rq.RequestId
		) AS wt
		INNER JOIN #tblRequestInDaily AS rd WITH (NOLOCK) ON wt.RequestId = rd.RequestID
		INNER JOIN #tblRequestId AS r1 WITH (NOLOCK) ON r1.RequestId = rd.RequestId
	ORDER BY wt.RequestId

	SELECT r.RequestId
		,r.RequestType
		,r.Currentstatus AS [Status]
		,r.empID
		,rd.FromDate
		,rd.ToDate
		,rd.TotalDays
		,rd.IsHalfDay
		,rd.RequestedTime AS RequestedDate
		,rd.FromTime
		,rd.ToTime
		,rd.KeepInViewType
		,gdt.LeaveCountDetails
		,lv.LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,r.Remark
		,ISNULL(rm.TotalDaysRequest, 0) TotalDaysRequestInMonth
		,CASE 
			WHEN r.RequestType IN (1, 2) THEN inoutmiss.ReasonId
			WHEN r.RequestType IN (3, 4) THEN inout.ReasonId
			ELSE 0
			END [ReasonId]
		,CASE 
			WHEN r.RequestType IN (1, 2, 6, 7) THEN lr.RefNo
			WHEN r.RequestType IN (3, 4) THEN inout.RefNo
			WHEN r.RequestType IN (5) THEN NULL
			END RefNo
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN s1.ShiftID
			ELSE s3.ShiftID END
			) AS FromShiftId
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShiftName
		,s2.ShiftID AS ToShiftId
		,(CASE 
			WHEN s2.ShiftID IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShiftName
		,s2.[Name] AS ToShiftName
		,csr.TypeId AS ChangeShiftType
		,rd.InOutMins AS TotalMinutes
		,rd.ActualInOutMins
		,r.CreatedDate
		,e.EmpId AS RequesterId
		,e.NickName AS RequesterNickName
		,e.FullName AS RequesterFullName
		,g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dep.DepartmentId
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,verifier.EmpId AS VerifierId
		,verifier.NickName AS VerifierNickName
		,verifier.FullName AS VerifierFullName
		,r.VerifiedDate
		,r.VerifiedStatus
		,approver.EmpId AS ApproverId
        ,approver.NickName AS ApproverNickName
		,approver.FullName AS ApproverFullName
		,r.ApprovedDate
		,r.ApprovedStatus
		,hr.NickName AS ProcessedByNickName
		,hr.FullName AS ProcessedByFullName
		,r.HRDate AS ProcessedDate
		,r.HRStatus AS ProcessedStatus
		,r.ModifiedDate
		,ISNULL(rd.IsWarning, 0) AS IsWarning
		,r.ReworkCount
		,dbo.fnc_GetAnnualLeaveBalanceByYear(r.EmpId, YEAR(rd.FromDate), r.RequestId) AS AnnualLeaveBalance
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblRequestInDaily AS rd WITH (NOLOCK) ON r.RequestId = rd.RequestID
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON r.RequestId = rq.RequestId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = r.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = r.empID
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.empid = r.VerifierId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.empid = r.ApproverId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.empid = r.HRId
		LEFT JOIN #tblTotalDaysRequestInMonth AS rm ON r.empID = rm.empid
		AND r.RequestType = rm.RequestType
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS C WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftID = rd.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftID = rd.ToShift
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftID = c.ShiftID
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeID = lr.LeaveType
        AND lv.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId 
		AND (@leaveTypeId IS NULL OR lr.LeaveType = @leaveTypeId)
	ORDER BY r.CreatedDate DESC

	SELECT csrd.RequestId
		,csrd.OnDate
		,csrd.ToDate
	FROM #tblRequestId AS r WITH (NOLOCK)
		INNER JOIN ChangeShiftRequest AS csr WITH (NOLOCK) ON csr.RequestId = r.RequestId
		INNER JOIN ChangeShiftRequestDetail AS csrd WITH (NOLOCK) ON csr.RequestId = csrd.RequestId

	DROP TABLE #tblstatus

	DROP TABLE #tblGroupsList

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblTotalDaysRequestInMonth

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestId
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Overtime_GetMemberMonthlyRequest] @ActorId INT
	,@EmployeeId INT = NULL
	,@TeamIds VARCHAR(MAX) = NULL
	,@Month DATE = NULL
	,@StatusIds VARCHAR(MAX) = NULL
	,@IsProcessor BIT = 0
	,@OvertimeType SMALLINT = NULL
	,@IsLocal BIT = NULL
	,@CompanyId INT 
AS
/*
Created: Tim.Trinh@2019-07-05
Task: Get member overtime request
DB: HRM

Revisions:
    20250403@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	-- request status
	DECLARE @PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7
	-- overtime type
		,@ALLOvertimeType TINYINT = 0
		,@NormalDay TINYINT = 1
		,@OffDay TINYINT = 2
		,@PublicHoliday TINYINT = 3
		,@SpecialOT TINYINT = 4

	DECLARE @tblStatusIds TABLE (StatusId TINYINT)

	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	CREATE TABLE #tblGroupIds (GroupId INT)

	CREATE TABLE #tblOvertimeType (RequestId INT)

	INSERT INTO #tblOvertimeType (RequestId)
	SELECT otmr.RequestId
	FROM dbo.OTMonthlyRequest AS otmr WITH (NOLOCK)
	WHERE @OvertimeType = @ALLOvertimeType
		OR (@OvertimeType = @NormalDay AND otmr.NormalHours > 0)
		OR (@OvertimeType = @OffDay AND otmr.OffHours > 0)
		OR (@OvertimeType = @PublicHoliday AND otmr.PublicHours > 0)
		OR (@OvertimeType = @SpecialOT AND otmr.SpecialHours > 0)

	IF @EmployeeId IS NULL
	BEGIN
		IF @IsProcessor = 1
		BEGIN
			INSERT INTO #tblEmployeeIds (EmployeeId)
			SELECT emp.EmpId
			FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON emp.EmpId = c.EmpId
			WHERE emp.[Enabled] = 1
				AND emp.isDeleted = 0
				AND c.CompanyId = @CompanyId
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeIds (EmployeeId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 1, 0, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeIds (EmployeeId)
		VALUES (@EmployeeId)
	END

	INSERT INTO @tblStatusIds (StatusId)
	SELECT value
	FROM STRING_SPLIT(@StatusIds, ',')

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END
	
	SELECT req.RequestId
		,req.[Month]
		,req.NormalHours
		,req.OffHours
		,req.PublicHours
		,req.SpecialHours
		,(CASE 
			WHEN att.RequestId IS NOT NULL THEN 1
			ELSE 0 END
			) IsWarning
		,(CASE 
			WHEN (
					@IsProcessor = 0
					AND req.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @NotVerifiedStatusId, @ApprovedStatusId, @RejectedStatusId)
					AND (
						verifier.EmpId = @ActorId
						OR approver.EmpId = @ActorId
						)
					)
				OR @IsProcessor = 1 THEN 1
			ELSE 0 END
			) AS IsHost
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,verifier.EmpId AS VerifierId
		,verifier.NickName AS VerifierNickname
		,verifier.FullName AS VerifierFullName
		,approver.EmpId AS ApproverId
		,approver.NickName AS ApproverNickname
		,approver.FullName AS ApproverFullName
		,req.CurrentStatus AS StatusId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
	FROM dbo.OTMonthlyRequest AS req WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds e WITH (NOLOCK) ON req.EmpId = e.EmployeeId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON req.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN #tblGroupIds AS tblgr WITH (NOLOCK) ON gr.GroupId = tblgr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = req.VerifierId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = req.ApproverId
		LEFT JOIN (
		SELECT DISTINCT ot.RequestId
		FROM dbo.OTDailyRequest AS ot WITH (NOLOCK)
			LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON ot.Schedule = s.ShiftId
			LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON empatt.AttendanceDate = ot.OvertimeDate
			AND empatt.EmpId = ot.EmpId
		WHERE ot.TotalHours - ISNULL(empatt.LateIn, 0) / 60 >= s.TotalHours + 1
		) AS att ON att.RequestId = req.RequestId
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
        AND (
			@Month IS NULL
			OR req.[Month] = @Month
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND EXISTS (
			SELECT 1
			FROM @tblStatusIds AS tbl
			WHERE req.CurrentStatus = tbl.StatusId
			)
		AND EXISTS (
			SELECT 1
			FROM #tblOvertimeType AS ovt
			WHERE req.RequestId = ovt.RequestId
			)
	ORDER BY IsHost DESC
		,StatusId
		,req.[Month] DESC
		,emp.NickName

	DROP TABLE #tblEmployeeIds

	DROP TABLE #tblGroupIds

	DROP TABLE #tblOvertimeType
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetRequestByRequestDate_AllType] @SupervisorId INT = NULL
	,@empid INT = NULL
	,@TeamIds VARCHAR(max) = ''
	,@fromdate DATETIME
	,@todate DATETIME
	,@status VARCHAR(max) = NULL
	,@role VARCHAR(max) = ''
	,@isLocal BIT = NULL
	,@requestType INT = NULL
	,@leaveTypeId INT = NULL
	,@CompanyId SMALLINT
AS
/*
Created: Tom.Vo@2013-11-04
Task: get all emp request list
DB: HRM

Revisions:
    20250403@Tim: remove section [Redmine: #222886]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	-- work type
	DECLARE @OffDay TINYINT = 1
		,@LeaveDay TINYINT = 2
		,@Onduty TINYINT = 3

	CREATE TABLE #tblstatus (Currentstatus TINYINT)

	CREATE TABLE #tblGroupsList (GroupId INT)

	CREATE TABLE #tblEmployeeId (EmpId INT)

	CREATE TABLE #tblRequestId (RequestId INT)

	CREATE TABLE #tblTotalDaysRequestInMonth (
		empid INT
		,RequestType TINYINT
		,TotalDaysRequest INT
		)

	CREATE TABLE #tblRequestInDaily (
		RequestId BIGINT
		,empid INT
		,RequestType TINYINT
		,InOutMins INT
		,ActualInOutMins INT
		,RequestedTime DATETIME
		,FromDate DATETIME
		,ToDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 1)
		,IsHalfDay BIT
		,IsWarning BIT
		,KeepInViewType TINYINT
		)

	CREATE TABLE #tblGeneralLeaveDetail (
		RequestId BIGINT
		,LeaveCountDetails NVARCHAR(MAX)
		)

	IF ISNULL(@status, '') <> ''
	BEGIN
		INSERT INTO #tblstatus (Currentstatus)
		SELECT value
		FROM STRING_SPLIT(@status, ',')
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupsList (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empid IS NULL
	BEGIN
		IF @SupervisorId IS NULL
			OR @role LIKE '%6%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpID)
			SELECT DISTINCT e.EmpId
			FROM dbo.Employee AS e WITH (NOLOCK)
		END
		ELSE IF @role LIKE '%2%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			EXEC dbo.Request_GetMemberByActorId @EmpId = @SupervisorId
				,@ExcludeUserDelete = 1
				,@IsShowUserInTeam = 0
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 1, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeId (EmpId)
		VALUES (@empid)
	END

	INSERT INTO #tblRequestId (RequestId)
	SELECT r.RequestId
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS eid ON r.EmpId = eid.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = eid.empID
		AND e.isDeleted = 0
		INNER JOIN dbo.EmployeeSummary AS e_s WITH (NOLOCK) ON e_s.EmpId = eid.EmpId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.KeepInViewRequest AS ke WITH (NOLOCK) ON r.RequestId = ke.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS mi WITH (NOLOCK) ON r.RequestId = mi.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
	WHERE (
			@requestType = 0
			OR (
				@requestType = 1
				AND r.RequestType IN (1, 2)
				)
			OR (
				@requestType = 2
				AND r.RequestType IN (3, 4)
				)
			OR (
				@requestType = 3
				AND r.RequestType = 5
				)
			OR (
				@requestType = 4
				AND r.RequestType = 6
				)
			OR (
				@requestType = 5
				AND r.RequestType = 7
				)
			)
		AND (
			(
				@empid IS NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId WITH (NOLOCK)
						WHERE EmpId = r.EmpId
						)
					OR r.VerifierId = @SupervisorID
					OR r.ApproverId = @SupervisorID
					)
				)
			OR (
				@empid IS NOT NULL
				AND EXISTS (
					SELECT 1
					FROM #tblEmployeeId WITH (NOLOCK)
					WHERE EmpId = r.EmpId
					)
				)
			)
		AND (
			ISNULL(@status, '') = ''
			OR r.currentstatus IN (
				SELECT Currentstatus
				FROM #tblstatus WITH (NOLOCK)
				)
			)
		AND (
			e.GroupId IS NULL
			OR e.GroupId IN (
				SELECT GroupId
				FROM #tblGroupsList WITH (NOLOCK)
				)
			)
		AND (
			@isLocal IS NULL
			OR e_s.IsLocal = @isLocal
			)
		AND (
			(
				r.RequestType IN (3, 4)
				AND (
					inout.OnDate BETWEEN @fromdate
						AND @todate
					)
				)
			OR (
				r.RequestType = 6
				AND (
					(
						lr.FromDate >= @fromdate
						AND lr.FromDate <= @todate
						AND lr.ToDate >= @todate
						)
					OR (
						lr.FromDate <= @fromdate
						AND lr.ToDate >= @todate
						)
					OR lr.ToDate BETWEEN @fromdate
						AND @todate
					)
				)
			OR (
				r.RequestType = 7
				AND ke.OnDate BETWEEN @fromdate
					AND @todate
				)
			OR (
				r.RequestType IN (1, 2)
				AND mi.OnDate BETWEEN @fromdate
					AND @todate
				)
			OR (
				r.RequestType = 5
				AND (
					(
						cs.FromDate >= @fromdate
						AND cs.FromDate <= @todate
						AND cs.ToDate >= @todate
						)
					OR (
						cs.FromDate <= @fromdate
						AND cs.FromDate <= @todate
						AND cs.ToDate >= @todate
						)
					OR cs.ToDate BETWEEN @fromdate
						AND @todate
					)
				)
			)
		AND (
			@leaveTypeId IS NULL
			OR lr.LeaveType = @leaveTypeId
			)

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND ee.GroupId IN (
			SELECT GroupId
			FROM #tblGroupsList
			)
		AND (
			DATEDIFF(M, inout.OnDate, @fromdate) = 0
			OR DATEDIFF(M, inout.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND ee.GroupId IN (
			SELECT GroupId
			FROM #tblGroupsList
			)
		AND (
			DATEDIFF(M, lr.FromDate, @fromdate) = 0
			OR DATEDIFF(M, lr.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(M, cs.FromDate, @fromdate) = 0
			OR DATEDIFF(M, cs.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT @empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE wt.EmpId = @empid
		AND wt.currentstatus = 6
		AND DATEDIFF(M, lr.OnDate, @fromdate) = 0
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequest lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND ee.GroupId IN (
			SELECT GroupId
			FROM #tblGroupsList
			)
		AND (
			DATEDIFF(M, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(M, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,ActualInOutMins
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,inout.OnDate
		,inout.OnDate
		,0
		,CASE 
			WHEN wt.RequestType = 3 THEN inout.LateInMins
			ELSE inout.EarlyOutMins
			END
		,CASE 
			WHEN wt.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON inout.EmpId = att.EmpId
		AND inout.OnDate = att.AttendanceDate

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,CASE 
			WHEN ldt.FromTime IS NULL THEN lr.FromDate
			ELSE ldt.FromTime
			END
		,CASE 
			WHEN ldt.ToTime IS NULL THEN lr.ToDate
			ELSE ldt.ToTime
			END
		,lr.TotalDays
		,1
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
	WHERE lr.TotalDays = 0.5
		AND ldt.IsHalfDay = 1

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,0
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE lr.TotalDays <> 0.5

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,FromShift
		,ToShift
		,IsHalfDay
		,KeepInViewType
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.OnDate
		,lr.OnDate
		,lr.OnDate
		,lr.FromTime
		,lr.ToTime
		,CASE 
			WHEN lr.IsHalfDay = 0 THEN 1
			ELSE 0.5
			END TotalDays
		,NULL
		,NULL
		,lr.IsHalfDay
		,lr.KeepInViewType
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,IsWarning
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftID
		,CASE 
			WHEN ISNULL(att.TotalWorkHours, 0) = 0 THEN 1
			ELSE 0
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON lr.OnDate = att.AttendanceDate
		AND lr.EmpId = att.EmpId
	WHERE wt.CurrentStatus = 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftID
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
	WHERE wt.CurrentStatus <> 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate
		,COUNT(1) TotalDays
		,MAX(csd.FromShift) FromShift
		,MAX(csd.ToShift) ToShift
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
		INNER JOIN dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK) ON csd.RequestId = cs.RequestId
	GROUP BY wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate

	INSERT INTO #tblGeneralLeaveDetail (
		RequestId
		,LeaveCountDetails
		)
	SELECT DISTINCT wt.RequestId
		,STUFF((
				SELECT ', ' + CAST(SUM(LeaveDay) AS NVARCHAR(100)) + CASE 
						WHEN SUM(LeaveDay) > 1 THEN ' days '
						ELSE ' day '
						END + Code
				FROM (
					SELECT RequestId
						,CASE 
							WHEN IsOffDay = 1 THEN 'Off'
							ELSE CASE 
									WHEN IsHoliday = 1 THEN 'PH'
									ELSE Code
									END
							END AS Code
						,CASE 
							WHEN IsOffDay <> 1
								AND IsHoliday <> 1 THEN LeaveDay
							ELSE 1
							END AS LeaveDay
					FROM (
						SELECT ldt.RequestId
							,ldt.LeaveType AS LeaveTypeId
							,lt1.Code
							,CASE 
								WHEN ldt.LeaveType <> 0
									AND ldt.IsHalfDay = 0 THEN 1
								WHEN ldt.LeaveType <> 0
									AND ldt.IsHalfDay = 1 THEN 0.5
								ELSE 0
								END AS LeaveDay
							,CASE 
								WHEN (
										ldt.WorkType = 1
										OR (
											WorkType <> @Onduty
											AND cl.IsOffDay = 1
											)
										) THEN 1
								ELSE 0
								END AS IsOffDay
							,CASE 
								WHEN (
										ldt.WorkType = 1
										OR (
											WorkType <> @Onduty
											AND cl.IsHoliday = 1
											)
										) THEN 1
								ELSE 0
								END AS IsHoliday
						FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							INNER JOIN #tblRequestId AS r ON r.RequestId = ldt.RequestId
							LEFT JOIN dbo.LeaveType AS lt1 WITH (NOLOCK) ON lt1.LeaveTypeId = ldt.LeaveType
                            AND lt1.CompanyId = @CompanyId
							LEFT JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON ldt.OnDate = cl.WorkDate
							AND ldt.EmpId = cl.EmpId
						WHERE ldt.WorkType <> @Onduty
						) AS a
					WHERE a.LeaveTypeId <> 0
						OR a.IsOffDay = 1
						OR a.IsHoliday = 1
					) AS b
				WHERE b.RequestId = wt.RequestId
				GROUP BY b.RequestId
					,b.Code
				FOR XML PATH('')
				), 1, 2, '') AS LeaveCountDetails
	FROM (
		SELECT rq.RequestId
			,CreatedDate
			,EmpId
		FROM dbo.WorkingTimeRequest AS rq WITH (NOLOCK)
			INNER JOIN #tblRequestId AS r ON r.RequestId = rq.RequestId
		) AS wt

	SELECT r.RequestId
		,r.RequestType
		,r.Currentstatus AS [Status]
		,r.empID
		,rd.FromDate
		,rd.ToDate
		,rd.TotalDays
		,rd.IsHalfDay
		,rd.RequestedTime AS RequestedDate
		,rd.FromTime
		,rd.ToTime
		,rd.KeepInViewType
		,gdt.LeaveCountDetails
		,lv.LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,r.Remark
		,ISNULL(rm.TotalDaysRequest, 0) TotalDaysRequestInMonth
		,CASE 
			WHEN r.RequestType IN (1, 2) THEN inoutmiss.ReasonId
			WHEN r.RequestType IN (3, 4) THEN inout.ReasonId
			ELSE 0
			END [ReasonId]
		,CASE 
			WHEN r.RequestType IN (1, 2, 6, 7) THEN lr.RefNo
			WHEN r.RequestType IN (3, 4) THEN inout.RefNo
			WHEN r.RequestType IN (5) THEN NULL
			END RefNo
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN s1.ShiftID
			ELSE s3.ShiftID END
			) AS FromShiftId
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShiftName
		,s2.ShiftID AS ToShiftId
		,(CASE 
			WHEN s2.ShiftID IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShiftName
		,s2.[Name] AS ToShiftName
		,csr.TypeId AS ChangeShiftType
		,rd.InOutMins AS TotalMinutes
		,rd.ActualInOutMins
		,r.CreatedDate
		,e.EmpId AS RequesterId
		,e.NickName AS RequesterNickName
		,e.FullName AS RequesterFullName
		,g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dep.DepartmentId
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,verifier.EmpId AS VerifierId
		,verifier.NickName AS VerifierNickName
		,verifier.FullName AS VerifierFullName
		,r.VerifiedDate
		,r.VerifiedStatus
		,approver.EmpId AS ApproverId
		,approver.NickName AS ApproverNickName
		,approver.FullName AS ApproverFullName
		,r.ApprovedDate
		,r.ApprovedStatus
		,hr.NickName AS ProcessedByNickName
		,hr.FullName AS ProcessedByFullName
		,r.HRDate AS ProcessedDate
		,r.HRStatus AS ProcessedStatus
		,r.ModifiedDate
		,ISNULL(rd.IsWarning, 0) AS IsWarning
		,r.ReworkCount
		,dbo.fnc_GetAnnualLeaveBalanceByYear(r.EmpId, YEAR(rd.FromDate), r.RequestId) AS AnnualLeaveBalance
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON r.RequestId = rq.RequestId
		INNER JOIN #tblRequestInDaily AS rd ON r.RequestId = rd.RequestID
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = r.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = r.empID
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.empid = r.VerifierId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.empid = r.ApproverId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.empid = r.HRId
		LEFT JOIN #tblTotalDaysRequestInMonth AS rm ON r.empID = rm.empid
		AND r.RequestType = rm.RequestType
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS C WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftID = rd.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftID = rd.ToShift
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftID = c.ShiftID
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeID = lr.LeaveType
        AND lv.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId
	ORDER BY r.CreatedDate DESC

	SELECT csrd.RequestId
		,csrd.OnDate
		,csrd.ToDate
	FROM #tblRequestId AS r
		INNER JOIN ChangeShiftRequest AS csr WITH (NOLOCK) ON csr.RequestId = r.RequestId
		INNER JOIN ChangeShiftRequestDetail AS csrd WITH (NOLOCK) ON csr.RequestId = csrd.RequestId

	DROP TABLE #tblstatus

	DROP TABLE #tblGroupsList

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblTotalDaysRequestInMonth

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestId
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Department_Get] @IsActive BIT = NULL
AS
/*
Created: 20200521@Lilac.Nguyen
Task: get department
DB: HRM

Revisions:
    20250403@Tim: remove param CompanyId [Redmine: #222886]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT dep.DepartmentId AS Id
		,dep.Code
		,dep.[Name]
		,dep.IsActive
		,u.UnitId
        ,u.Code
		,u.[Name]
	FROM dbo.Department AS dep WITH (NOLOCK)
		LEFT JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
	WHERE (@IsActive IS NULL OR dep.IsActive = @IsActive)
		AND dep.IsDeleted = 0
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsert_ForEmpId] @empId INT
	,@fromTime DATETIME
	,@toTime DATETIME
	,@onlyUpdate BIT = 0
AS
/*
Created:
Task:
DB: HRM

Revisions:

*/
BEGIN
	SET XACT_ABORT ON;
	
	DECLARE @RangeToScanTime SMALLINT = 480 -- 480 munites
        ,@serverTimeZone SMALLINT = -4
        ,@clientTimeZone REAL
		,@DateChangeRuleLateInEarlyOutRequest DATETIME = '2015-10-19'
	DECLARE @TimeRecord TABLE (Id INT, EmpId INT, RecordTime DATETIME, InOutType TINYINT)

    SELECT @clientTimeZone = config.[Value]
    FROM dbo.Employee AS emp WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'
    WHERE emp.EmpId = @EmpId

    SET @clientTimeZone = ISNULL(@clientTimeZone, @serverTimeZone)

	INSERT INTO @TimeRecord (Id, EmpId, RecordTime, InOutType)
	SELECT Id, EmpId, RecordTime, InOutType
	FROM #tmpTimeRecord WITH (NOLOCK)
	WHERE DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), RecordTime)) BETWEEN DATEADD(HH, - 2, CONVERT(VARCHAR(10), @fromTime, 111))
			AND DATEADD(d, 2, CONVERT(VARCHAR(10), @toTime, 111))
		AND EmpId = @empId

	DECLARE @i INT
		,@attendaceDate DATETIME
	DECLARE @WorkDate DATETIME
		,@ShiftId INT
		,@IsHoliday BIT
		,@isOffDay BIT
		,@IsLeaveDay BIT
		,@LeaveTypeId INT
		,@LateIn INT
		,@EarlyOut INT
		,@RequestedCheckinTime DATETIME
		,@RequestedCheckoutTime DATETIME
		,@BeginCheckInTime DATETIME
		,@EndCheckInTime DATETIME
		,@BeginCheckOutTime DATETIME
		,@EndCheckOutTime DATETIME
		,@InOfMachine DATETIME
		,@OutOfMachine DATETIME
		,@ExpectedInTime DATETIME
		,@ExpectedOutTime DATETIME
		,@Absence BIT
		,@IsRightShift BIT
		,@ActualLateIn INT
		,@ActualEarlyOut INT
		,@TotalWorkHours DECIMAL(18, 2)
		,@BreakTimeMins INT
		,@LeaveDay DECIMAL(18, 1)
		,@Notes NVARCHAR(2000)
		,@RequestLeaveTimeBegin DATETIME
		,@RequestLeaveTimeEnd DATETIME
		,@adjustLateIn INT
		,@adjustEarlyOut INT

	SET @i = 0
	SET @attendaceDate = CONVERT(VARCHAR(10), @fromTime, 111)

	WHILE DATEDIFF(d, @attendaceDate, @toTime) >= 0
	BEGIN
        SELECT @Absence = 0
			,@InOfMachine = NULL
			,@OutOfMachine = NULL
			,@ExpectedOutTime = NULL
			,@IsRightShift = NULL
			,@ExpectedInTime = NULL
			,@ExpectedOutTime = NULL
			,@ActualLateIn = 0
			,@ActualEarlyOut = 0
			,@RequestedCheckinTime = NULL
			,@RequestedCheckoutTime = NULL
			,@TotalWorkHours = NULL
			,@BreakTimeMins = 0
			,@ShiftId = NULL
			,@LeaveTypeId = NULL
			,@RequestLeaveTimeBegin = NULL
			,@RequestLeaveTimeEnd = NULL
			,@adjustLateIn = 0
			,@adjustEarlyOut = 0

		SELECT @WorkDate = WorkDate
			,@ShiftId = ShiftId
			,@IsHoliday = IsHoliday
			,@isOffDay = IsOffDay
			,@IsLeaveDay = IsLeaveDay
			,@LeaveTypeId = LeaveTypeId
			,@LateIn = ISNULL(LateIn, 0)
			,@EarlyOut = ISNULL(EarlyOut, 0)
			,@RequestedCheckinTime = RequestedCheckinTime
			,@RequestedCheckoutTime = RequestedCheckoutTime
			,@BeginCheckInTime = BeginCheckInTime
			,@EndCheckInTime = EndCheckInTime
			,@BeginCheckOutTime = BeginCheckOutTime
			,@EndCheckOutTime = EndCheckOutTime
			,@BreakTimeMins = BreakTimeMins
			,@LeaveDay = LeaveDay
		FROM #tmpEmpCalendar WITH (NOLOCK)
		WHERE EmpId = @empId
			AND WorkDate = @attendaceDate

		IF DATEDIFF(D, @DateChangeRuleLateInEarlyOutRequest, @WorkDate) >= 0
		BEGIN
			SELECT @LateIn = 0
				,@EarlyOut = 0
		END

		-- If Has Shift
		IF @ShiftId IS NOT NULL
			AND ISNULL(@LeaveDay, 0) <> 1
		BEGIN
			SET @ExpectedInTime = @BeginCheckInTime
			SET @ExpectedOutTime = @BeginCheckOutTime

			-- get time in
			SELECT @InOfMachine = MIN(RecordTime)
			FROM @TimeRecord
			WHERE InOutType = 0
				AND RecordTime BETWEEN DATEADD(mi, - @RangeToScanTime, @ExpectedInTime)
					AND @ExpectedOutTime

			-- get time out
			SELECT @OutOfMachine = MAX(RecordTime)
			FROM @TimeRecord
			WHERE InOutType = 1
				AND RecordTime BETWEEN @ExpectedInTime
					AND DATEADD(mi, @RangeToScanTime, @ExpectedOutTime)

			IF @InOfMachine > @OutOfMachine
			BEGIN
				SET @OutOfMachine = NULL
			END

			IF @RequestedCheckinTime IS NOT NULL
			BEGIN
				SET @InOfMachine = @RequestedCheckinTime
			END

			IF @RequestedCheckoutTime IS NOT NULL
			BEGIN
				SET @OutOfMachine = @RequestedCheckoutTime
			END

			IF DATEADD(mi, @EarlyOut, @OutOfMachine) < @ExpectedOutTime
			BEGIN
				SET @ActualEarlyOut = DATEDIFF(MINUTE, DATEADD(mi, @EarlyOut, @OutOfMachine), @ExpectedOutTime)
			END

			IF DATEADD(mi, - @LateIn, @InOfMachine) > @ExpectedINTime
			BEGIN
				SET @ActualLateIn = DATEDIFF(MINUTE, @ExpectedINTime, DATEADD(mi, - @LateIn, @InOfMachine))
			END

			IF @InOfMachine IS NOT NULL
			BEGIN
				IF @InOfMachine < @ExpectedInTime
				BEGIN
					SET @TotalWorkHours = (DATEDIFF(mi, @ExpectedInTime, @OutOfMachine) - ISNULL(@BreakTimeMins, 0)) / 60.0
				END
				ELSE
				BEGIN
					SET @TotalWorkHours = (DATEDIFF(mi, @InOfMachine, @OutOfMachine) - ISNULL(@BreakTimeMins, 0)) / 60.0
				END

				-- half leave
				IF @IsLeaveDay = 1
					AND @LeaveDay = 0.5
				BEGIN
					SELECT @RequestLeaveTimeBegin = FromTime
						,@RequestLeaveTimeEnd = ToTime
					FROM #tmpLeaveRequestHalfDay
					WHERE EmpId = @empId
						AND OnDate = @attendaceDate

					IF @RequestLeaveTimeBegin IS NOT NULL
						AND @RequestLeaveTimeEnd IS NOT NULL
					BEGIN
						IF DATEDIFF(mi, @ExpectedInTime, @RequestLeaveTimeBegin) < 30
							AND DATEDIFF(mi, @ExpectedInTime, @RequestLeaveTimeBegin) > - 30
						BEGIN
							SET @adjustLateIn = DATEDIFF(mi, @RequestLeaveTimeBegin, @RequestLeaveTimeEnd)
							SET @ActualLateIn = @ActualLateIn - @adjustLateIn

							IF @ActualLateIn < 0
							BEGIN
								SET @ActualLateIn = 0
							END
						END
						ELSE IF DATEDIFF(mi, @ExpectedOutTime, @RequestLeaveTimeEnd) < 30
							AND DATEDIFF(mi, @ExpectedOutTime, @RequestLeaveTimeEnd) > - 30
						BEGIN
							SET @adjustEarlyOut = DATEDIFF(mi, @RequestLeaveTimeBegin, @RequestLeaveTimeEnd)
							SET @ActualEarlyOut = @ActualEarlyOut - @adjustEarlyOut

							IF @ActualEarlyOut < 0
							BEGIN
								SET @ActualEarlyOut = 0
							END
						END
					END
				END
			END
		END
		ELSE IF ISNULL(@isOffDay, 0) = 0
			AND ISNULL(@IsHoliday, 0) = 0
			AND ISNULL(@LeaveDay, 0) <> 1
		BEGIN
			-- get time in
			SELECT @InOfMachine = MIN(RecordTime)
			FROM @TimeRecord
			WHERE InOutType = 0
				AND DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), RecordTime)) BETWEEN DATEADD(mi, 270, @attendaceDate)
					AND DATEADD(mi, 270, DATEADD(d, 1, @attendaceDate)) -- 4h30 of after day

			-- get time out
			SELECT @OutOfMachine = MAX(RecordTime)
			FROM @TimeRecord
			WHERE InOutType = 1
				AND DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), RecordTime)) BETWEEN DATEADD(mi, 540, @attendaceDate)
					AND DATEADD(mi, 720, DATEADD(d, 1, @attendaceDate)) -- 12h of after day

			IF @InOfMachine > @OutOfMachine
			BEGIN
				SET @OutOfMachine = NULL
			END

			IF @RequestedCheckinTime IS NOT NULL
			BEGIN
				SET @InOfMachine = @RequestedCheckinTime
			END

			IF @RequestedCheckoutTime IS NOT NULL
			BEGIN
				SET @OutOfMachine = @RequestedCheckoutTime
			END

			IF @InOfMachine IS NOT NULL
				AND @OutOfMachine IS NOT NULL
			BEGIN
				SET @TotalWorkHours = (DATEDIFF(mi, @InOfMachine, @OutOfMachine)) / 60.0
			END
		END

		IF @ShiftId IS NULL
			OR (
				@IsLeaveDay = 1
				AND @LeaveDay = 1
				)
		BEGIN
			SET @Absence = 1
		END
		ELSE IF @InOfMachine IS NULL
			AND @OutOfMachine IS NULL
		BEGIN
			SET @Absence = 1
		END

		--SELECT @ShiftId, @InOfMachine, @OutOfMachine, @IsLeaveDay, @isOffDay, @IsHoliday
		IF DATEDIFF(DD, @attendaceDate, DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), GETDATE()))) >= 0
		BEGIN
			IF (
					@ShiftId IS NOT NULL
					OR @InOfMachine IS NOT NULL
					OR @OutOfMachine IS NOT NULL
					OR @IsLeaveDay = 1
					OR @isOffDay = 1
					OR @IsHoliday = 1
					)
			BEGIN
				-- insert or update
				IF EXISTS (
						SELECT 1
						FROM dbo.EmployeeAttendance WITH (NOLOCK)
						WHERE EmpId = @empId
							AND AttendanceDate = CAST(@attendaceDate AS DATETIME)
						)
				BEGIN
					--update
					UPDATE dbo.EmployeeAttendance WITH (ROWLOCK)
					SET ShiftId = @ShiftId
						,InFixed = @InOfMachine
						,OutFixed = @OutOfMachine
						,ExpectedInTime = @ExpectedInTime
						,ExpectedOutTime = @ExpectedOutTime
						,LateIn = @ActualLateIn
						,EarlyOut = @ActualEarlyOut
						,LeaveTypeId = @LeaveTypeId
						,Absence = @Absence
						,TotalWorkHours = @TotalWorkHours
						,IsRightShift = @IsRightShift
						,LeaveDay = @LeaveDay
						,InsertDate = GETDATE()
					WHERE EmpId = @empId
						AND AttendanceDate = CAST(@attendaceDate AS DATETIME)
				END
				ELSE
				BEGIN
					--insert
					INSERT INTO dbo.EmployeeAttendance (
						EmpId
						,AttendanceDate
						,ShiftId
						,InFixed
						,OutFixed
						,ExpectedInTime
						,ExpectedOutTime
						,LateIn
						,EarlyOut
						,LeaveTypeId
						,Absence
						,TotalWorkHours
						,IsRightShift
						,LeaveDay
						,InsertDate
						)
					VALUES (
						@empId
						,@attendaceDate
						,@ShiftId
						,@InOfMachine
						,@OutOfMachine
						,@ExpectedInTime
						,@ExpectedOutTime
						,@ActualLateIn
						,@ActualEarlyOut
						,@LeaveTypeId
						,@Absence
						,@TotalWorkHours
						,@IsRightShift
						,@LeaveDay
						,GETDATE()
						)
				END
			END
			ELSE
			BEGIN
				DELETE
				FROM dbo.EmployeeAttendance WITH (ROWLOCK)
				WHERE EmpId = @empId
					AND AttendanceDate = CAST(@attendaceDate AS DATETIME)
			END
		END

		SET @i = @i + 1
		SET @attendaceDate = DATEADD(d, @i, @fromTime)
	END
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ScheduleArrangement_UpdateWeekly] @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@WeeklyScheduleXml VARCHAR(MAX) = ''
	,@DefaultShiftXml VARCHAR(MAX) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim.Trinh@2019-04-16
Task: Update weekly schedule
DB: HRM

Revisions:
Param's Explanation:
    @WeeklyScheduleXml=N'<ROOT><Row EmployeeId="1" WorkDate="2013-01-01" ShiftId="1" IsHoliday="1" IsOffDay="1" IsFixedOffDay="1" IsPublic="1" /></ROOT>
    @DefaultShiftXml=N'<ROOT><Row EmployeeId="1" FromDate="2013-01-01" ShiftId="1" /></ROOT>

*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @Today DATE = GETDATE()
		,@ModifiedDate DATETIME = GETDATE()
		,@DocHandler INT
		-- change shift type
		,@ChangeShiftTypeId TINYINT = 1
		,@MoveOfDayTypeId TINYINT = 2
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7

	CREATE TABLE #tblWeeklySchedule (
		EmployeeId INT
		,WorkDate DATE
		,ShiftId INT NULL
		,IsHoliday BIT
		,IsOffDay BIT
		,IsFixedOffDay BIT
		,IsPublic BIT
		)

	CREATE TABLE #tblDefaultShift (
		EmployeeId INT
		,FromDate DATE
		,ShiftId INT NULL
		)

	CREATE TABLE #OTMonthlyRequest (
		RequestId BIGINT
		,NormalHours DECIMAL(18, 2)
		,OffHours DECIMAL(18, 2)
		,PublicHours DECIMAL(18, 2)
		,SpecialHours DECIMAL(18, 2)
		)

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@WeeklyScheduleXml

		INSERT INTO #tblWeeklySchedule (
			EmployeeId
			,WorkDate
			,ShiftId
			,IsHoliday
			,IsOffDay
			,IsFixedOffDay
			,IsPublic
			)
		SELECT EmployeeId
			,WorkDate
			,CASE 
				WHEN ShiftId = '' THEN NULL
				ELSE CONVERT(INT, ShiftId)
				END
			,IsHoliday
			,IsOffDay
			,IsFixedOffDay
			,IsPublic
		FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (EmployeeId INT, WorkDate DATE, ShiftId VARCHAR(100), IsHoliday BIT, IsOffDay BIT, IsFixedOffDay BIT, IsPublic BIT) AS Data

		EXEC sp_xml_removedocument @DocHandler

		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@DefaultShiftXml

		INSERT INTO #tblDefaultShift (
			EmployeeId
			,FromDate
			,ShiftId
			)
		SELECT EmployeeId
			,FromDate
			,CASE 
				WHEN ShiftId = '' THEN NULL
				ELSE CONVERT(INT, ShiftId)
				END
		FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (EmployeeId INT, FromDate DATE, ShiftId VARCHAR(100)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	DECLARE @EmployeeIds VARCHAR(MAX)

	SELECT @EmployeeIds = COALESCE(@EmployeeIds + ',', '') + CAST(EmployeeId AS VARCHAR(10))
	FROM (
		SELECT DISTINCT EmployeeId
		FROM #tblWeeklySchedule
		) AS tbl

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
        ,@fromDate = @FromDate
		,@toDate = @ToDate
		,@empIds = @EmployeeIds
		,@isUpdateRequestData = 1

	DELETE tblweekly
	FROM #tblWeeklySchedule AS tblweekly WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tblweekly.EmployeeId = emp.EmpId
	WHERE emp.JoinedDate > tblweekly.WorkDate
		OR emp.ResignedDate <= tblweekly.WorkDate

	--DELETE tblweekly
	--FROM #tblWeeklySchedule AS tblweekly WITH (ROWLOCK, UPDLOCK)
	--	INNER JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON tblweekly.WorkDate = empatt.AttendanceDate
	--	AND tblweekly.EmployeeId = empatt.EmpId
	--	INNER JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON empca.WorkDate = tblweekly.WorkDate
	--	AND empca.EmpId = tblweekly.EmployeeId
	--	AND ISNULL(empca.ShiftId, - 1) = ISNULL(tblweekly.ShiftId, - 1)
	--	AND empca.IsOffDay = tblweekly.IsOffDay
	--	AND empca.IsHoliday = tblweekly.IsHoliday
	--	AND empca.IsPublic = tblweekly.IsPublic
	--WHERE tblweekly.WorkDate <= @Today

	DELETE tblweekly
	FROM #tblWeeklySchedule AS tblweekly WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON tblweekly.WorkDate = empca.WorkDate
		AND tblweekly.EmployeeId = empca.EmpId
	WHERE (
			empca.IsLeaveDay = 1
			AND empca.LeaveDay = 1
			)
		OR empca.ChangeShiftTypeId = @ChangeShiftTypeId
		OR (
			empca.ChangeShiftTypeId = @MoveOfDayTypeId
			AND empca.MoveOffFromDate IS NOT NULL
			)
		OR (
			empca.IsKeepInView = 1
			AND tblweekly.ShiftId IS NULL
			)
		OR (
			tblweekly.WorkDate <= @Today
			AND empca.IsOvertime = 1
			)

	INSERT INTO #OTMonthlyRequest (
		RequestId
		,NormalHours
		,OffHours
		,PublicHours
		,SpecialHours
		)
	SELECT ot.RequestId
		,SUM(ISNULL(ot.NormalHours, 0))
		,SUM(ISNULL(ot.OffHours, 0))
		,SUM(ISNULL(ot.PublicHours, 0))
		,SUM(ISNULL(ot.SpecialHours, 0))
	FROM dbo.OTDailyRequest AS ot WITH (NOLOCK)
		INNER JOIN #tblWeeklySchedule AS tblweekly WITH (NOLOCK) ON ot.EmpId = tblweekly.EmployeeId
		AND ot.OvertimeDate = tblweekly.WorkDate
	GROUP BY ot.RequestId

	DELETE ot
	FROM dbo.OTDailyRequest AS ot WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblWeeklySchedule AS tblweekly WITH (NOLOCK) ON ot.EmpId = tblweekly.EmployeeId
		AND ot.OvertimeDate = tblweekly.WorkDate

	UPDATE otm
	SET otm.NormalHours = ISNULL(otm.NormalHours, 0) - ot.NormalHours
		,otm.OffHours = ISNULL(otm.OffHours, 0) - ot.OffHours
		,otm.PublicHours = ISNULL(otm.PublicHours, 0) - ot.PublicHours
		,otm.SpecialHours = ISNULL(otm.SpecialHours, 0) - ot.SpecialHours
	FROM dbo.OTMonthlyRequest AS otm WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #OTMonthlyRequest AS ot WITH (NOLOCK) ON otm.RequestId = ot.RequestId

	INSERT INTO dbo.tmpEmployeeAttendace (
		EmpId
		,WorkDate
		,InsertedDate
		)
	SELECT tblweekly.EmployeeId
		,tblweekly.WorkDate
		,@ModifiedDate
	FROM #tblWeeklySchedule AS tblweekly WITH (NOLOCK)
		LEFT JOIN dbo.tmpEmployeeAttendace AS att WITH (NOLOCK) ON tblweekly.EmployeeId = att.EmpId
		AND tblweekly.WorkDate = att.WorkDate
	WHERE att.EmpId IS NULL
		AND DATEDIFF(DD, tblweekly.WorkDate, @Today) >= 0

	UPDATE empca
	SET empca.ShiftId = tblweekly.ShiftId
		,empca.IsOffDay = tblweekly.IsOffDay
		,empca.IsFixedOffDay = tblweekly.IsFixedOffDay
		,empca.IsHoliday = tblweekly.IsHoliday
		,empca.IsPublic = tblweekly.IsPublic
		,empca.ModifiedBy = @ActorId
		,empca.ModifiedDate = @ModifiedDate
	FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblWeeklySchedule AS tblweekly WITH (NOLOCK) ON tblweekly.WorkDate = empca.WorkDate
		AND tblweekly.EmployeeId = empca.EmpId

	UPDATE empca
	SET empca.IsFixedOffDay = 0
	FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
	WHERE empca.IsOffDay = 0
		AND empca.IsFixedOffDay = 1

	INSERT INTO dbo.EmployeeCalendar (
		WorkDate
		,EmpId
		,ShiftId
		,IsOffDay
		,IsFixedOffDay
		,IsHoliday
		,IsPublic
		,ModifiedBy
		,ModifiedDate
		)
	SELECT WorkDate
		,EmployeeId
		,ShiftId
		,IsOffDay
		,IsFixedOffDay
		,IsHoliday
		,IsPublic
		,@ActorId
		,@ModifiedDate
	FROM #tblWeeklySchedule AS tbl WITH (NOLOCK)
	WHERE NOT EXISTS (
		SELECT 1
		FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
		WHERE tbl.EmployeeId = ec.EmpId
			AND tbl.WorkDate = ec.WorkDate
		)

	MERGE dbo.ScheduleArrangementDefaultShift AS [target]
	USING #tblDefaultShift AS [source] ON (
				[target].EmployeeId = [source].EmployeeId
				AND [target].FromDate = [source].FromDate
				)
	WHEN MATCHED
		AND ISNULL([target].ShiftId, 0) <> ISNULL([source].ShiftId, 0) THEN
			UPDATE
			SET [target].ShiftId = [source].ShiftId
				,[target].ModifiedBy = @ActorId
				,[target].ModifiedDate = @ModifiedDate
	WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				EmployeeId
				,FromDate
				,ShiftId
				,ModifiedBy
				,ModifiedDate
				)
			VALUES (
				[source].EmployeeId
				,[source].FromDate
				,[source].ShiftId
				,@ActorId
				,@ModifiedDate
				);

	EXEC dbo.ScheduleArrangement_UpdateOffDayReplacement @CompanyId = @CompanyId
        ,@ActorId = @ActorId
		,@EmployeeIds = @EmployeeIds
		,@FromDate = @FromDate
		,@ToDate = @ToDate
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	DELETE
	FROM #tblWeeklySchedule WITH (ROWLOCK, UPDLOCK)
	WHERE WorkDate > @Today

	WHILE EXISTS (
		SELECT 1
		FROM #tblWeeklySchedule WITH (NOLOCK)
		)
	BEGIN
		DECLARE @EmpId INT, @WorkDate DATE
		SELECT TOP 1 @EmpId = EmployeeId
			,@WorkDate = WorkDate
		FROM #tblWeeklySchedule WITH (NOLOCK)

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
			,@WorkDate
			,@WorkDate
			,1

		DELETE
		FROM #tblWeeklySchedule WITH (ROWLOCK, UPDLOCK)
		WHERE EmployeeId = @EmpId
			AND WorkDate = @WorkDate
	END

	EXEC dbo.Log_WriteLog @LogActionId = 1002
		,@LogDate = @ModifiedDate
		,@Description = 'Update employee calendar'
		,@TrackingValue = @WeeklyScheduleXml
		,@UserId = @ActorId

	DROP TABLE #tblWeeklySchedule

	DROP TABLE #tblDefaultShift

	DROP TABLE #OTMonthlyRequest
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ScheduleArrangement_SyncShift] @CompanyId SMALLINT
    ,@ActorId INT
	,@ShiftXml NVARCHAR(MAX) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim@20250327
Task: sync shift from OWP
DB: HRM

Revisions:
Param's Explanation:
    @ShiftXml: "<Root>
		<Row ShiftCode={1} CheckInTime={2} CheckOutTime={3} IsInAfterDay={3} IsOutAfterDay={4} IsCrossDay={5} TotalHours={6} ModifiedDate={7} />
	</Root>"
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SyncDate DATETIME = GETDATE()
		,@DocHandler INT

    CREATE TABLE #tmpShiftId (RowIndex INT PRIMARY KEY IDENTITY(1, 1), ShiftId INT)

	CREATE TABLE #tmpShift (
		ShiftCode VARCHAR(20)
		,CheckInTime NCHAR(5) NULL
		,CheckOutTime NCHAR(5) NULL
		,IsInAfterDay BIT
		,IsOutAfterDay BIT
		,IsCrossDay BIT
		,TotalHours DECIMAL(10, 2)
		,ModifiedDate DATETIME
		)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@ShiftXml

	INSERT INTO #tmpShift (
		ShiftCode
		,CheckInTime
		,CheckOutTime
		,IsInAfterDay
		,IsOutAfterDay
		,IsCrossDay
		,TotalHours
		,ModifiedDate
		)
	SELECT ShiftCode
		,CheckInTime
		,CheckOutTime
		,IsInAfterDay
		,IsOutAfterDay
		,IsCrossDay
		,TotalHours
		,ModifiedDate
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (ShiftCode VARCHAR(20), CheckInTime NCHAR(5), CheckOutTime NCHAR(5), IsInAfterDay BIT, IsOutAfterDay BIT, IsCrossDay BIT, TotalHours DECIMAL(10, 2), ModifiedDate DATETIME) AS Data

	EXEC sp_xml_removedocument @DocHandler

	INSERT INTO dbo.[Shift] (
		Code
		,[Name]
		,BeginCheckInTime
		,EndCheckInTime
		,BeginCheckOutTime
		,EndCheckOutTime
		,BreakTimeMins
		,TotalHours
		,CrossDay
		,IsInAfterDay
		,IsOutAfterDay
		,OWPModifiedDate
		,OWPSyncDate
		,CreatedDate
		,IsDisabled
        ,CompanyId
        ,OldShiftId
		)
    OUTPUT inserted.ShiftID
    INTO #tmpShiftId(ShiftId)
	SELECT DISTINCT tmpws.ShiftCode
		,tmpws.ShiftCode
		,tmpws.CheckInTime
		,tmpws.CheckInTime
		,tmpws.CheckOutTime
		,tmpws.CheckOutTime
		,0
		,tmpws.TotalHours
		,tmpws.IsCrossDay
		,tmpws.IsInAfterDay
		,tmpws.IsOutAfterDay
		,tmpws.ModifiedDate
		,@SyncDate
		,@SyncDate
		,0
        ,@CompanyId
        ,0
	FROM #tmpShift AS tmpws WITH (NOLOCK)
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.[Shift] AS s WITH (NOLOCK)
			WHERE s.CompanyId = @CompanyId
                AND s.Code = tmpws.ShiftCode
			)

    DECLARE @RowIndex INT = 1
        ,@ShiftId INT
        ,@OldShiftId INT

    WHILE EXISTS (
			SELECT 1
			FROM #tmpShiftId WITH (NOLOCK)
			WHERE RowIndex = @RowIndex
			)
	BEGIN
		SELECT @ShiftId = ShiftId
		FROM #tmpShiftId WITH (NOLOCK)
		WHERE RowIndex = @RowIndex

        SELECT @OldShiftId = MAX(OldShiftId)
        FROM dbo.[Shift] WITH (NOLOCK)
        WHERE CompanyId = @CompanyId

        SET @OldShiftId = ISNULL(@OldShiftId, 0) + 1

		UPDATE dbo.[Shift] WITH (ROWLOCK)
        SET OldShiftId = @OldShiftId
        WHERE ShiftID = @ShiftId

		SET @RowIndex = @RowIndex + 1
	END

    DROP TABLE #tmpShiftId
	DROP TABLE #tmpShift
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeAttendance_ForWaitingCase] @CompanyId SMALLINT = NULL
AS
/*
Created:
Task:
DB: HRM

Revisions:

*/
BEGIN
	SET XACT_ABORT ON;

	DECLARE @i INT
		,@TempEmpId INT
		,@TempWorkDate DATE
		,@TempShiftId INT
		,@fromDate DATE
		,@toDate DATE
        ,@serverTimeZone SMALLINT = -4
	CREATE TABLE #tmpEmployee (Id INT PRIMARY KEY IDENTITY(1, 1), EmpId INT, CompanyId SMALLINT, WorkDate DATE)

	SELECT @fromDate = MIN(att.WorkDate)
		,@toDate = MAX(att.WorkDate)
	FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON att.EmpId = ce.EmpId
    WHERE @CompanyId IS NULL
        OR ce.CompanyId = @CompanyId

	INSERT INTO #tmpEmployee (EmpId, CompanyId, WorkDate)
	SELECT TOP 100 att.EmpId
		,ce.CompanyId
        ,att.WorkDate
	FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON att.EmpId = ce.EmpId
    WHERE @CompanyId IS NULL
        OR ce.CompanyId = @CompanyId

	DELETE tmp
	FROM dbo.tmpEmployeeAttendace AS tmp WITH (ROWLOCK)
		INNER JOIN #tmpEmployee AS e WITH (NOLOCK) ON tmp.EmpId = e.EmpId
	WHERE tmp.WorkDate = e.WorkDate

	IF EXISTS (
			SELECT 1
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpTimeRecord'
			)
	BEGIN
		DROP TABLE #tmpTimeRecord
	END

	CREATE TABLE #tmpTimeRecord (Id INT, EmpId INT, RecordTime DATETIME, InOutType TINYINT)

	-- Get all in/out data into temp table to calculate
	INSERT INTO #tmpTimeRecord (Id, EmpId, RecordTime, InOutType)
	SELECT ti.Id, ti.EmpId, ti.RecordTime, ti.InOutType
	FROM dbo.TimeRecord AS ti WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ti.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'
	WHERE DATEADD(MINUTE, CAST(ISNULL(config.Value, @serverTimeZone) AS REAL) * 60, DATEADD(HOUR, ABS(@serverTimeZone), ti.RecordTime))
        BETWEEN DATEADD(HH, - 2, CONVERT(VARCHAR(10), @fromDate, 111)) AND DATEADD(d, 2, CONVERT(VARCHAR(10), @toDate, 111))
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS e WITH (NOLOCK)
			WHERE e.EmpId = ti.EmpId
			)

	IF EXISTS (
			SELECT 1
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpLeaveRequestHalfDay'
			)
	BEGIN
		DROP TABLE #tmpLeaveRequestHalfDay
	END

	CREATE TABLE #tmpLeaveRequestHalfDay (EmpId INT, OnDate DATETIME, FromTime DATETIME, ToTime DATETIME)

	-- Get all leave request half day
	INSERT INTO #tmpLeaveRequestHalfDay (EmpId, OnDate, FromTime, ToTime)
	SELECT lv.EmpId, lv.OnDate, FromTime, ToTime
	FROM dbo.LeaveRequestDetail AS lv WITH (NOLOCK)
		INNER JOIN (
		SELECT ldt.empId
			,OnDate
		FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			INNER JOIN dbo.WorkingTimeRequest AS wrq WITH (NOLOCK) ON ldt.RequestId = wrq.RequestId
		WHERE WorkType = 2
			AND IsHalfDay = 1 -- 2: leave, 1: Half day
			AND DATEDIFF(DD, @fromDate, OnDate) >= 0
			AND DATEDIFF(DD, OnDate, DATEADD(DD, 2, @toDate)) >= 0
			AND EXISTS (
				SELECT 1
				FROM #tmpEmployee AS tmp WITH (NOLOCK)
				WHERE tmp.EmpId = ldt.EmpId
				)
			AND wrq.CurrentStatus IN (4, 6)
		GROUP BY ldt.empId
			,OnDate
		HAVING COUNT(1) = 1
		) a ON a.EmpId = lv.EmpId
		AND a.OnDate = lv.OnDate
		INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON lv.RequestId = rq.RequestId
	WHERE lv.IsHalfDay = 1
		AND EXISTS (
			SELECT 1
			FROM #tmpEmployee AS tmp WITH (NOLOCK)
			WHERE tmp.EmpId = lv.EmpId
			)
		AND rq.CurrentStatus IN (4, 6)

	-- Get all calendars of employees into temp table
	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpEmpCalendar'
			)
	BEGIN
		DROP TABLE #tmpEmpCalendar
	END

	CREATE TABLE #tmpEmpCalendar (
		Id INT PRIMARY KEY IDENTITY(1, 1)
		,EmpId INT
		,WorkDate DATETIME
		,ShiftId INT
		,IsHoliday BIT
		,IsOffDay BIT
		,IsLeaveDay BIT
		,LeaveTypeId INT NULL
		,IsKeepInView BIT
		,LateIn INT
		,EarlyOut INT
		,RequestedCheckInTime DATETIME
		,RequestedCheckOutTime DATETIME
		,BeginCheckInTime DATETIME
		,EndCheckInTime DATETIME
		,BeginCheckOutTime DATETIME
		,EndCheckOutTime DATETIME
		,BreakTimeMins INT
		,LeaveDay DECIMAL(18, 1)
		)

	INSERT INTO #tmpEmpCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsHoliday
		,IsOffDay
		,IsLeaveDay
		,LeaveTypeId
		,IsKeepInView
		,LateIn
		,EarlyOut
		,RequestedCheckInTime
		,RequestedCheckOutTime
		,BeginCheckInTime
		,EndCheckInTime
		,BeginCheckOutTime
		,EndCheckOutTime
		,BreakTimeMins
		,LeaveDay
		)
	SELECT e.EmpId
		,e.WorkDate
		,ec.ShiftId
		,ec.IsHoliday
		,ec.IsOffDay
		,ec.IsLeaveDay
		,ec.LeaveTypeId
		,ec.IsKeepInView
		,ec.LateIn
		,ec.EarlyOut
		,ec.RequestedCheckinTime
		,ec.RequestedCheckoutTime
		,CASE
			WHEN s.IsInAfterDay = 1 THEN DATEADD(D, 1, ec.WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(ec.WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS BeginCheckInTime
		,CASE 
			WHEN s.IsInAfterDay = 1 THEN DATEADD(d, 1, ec.WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(ec.WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS EndCheckInTime
		,CASE 
			WHEN s.IsOutAfterDay = 1 THEN DATEADD(d, 1, ec.WorkDate + ' ' + s.BeginCheckOutTime)
			ELSE CAST(ec.WorkDate + ' ' + s.BeginCheckOutTime AS DATETIME)
			END AS BeginCheckOutTime
		,CASE 
			WHEN s.IsOutAfterDay = 1 THEN DATEADD(d, 1, ec.WorkDate + ' ' + s.EndCheckOutTime)
			ELSE CAST(ec.WorkDate + ' ' + s.EndCheckOutTime AS DATETIME)
			END AS EndCheckOutTime
		,s.BreakTimeMins
		,ec.LeaveDay
	FROM #tmpEmployee AS e WITH (NOLOCK)
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.EmpId = e.EmpId
		AND ec.WorkDate = e.WorkDate
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ec.ShiftId
	ORDER BY e.EmpId
		,e.WorkDate

    -- convert to server time zone
    UPDATE empca
    SET empca.BeginCheckInTime = CASE WHEN empca.BeginCheckInTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.BeginCheckInTime) END
        ,empca.EndCheckInTime = CASE WHEN empca.EndCheckInTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.EndCheckInTime) END
        ,empca.BeginCheckOutTime = CASE WHEN empca.BeginCheckOutTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.BeginCheckOutTime) END
        ,empca.EndCheckOutTime = CASE WHEN empca.EndCheckOutTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.EndCheckOutTime) END
    FROM #tmpEmpCalendar AS empca WITH (ROWLOCK)
        INNER JOIN #tmpEmployee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON emp.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'

	IF EXISTS (
			SELECT 1
			FROM #tmpEmpCalendar WITH (NOLOCK)
			)
	BEGIN
		SET @i = 1

		WHILE EXISTS (
				SELECT 1
				FROM #tmpEmpCalendar WITH (NOLOCK)
				WHERE Id = @i
				)
		BEGIN
			SELECT @TempEmpId = EmpId
				,@TempWorkDate = WorkDate
				,@TempShiftId = ShiftId
			FROM #tmpEmpCalendar
			WHERE Id = @i

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForEmpId @TempEmpId
				,@TempWorkDate
				,@TempWorkDate
				,1

			EXEC dbo.Discipline_Insert @FromDate = @TempWorkDate
				,@ToDate = @TempWorkDate
				,@EmpId = @TempEmpId

			SET @i = @i + 1
		END
	END

    DROP TABLE #tmpEmployee

	DROP TABLE #tmpTimeRecord

	DROP TABLE #tmpEmpCalendar

	DROP TABLE #tmpLeaveRequestHalfDay
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsert] @empId INT = NULL
	,@fromTime DATETIME
	,@toTime DATETIME
	,@onlyUpdate BIT = 0
    ,@CompanyId SMALLINT = NULL
AS
/*
Created:
Task:
DB: HRM

Revisions:

*/
BEGIN
	SET XACT_ABORT ON;

	DECLARE @i INT
		,@TempEmpId INT
		,@tempFromDate DATE = @fromTime
		,@tempToDate DATE = @toTime
		,@today DATE = GETDATE()
        ,@serverTimeZone SMALLINT = -4
	DECLARE @tblDateRange TABLE (WorkDate DATE)
	CREATE TABLE #tmpEmployee (Id INT PRIMARY KEY IDENTITY(1, 1), EmpId INT)

	IF @tempToDate > @today
	BEGIN
		SET @tempToDate = @today
	END

	WHILE @tempFromDate <= @tempToDate
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM @tblDateRange
				WHERE WorkDate = @tempFromDate
				)
		BEGIN
			INSERT INTO @tblDateRange (WorkDate)
			VALUES (@tempFromDate)
		END

		SET @tempFromDate = DATEADD(DAY, 1, @tempFromDate)
	END

	IF EXISTS (
			SELECT EmpId
			FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
				LEFT JOIN @tblDateRange AS tbldate ON empca.WorkDate = tbldate.WorkDate
			WHERE (
					@empId IS NULL
					OR EmpId = @empId
					)
				AND tbldate.WorkDate IS NULL
			)
	BEGIN
		DECLARE @ErrCode INT = 0
			,@ErrMsg VARCHAR(200) = ''

		EXEC dbo.EmployeeCalendar_Insert @EmpId = @empId
			,@fromdate = @fromTime
			,@todate = @tempToDate
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END

	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpTimeRecord'
			)
	BEGIN
		DROP TABLE #tmpTimeRecord
	END

	CREATE TABLE #tmpTimeRecord (
		Id INT
		,EmpId INT
		,RecordTime DATETIME
		,InOutType TINYINT
		)

	-- Get all in/out data into temp table to calculate
	INSERT INTO #tmpTimeRecord (
		Id
		,EmpId
		,RecordTime
		,InOutType
		)
	SELECT tr.Id
		,tr.EmpId
		,tr.RecordTime
		,tr.InOutType
	FROM dbo.TimeRecord AS tr WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON tr.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND DATEADD(MINUTE, CAST(ISNULL(config.Value, @serverTimeZone) AS REAL) * 60, DATEADD(HOUR, ABS(@serverTimeZone), tr.RecordTime))
            BETWEEN DATEADD(HH, - 2, CONVERT(VARCHAR(10), @fromTime, 111)) AND DATEADD(d, 2, CONVERT(VARCHAR(10), @toTime, 111))
		AND emp.JoinedDate <= CAST(tr.RecordTime AS DATE)
		AND (
			@empId IS NULL
			OR tr.EmpId = @empId
			)

	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpLeaveRequestHalfDay'
			)
	BEGIN
		DROP TABLE #tmpLeaveRequestHalfDay
	END

	CREATE TABLE #tmpLeaveRequestHalfDay (
		EmpId INT
		,OnDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		)

	-- Get all leave request half day
	INSERT INTO #tmpLeaveRequestHalfDay (
		EmpId
		,OnDate
		,FromTime
		,ToTime
		)
	SELECT lv.EmpId
		,lv.OnDate
		,FromTime
		,ToTime
	FROM dbo.LeaveRequestDetail AS lv WITH (NOLOCK)
		INNER JOIN (
		SELECT ldt.empId
			,OnDate
		FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			INNER JOIN dbo.WorkingTimeRequest AS wrq WITH (NOLOCK) ON ldt.RequestId = wrq.RequestId
		WHERE WorkType = 2
			AND IsHalfDay = 1 -- 2: leave, 1: Half day
			AND OnDate BETWEEN CONVERT(VARCHAR(10), @fromTime, 111)
				AND CONVERT(VARCHAR(10), DATEADD(d, 2, @toTime), 111)
			AND (
				@empId IS NULL
				OR ldt.EmpId = @empId
				)
			AND wrq.CurrentStatus IN (4, 6)
		GROUP BY ldt.empId
			,OnDate
		HAVING COUNT(*) = 1
		) a ON a.EmpId = lv.EmpId
			AND a.OnDate = lv.OnDate
		INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON lv.RequestId = rq.RequestId
	WHERE lv.IsHalfDay = 1
		AND (
			@empId IS NULL
			OR lv.EmpId = @empId
			)
		AND rq.CurrentStatus IN (4, 6)

	-- Get all calendars of employees into temp table
	IF EXISTS (
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = '#tmpEmpCalendar'
			)
	BEGIN
		DROP TABLE #tmpEmpCalendar
	END

	CREATE TABLE #tmpEmpCalendar (
		Id INT PRIMARY KEY IDENTITY(1, 1)
		,EmpId INT
		,WorkDate DATETIME
		,ShiftId INT
		,IsHoliday BIT
		,IsOffDay BIT
		,IsLeaveDay BIT
		,LeaveTypeId INT NULL
		,IsKeepInView BIT
		,LateIn INT
		,EarlyOut INT
		,RequestedCheckInTime DATETIME
		,RequestedCheckOutTime DATETIME
		,BeginCheckInTime DATETIME
		,EndCheckInTime DATETIME
		,BeginCheckOutTime DATETIME
		,EndCheckOutTime DATETIME
		,BreakTimeMins INT
		,LeaveDay DECIMAL(18, 1)
		)

	INSERT INTO #tmpEmpCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsHoliday
		,IsOffDay
		,IsLeaveDay
		,LeaveTypeId
		,IsKeepInView
		,LateIn
		,EarlyOut
		,RequestedCheckInTime
		,RequestedCheckOutTime
		,BeginCheckInTime
		,EndCheckInTime
		,BeginCheckOutTime
		,EndCheckOutTime
		,BreakTimeMins
		,LeaveDay
		)
	SELECT ec.EmpId
		,ec.WorkDate
		,ec.ShiftId
		,ec.IsHoliday
		,ec.IsOffDay
		,ec.IsLeaveDay
		,ec.LeaveTypeId
		,ec.IsKeepInView
		,ec.LateIn
		,ec.EarlyOut
		,ec.RequestedCheckinTime
		,ec.RequestedCheckoutTime
		,CASE 
			WHEN IsInAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS BeginCheckInTime
		,CASE 
			WHEN IsInAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckInTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckInTime AS DATETIME)
			END AS EndCheckInTime
		,CASE 
			WHEN IsOutAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.BeginCheckOutTime)
			ELSE CAST(WorkDate + ' ' + s.BeginCheckOutTime AS DATETIME)
			END AS BeginCheckOutTime
		,CASE 
			WHEN IsOutAfterDay = 1 THEN DATEADD(d, 1, WorkDate + ' ' + s.EndCheckOutTime)
			ELSE CAST(WorkDate + ' ' + s.EndCheckOutTime AS DATETIME)
			END AS EndCheckOutTime
		,BreakTimeMins
		,LeaveDay
	FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ec.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ec.ShiftId
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
        AND (
			@EmpId IS NULL
			OR emp.EmpId = @EmpId
			)
        AND (
			@CompanyId IS NULL
			OR ce.CompanyId = @CompanyId
			)
		AND ec.WorkDate BETWEEN @FromTime
			AND @ToTime
	ORDER BY ec.EmpId
		,ec.WorkDate

    -- convert to server time zone
    UPDATE empca
    SET empca.BeginCheckInTime = CASE WHEN empca.BeginCheckInTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.BeginCheckInTime) END
        ,empca.EndCheckInTime = CASE WHEN empca.EndCheckInTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.EndCheckInTime) END
        ,empca.BeginCheckOutTime = CASE WHEN empca.BeginCheckOutTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.BeginCheckOutTime) END
        ,empca.EndCheckOutTime = CASE WHEN empca.EndCheckOutTime IS NULL THEN NULL
            ELSE DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE (-1.0 * config.[Value]) + @serverTimeZone END * 60, empca.EndCheckOutTime) END
    FROM #tmpEmpCalendar AS empca WITH (ROWLOCK)
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'

	IF @empId IS NULL
	BEGIN
		INSERT INTO #tmpEmployee (EmpId)
		SELECT e.EmpId
		FROM dbo.Employee AS e WITH (NOLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
		WHERE e.[Enabled] = 1
		    AND e.isDeleted = 0
            AND (
			    @CompanyId IS NULL
			    OR ce.CompanyId = @CompanyId
			)
			AND EXISTS (
				SELECT 1
				FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
				WHERE DATEDIFF(DD, @fromTime, cl.WorkDate) >= 0
					AND DATEDIFF(DD, WorkDate, @toTime) >= 0
					AND e.EmpId = cl.EmpId
				)

		SET @i = 1

		WHILE EXISTS (
				SELECT 1
				FROM #tmpEmployee WITH (NOLOCK)
				WHERE Id = @i
				)
		BEGIN
			SELECT @TempEmpId = EmpId
			FROM #tmpEmployee WITH (NOLOCK)
			WHERE Id = @i

			EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForEmpId @TempEmpId
				,@fromTime
				,@toTime
				,@onlyUpdate

			SET @i = @i + 1
		END

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForWorkDay @empId
			,@fromTime
			,@toTime
	END
	ELSE
	BEGIN
		EXEC dbo.EmployeeAttendance_ProcessingAndInsert_ForEmpId @EmpId
			,@fromTime
			,@toTime
			,@onlyUpdate
	END

	EXEC dbo.Discipline_Insert @FromDate = @fromTime
		,@ToDate = @toTime
		,@EmpId = @EmpId

	DROP TABLE #tmpEmployee
    
    DROP TABLE #tmpTimeRecord

	DROP TABLE #tmpEmpCalendar

	DROP TABLE #tmpLeaveRequestHalfDay
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsert_ForWorkDay] @empId INT
	,@fromTime DATETIME
	,@toTime DATETIME
AS
/*
Created:
Task:
DB: HRM

Revisions:

*/
BEGIN
	UPDATE att
	SET att.ShiftId = c.ShiftID
		,att.InFixed = c.CheckIn
		,att.OutFixed = c.CheckOut
		,att.ExpectedInTime = c.ExpectedInTime
		,att.ExpectedOutTime = c.ExpectedOutTime
		,att.LateIn = CASE 
			WHEN c.LateIn <= 0 THEN 0
			ELSE c.LateIn
			END
		,att.EarlyOut = CASE 
			WHEN c.EarlyOut <= 0 THEN 0
			ELSE c.EarlyOut
			END
		,att.LeaveTypeId = NULL
		,att.Absence = c.Absence
		,att.TotalWorkHours = CASE 
			WHEN c.IsValid = 1 THEN (CASE 
					WHEN c.CheckIn < c.ExpectedInTime THEN ((DATEDIFF(mi, c.ExpectedInTime, c.CheckOut) - ISNULL(c.BreakTimeMins, 0)) / 60.0)
					ELSE (DATEDIFF(mi, c.CheckIn, c.CheckOut) - ISNULL(c.BreakTimeMins, 0)) / 60.0 END
					)
			ELSE NULL
			END
		,att.LeaveDay = NULL
		,att.InsertDate = GETDATE()
		,att.LeaveTypeId2 = NULL
	FROM (
		SELECT b.EmpId
			,b.WorkDate
			,b.Code
			,b.ShiftID
			,b.CheckIn
			,b.CheckOut
			,CASE 
				WHEN (
						b.CheckIn IS NOT NULL
						AND b.CheckOut IS NOT NULL
						AND b.CheckIn < b.CheckOut
						) THEN 1
				ELSE 0
				END AS IsValid
			,CASE 
				WHEN b.CheckIn IS NULL THEN 0
				ELSE DATEDIFF(MINUTE, b.ExpectedInTime, b.CheckIn)
				END AS LateIn
			,CASE 
				WHEN b.CheckOut IS NULL THEN 0
				ELSE DATEDIFF(MINUTE, b.CheckOut, b.ExpectedOutTime)
				END AS EarlyOut
			,b.ExpectedInTime
			,b.ExpectedOutTime
			,b.BreakTimeMins
			,b.Absence
		FROM (
			SELECT a.EmpId
				,a.WorkDate
				,a.Code
				,a.ShiftID
				,(CASE 
					WHEN a.RequestedCheckinTime IS NULL THEN a.CheckIn
					ELSE a.RequestedCheckinTime END
					) CheckIn
				,(CASE 
					WHEN a.RequestedCheckoutTime IS NULL THEN a.CheckOut
					ELSE a.RequestedCheckoutTime END
					) CheckOut
				,a.ExpectedInTime
				,a.ExpectedOutTime
				,a.BreakTimeMins
				,CASE 
					WHEN (
							a.IsOffDay = 1
							OR a.IsHoliday = 1
							OR (
								a.IsLeaveDay = 1
								AND a.LeaveDay = 1
								)
							OR (
								a.CheckIn IS NULL
								AND a.CheckOut IS NULL
								)
							) THEN 1
					ELSE 0
					END AS Absence
			FROM (
				SELECT cl.EmpId
					,cl.WorkDate
					,sh.ShiftID
					,sh.Code
					,sh.BeginCheckInTime
					,sh.BeginCheckOutTime
					,sh.IsInAfterDay
					,sh.IsOutAfterDay
					,cl.RequestedCheckinTime
					,cl.RequestedCheckoutTime
					,cl.LateIn
					,cl.EarlyOut
					,cl.IsHoliday
					,cl.IsOffDay
					,cl.IsLeaveDay
					,cl.LeaveTypeId
					,cl.IsKeepInView
					,cl.LeaveDay
					,sh.BreakTimeMins
					,CASE 
						WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
						ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111)
						END + ' ' + sh.BeginCheckInTime AS ExpectedInTime
					,CASE 
						WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
						ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111)
						END + ' ' + sh.BeginCheckOutTime AS ExpectedOutTime
					,(
						SELECT MIN(RecordTime)
						FROM dbo.TimeRecord WITH (NOLOCK)
						WHERE InOutType = 0
							AND EmpID = cl.EmpId
							AND RecordTime BETWEEN DATEADD(mi, - 480, (CASE 
											WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
											ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckInTime
											))
								AND (CASE 
										WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
										ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckOutTime
										)
						) AS CheckIn
					,(
						SELECT MAX(RecordTime)
						FROM dbo.TimeRecord WITH (NOLOCK)
						WHERE InOutType = 1
							AND EmpID = cl.EmpId
							AND RecordTime BETWEEN (CASE 
										WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
										ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckInTime
										)
								AND DATEADD(mi, 480, (CASE 
											WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
											ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckOutTime
											))
						) AS CheckOut
				FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
					INNER JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
				WHERE cl.EmpId = @empId
                    AND ISNULL(cl.LeaveDay, 0) = 0
					AND DATEDIFF(DD, @fromTime, WorkDate) >= 0
					AND DATEDIFF(DD, WorkDate, @toTime) >= 0
				) AS a
			) AS b
		) AS c
		INNER JOIN dbo.EmployeeAttendance AS att WITH (ROWLOCK) ON c.EmpId = att.EmpId
		AND c.WorkDate = att.AttendanceDate

	INSERT INTO dbo.EmployeeAttendance (
		[EmpId]
		,[AttendanceDate]
		,[ShiftId]
		,[InFixed]
		,[OutFixed]
		,[ExpectedInTime]
		,[ExpectedOutTime]
		,[LateIn]
		,[EarlyOut]
		,[Absence]
		,[TotalWorkHours]
		,[InsertDate]
		)
	SELECT c.EmpId
		,c.WorkDate
		,c.ShiftID
		,c.CheckIn
		,c.CheckOut
		,c.ExpectedInTime
		,c.ExpectedOutTime
		,CASE 
			WHEN c.LateIn <= 0 THEN 0
			ELSE c.LateIn
			END AS LateIn
		,CASE 
			WHEN c.EarlyOut <= 0 THEN 0
			ELSE c.EarlyOut
			END AS EarlyOut
		,c.Absence
		,CAST((CASE 
				WHEN c.IsValid = 1 THEN (CASE 
						WHEN c.CheckIn < c.ExpectedInTime THEN ((DATEDIFF(mi, c.ExpectedInTime, c.CheckOut) - ISNULL(c.BreakTimeMins, 0)) / 60.0)
						ELSE (DATEDIFF(mi, c.CheckIn, c.CheckOut) - ISNULL(c.BreakTimeMins, 0)) / 60.0 END
						)
				ELSE NULL END
				) AS DECIMAL(18, 2)) TotalHours
		,GETDATE()
	FROM (
		SELECT b.EmpId
			,b.WorkDate
			,b.Code
			,b.ShiftID
			,b.CheckIn
			,b.CheckOut
			,CASE 
				WHEN (
						b.CheckIn IS NOT NULL
						AND b.CheckOut IS NOT NULL
						AND b.CheckIn < b.CheckOut
						) THEN 1
				ELSE 0
				END AS IsValid
			,CASE 
				WHEN b.CheckIn IS NULL THEN 0
				ELSE DATEDIFF(MINUTE, b.ExpectedInTime, b.CheckIn)
				END AS LateIn
			,CASE 
				WHEN b.CheckOut IS NULL THEN 0
				ELSE DATEDIFF(MINUTE, b.CheckOut, b.ExpectedOutTime)
				END AS EarlyOut
			,b.ExpectedInTime
			,b.ExpectedOutTime
			,b.BreakTimeMins
			,b.Absence
		FROM (
			SELECT a.EmpId
				,a.WorkDate
				,a.Code
				,a.ShiftID
				,(CASE 
					WHEN a.RequestedCheckinTime IS NULL THEN a.CheckIn
					ELSE a.RequestedCheckinTime END
					) CheckIn
				,(CASE 
					WHEN a.RequestedCheckoutTime IS NULL THEN a.CheckOut
					ELSE a.RequestedCheckoutTime END
					) CheckOut
				,a.ExpectedInTime
				,a.ExpectedOutTime
				,a.BreakTimeMins
				,CASE 
					WHEN (
							a.IsOffDay = 1
							OR a.IsHoliday = 1
							OR (
								a.IsLeaveDay = 1
								AND a.LeaveDay = 1
								)
							OR (
								a.CheckIn IS NULL
								AND a.CheckOut IS NULL
								)
							) THEN 1
					ELSE 0
					END AS Absence
			FROM (
				SELECT cl.EmpId
					,cl.WorkDate
					,sh.ShiftID
					,sh.Code
					,sh.BeginCheckInTime
					,sh.BeginCheckOutTime
					,sh.IsInAfterDay
					,sh.IsOutAfterDay
					,cl.RequestedCheckinTime
					,cl.RequestedCheckoutTime
					,cl.LateIn
					,cl.EarlyOut
					,cl.IsHoliday
					,cl.IsOffDay
					,cl.IsLeaveDay
					,cl.LeaveTypeId
					,cl.IsKeepInView
					,cl.LeaveDay
					,sh.BreakTimeMins
					,CASE 
						WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
						ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111)
						END + ' ' + sh.BeginCheckInTime AS ExpectedInTime
					,CASE 
						WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
						ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111)
						END + ' ' + sh.BeginCheckOutTime AS ExpectedOutTime
					,(
						SELECT MIN(RecordTime)
						FROM dbo.TimeRecord WITH (NOLOCK)
						WHERE InOutType = 0
							AND EmpID = cl.EmpId
							AND RecordTime BETWEEN DATEADD(mi, - 480, (CASE 
											WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
											ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckInTime
											))
								AND (CASE 
										WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
										ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckOutTime
										)
						) AS CheckIn
					,(
						SELECT MAX(RecordTime)
						FROM dbo.TimeRecord WITH (NOLOCK)
						WHERE InOutType = 1
							AND EmpID = cl.EmpId
							AND RecordTime BETWEEN (CASE 
										WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
										ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckInTime
										)
								AND DATEADD(mi, 480, (CASE 
											WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
											ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckOutTime
											))
						) AS CheckOut
				FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
					INNER JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
				WHERE cl.EmpId = @empId
                    AND ISNULL(cl.LeaveDay, 0) = 0
					AND DATEDIFF(DD, @fromTime, WorkDate) >= 0
					AND DATEDIFF(DD, WorkDate, @toTime) >= 0
				) AS a
			) AS b
		) AS c
	WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
        WHERE c.EmpId = att.EmpId
		    AND c.WorkDate = att.AttendanceDate
        )
END
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Auto_TimeRecord_Import] @CompanyId SMALLINT
	,@FromDate DATE
    ,@ToDate DATE
    ,@TimeRecordXml NVARCHAR(MAX) = ''
    ,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20250318@Tim
Task: import check in/out
DB: HRM

Revisions:
Param's Explanation:
- @TimeRecordXml: "<Root>
		<Row EmpNo={0} InOutType={1} RecordTime={2} />
	</Root>"
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SyncDate DATETIME = GETDATE()
	    ,@DocHandler INT
        ,@serverTimeZone SMALLINT = -4

	CREATE TABLE #tmpTimeRecord (
		EmpId INT
		,InOutType TINYINT
		,RecordTime DATETIME
        ,ClientRecordTime DATETIME
		)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@TimeRecordXml

	INSERT INTO #tmpTimeRecord (
        EmpId
        ,InOutType
        ,RecordTime
        ,ClientRecordTime
		)
	SELECT emp.EmpId
        ,InOutType
        ,RecordTime
        ,DATEADD(MINUTE, CASE WHEN config.[Value] IS NULL THEN 0 ELSE CAST(config.[Value] AS REAL) END * 60, DATEADD(HOUR, ABS(@serverTimeZone), d.RecordTime))
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (EmpNo VARCHAR(20), InOutType TINYINT, RecordTime DATETIME) AS d
        INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON d.EmpNo = emp.Code
            OR ISNULL(TRY_PARSE(emp.Code AS INT), 0) = ISNULL(TRY_PARSE(d.EmpNo AS INT), -1)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        LEFT JOIN dbo.SystemConfigs AS config WITH (NOLOCK) ON ce.CompanyId = config.CompanyId
        AND config.[Key] = 'TimeZone'
    WHERE ce.CompanyId = @CompanyId

	EXEC sp_xml_removedocument @DocHandler

    INSERT INTO dbo.TimeRecord (
		EmpId
		,InOutType
		,RecordTime
		,InsertDate
		)
    SELECT tmp.EmpId
        ,tmp.InOutType
        ,tmp.RecordTime
        ,@SyncDate
    FROM #tmpTimeRecord AS tmp WITH (NOLOCK)
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.TimeRecord AS t WITH (NOLOCK)
        WHERE t.EmpId = tmp.EmpId
	        AND DATEDIFF(SECOND, t.RecordTime, tmp.RecordTime) = 0
        )

    INSERT INTO dbo.tmpEmployeeAttendace (
		EmpId
		,WorkDate
		,InsertedDate
		)
	SELECT tmp.EmpId
		,CAST(DATEADD(DD, -1, tmp.ClientRecordTime) AS DATE)
		,@SyncDate
	FROM #tmpTimeRecord AS tmp WITH (NOLOCK)
	WHERE NOT EXISTS (
        SELECT 1 
        FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK) 
        WHERE att.EmpId = tmp.EmpId
	        AND att.WorkDate = CAST(DATEADD(DD, -1, tmp.ClientRecordTime) AS DATE)
        )

	UNION
	SELECT tmp.EmpId
		,CAST(tmp.ClientRecordTime AS DATE)
		,@SyncDate
	FROM #tmpTimeRecord AS tmp WITH (NOLOCK)
	WHERE NOT EXISTS (
		SELECT 1 
		FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK) 
		WHERE att.EmpId = tmp.EmpId 
			AND att.WorkDate = CAST(tmp.ClientRecordTime AS DATE)
		)

    EXEC dbo.EmployeeAttendance_ForWaitingCase @CompanyId = @CompanyId

	SELECT EmpId
	INTO #tmpEmployee
	FROM dbo.EmployeeCalendar WITH (NOLOCK)
	WHERE DATEDIFF(DD, WorkDate, @ToDate) = 0
		AND (
			ShiftId IS NOT NULL
			OR IsOffDay = 1
			OR IsHoliday = 1
			OR IsLeaveDay = 1
			)

	IF EXISTS (
			SELECT 1
			FROM dbo.Employee AS e WITH (NOLOCK)
				INNER JOIN #tmpEmployee AS tmp ON e.EmpId = tmp.EmpId
			WHERE e.[Enabled] = 1
				AND DATEDIFF(DD, e.JoinedDate, @todate) > 0
				AND (
					e.ResignedDate IS NULL
					OR DATEDIFF(DD, @todate, e.ResignedDate) > 0
					)
				AND e.EmpId NOT IN (
					SELECT EmpId
					FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
					WHERE DATEDIFF(DD, att.AttendanceDate, @todate) = 0
						AND att.EmpId = e.EmpId
					)
			)
	BEGIN
		INSERT INTO dbo.tmpEmployeeAttendace (
			EmpId
			,WorkDate
			,InsertedDate
			)
		SELECT e.EmpId
			,@todate
			,@SyncDate
		FROM dbo.Employee AS e WITH (NOLOCK)
			INNER JOIN #tmpEmployee AS ec ON e.EmpId = ec.EmpId
		WHERE e.[Enabled] = 1
			AND DATEDIFF(DD, e.JoinedDate, @todate) > 0
			AND (
				e.ResignedDate IS NULL
				OR DATEDIFF(DD, @todate, e.ResignedDate) > 0
				)
			AND e.EmpId NOT IN (
				SELECT EmpId
				FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
				WHERE DATEDIFF(DD, att.AttendanceDate, @todate) = 0
					AND att.EmpId = e.EmpId
				)
	END

	INSERT INTO dbo.tmpEmployeeAttendace (
		EmpId
		,WorkDate
		,InsertedDate
		)
	SELECT att.EmpId
		,att.AttendanceDate
		,@SyncDate
	FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
		INNER JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON att.EmpId = empca.EmpId
		AND att.AttendanceDate = empca.WorkDate
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON att.EmpId = e.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON e.GroupId = rul.GroupId
		AND es.IsLocal = rul.IsLocal
		AND rul.DisciplineTypeId = 2
	WHERE att.AttendanceDate BETWEEN @FromDate
				AND @ToDate
		AND ISNULL(att.ShiftId, '') <> ''
		AND empca.LeaveDay <> 1
		AND (
			(
				ISNULL(att.InFixed, '') = ''
				AND ISNULL(att.OutFixed, '') <> ''
				AND @SyncDate > att.ExpectedInTime
				AND DATEDIFF(MI, att.ExpectedInTime, @SyncDate) < 480
				)
			OR (
				ISNULL(att.InFixed, '') <> ''
				AND ISNULL(att.OutFixed, '') = ''
				AND @SyncDate > att.ExpectedOutTime
				AND DATEDIFF(MI, att.ExpectedOutTime, @SyncDate) < 480
				)
			)
		AND ISNULL(rul.[Value], 0) = 1
	
	UNION
	SELECT att.EmpId
		,att.AttendanceDate
		,@SyncDate
	FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON att.EmpId = e.EmpId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN dbo.DisciplineGroupRule AS rul WITH (NOLOCK) ON e.GroupId = rul.GroupId
		AND es.IsLocal = rul.IsLocal
		AND rul.DisciplineTypeId = 5
	WHERE att.AttendanceDate BETWEEN @FromDate
				AND @ToDate
		AND ISNULL(att.ShiftId, '') <> ''
		AND ISNULL(att.InFixed, '') = ''
		AND ISNULL(att.OutFixed, '') = ''
		AND @SyncDate > att.ExpectedOutTime
		AND DATEDIFF(MI, att.ExpectedOutTime, @SyncDate) < 480
		AND ISNULL(att.LeaveDay, 0) <> 1
		AND ISNULL(rul.[Value], 0) = 1

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpTimeRecord
END
GO