USE [bodb_HRM]
GO

IF NOT EXISTS (
    SELECT * 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_SCHEMA = 'dbo' 
      AND TABLE_NAME = 'CompanySecondmentEmployee'
)
BEGIN
CREATE TABLE [dbo].[CompanySecondmentEmployee](
	[EmpId] [int] NOT NULL,
	[CompanyId] [int] NOT NULL,
    [CreatedBy] [int] NULL,
    [CreatedDate] [datetime] NULL,
    [ModifiedBy] [int] NULL,
    [ModifiedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[EmpId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[CompanySecondmentEmployee_Delete]
  @EmpId INT,
  @ModifiedBy INT,
  @ErrCode INT = 0 OUTPUT,
  @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Delete secondment employee
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

    SET @xml = (
        SELECT EmpId AS '@EmpId'
            ,CompanyId as '@CompanyId'
        FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
        WHERE EmpId = @EmpId
        FOR XML PATH('Row')
            ,TYPE
    )
    SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')


    DELETE FROM dbo.CompanySecondmentEmployee
    WHERE EmpId = @EmpId;

    EXEC dbo.ActivityLog_Insert
		@UserId = @ModifiedBy
		,@ObjectTypeId = 3
		,@ObjectId = @EmpId
		,@OldData = @logOldData
		,@Data = NULL
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE[dbo].[CompanySecondmentEmployee_Get]
  AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Secondment employee list
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    SELECT cse.EmpId,
           cse.CompanyId as SecondCompanyId,
           c.Name AS SecondCompanyName,
           ce.CompanyId AS CurrentCompanyId,
           c2.Name AS CurrentCompanyName,
           e.Code AS EmpCode,
           e.NickName,
           e.FullName
    FROM dbo.CompanySecondmentEmployee AS cse WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON cse.EmpId = e.EmpId
    INNER JOIN dbo.Company AS c WITH (NOLOCK) ON cse.CompanyId = c.CompanyId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON cse.EmpId = ce.EmpId
    INNER JOIN dbo.Company AS c2 WITH (NOLOCK) ON ce.CompanyId = c2.CompanyId
    ORDER BY cse.ModifiedDate DESC;
END
GO


/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE[dbo].[CompanySecondmentEmployee_GetByEmpId]
  @EmpId INT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Secondment employee list
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    SELECT cse.EmpId,
           cse.CompanyId as SecondCompanyId,
           c.Name AS SecondCompanyName,
           ce.CompanyId AS CurrentCompanyId,
           c2.Name AS CurrentCompanyName,
           e.Code AS EmpCode,
           e.NickName,
           e.FullName
    FROM dbo.CompanySecondmentEmployee AS cse WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON cse.EmpId = e.EmpId
    INNER JOIN dbo.Company AS c WITH (NOLOCK) ON cse.CompanyId = c.CompanyId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON cse.EmpId = ce.EmpId
    INNER JOIN dbo.Company AS c2 WITH (NOLOCK) ON ce.CompanyId = c2.CompanyId
    WHERE cse.EmpId = @EmpId;
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[CompanySecondmentEmployee_Insert]
  @EmpId INT,
  @CompanyId INT,
  @CreatedBy INT,
  @ErrCode INT = 0 OUTPUT,
  @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Insert secondment employee
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentCompanyId INT;

    SELECT @CurrentCompanyId = CompanyId 
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId;

    IF @CurrentCompanyId = @CompanyId
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'Cannot set secondment company to their current company';
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
        WHERE EmpId = @EmpId
    )
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'Employee is already seconded to another company';
        RETURN;
    END

    INSERT INTO dbo.CompanySecondmentEmployee (EmpId, CompanyId, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
    VALUES (@EmpId, @CompanyId, @CreatedBy, GETDATE(), @CreatedBy, GETDATE());


	DECLARE @xml XML
		,@logData NVARCHAR(MAX)

	SET @xml = (
			SELECT EmpId AS '@EmpId'
				,CompanyId as '@CompanyId'
			FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
			WHERE EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert
		@ObjectTypeId = 3
		,@ObjectId = @EmpId
		,@UserId = @CreatedBy
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE[dbo].[CompanySecondmentEmployee_Update]
  @EmpId INT,
  @OldEmpId INT = NULL,
  @CompanyId INT,
  @ModifiedBy INT,
  @ErrCode INT = 0 OUTPUT,
  @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Update secondment employee
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentCompanyId INT;
    DECLARE @ExistingEmpId INT;
    

    SELECT @CurrentCompanyId = CompanyId 
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId;

    IF @CurrentCompanyId = @CompanyId
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'Cannot set secondment company to their current company. Please select a different company.';
        RETURN;
    END

    -- Check for duplicate secondment records
    IF EXISTS (
        SELECT 1
        FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
        WHERE EmpId = @EmpId
        AND (@OldEmpId IS NULL OR EmpId <> @OldEmpId)
    )
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'Employee already exists in secondment records.';
        RETURN;
    END

    DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

    SET @xml = (
        SELECT EmpId AS '@EmpId'
            ,CompanyId as '@CompanyId'
        FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
        WHERE EmpId = @EmpId
        FOR XML PATH('Row')
            ,TYPE
    )
    SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

    -- If OldEmpId is provided and different from EmpId, update the old record
    IF @OldEmpId IS NOT NULL AND @OldEmpId <> @EmpId
    BEGIN
        UPDATE dbo.CompanySecondmentEmployee
        SET EmpId = @EmpId,
            CompanyId = @CompanyId,
            ModifiedBy = @ModifiedBy,
            ModifiedDate = GETDATE()
        WHERE EmpId = @OldEmpId;
    END
    ELSE
    BEGIN
        -- Update existing record
        UPDATE dbo.CompanySecondmentEmployee
        SET CompanyId = @CompanyId,
            ModifiedBy = @ModifiedBy,
            ModifiedDate = GETDATE()
        WHERE EmpId = @EmpId;
    END

    SET @xml = (
    SELECT EmpId AS '@EmpId'
        ,CompanyId as '@CompanyId'
    FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId
    FOR XML PATH('Row')
        ,TYPE
    )
    SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

    EXEC dbo.ActivityLog_Insert
		 @ObjectTypeId = 3
		,@ObjectId = @EmpId
        ,@UserId = @ModifiedBy
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END

GO


/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Employee_GroupScope_Get] 
	@query NVARCHAR(256) = NULL,
	@teamIds VARCHAR(MAX) = '',
	@enable BIT = NULL,
	@isDelete BIT = NULL,
	@pageNumber INT = 1,
	@pageSize INT = NULL,
	@totalRow INT = NULL OUTPUT,
	@titleId INT = NULL,
	@companyIds VARCHAR(MAX) = ''
AS
/*
	Created: 20250429@Jay.Do
	Task: get employees in group space 
	DB: bodb_HRM

	Revisions:
        20250507@Jay.Do: remove dynamic sql
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @GroupsList TABLE (GroupId INT)

	INSERT INTO @GroupsList (GroupId)
	SELECT value
	FROM STRING_SPLIT(@teamIds, ',')

	DECLARE @CompaniesList TABLE (CompanyId INT)

	INSERT INTO @CompaniesList (CompanyId)
	SELECT value
	FROM STRING_SPLIT(@companyIds, ',')

	DECLARE @Result TABLE (
		CtrId INT,
		EmpId INT,
		EmployeeCode NVARCHAR(50),
		NickName NVARCHAR(100),
		JobTitleId INT,
		[Enabled] BIT,
		JoinedDate DATETIME,
		ResignedDate DATETIME,
		isDeleted BIT,
		FullName NVARCHAR(200),
		IsLocal BIT,
		IsSpecial BIT,
		CompanyDate DATETIME,
		JobTitle NVARCHAR(100),
		CompanyId INT,
		Company NVARCHAR(200),
		UnitId INT,
		UnitCode NVARCHAR(50),
		UnitPIC NVARCHAR(100),
		TeamId INT,
		TeamCode NVARCHAR(50),
		TeamName NVARCHAR(200),
		TeamPIC NVARCHAR(100),
		DepartmentId INT,
		DepartmentCode NVARCHAR(50),
		DepartmentName NVARCHAR(200),
		DepartmentPIC NVARCHAR(100),
		ManagementLevel NVARCHAR(100),
		JobLevel NVARCHAR(100)
	)

	INSERT INTO @Result
	SELECT 
		e.CtrId,
		e.EmpId,
		e.Code AS EmployeeCode,
		e.NickName,
		e.JobTitleId,
		e.[Enabled],
		e.JoinedDate,
		e.ResignedDate,
		e.isDeleted,
		e.FullName,
		s.IsLocal,
		s.IsTopManager AS IsSpecial,
		s.CompanyDate,
		jt.[Name] AS JobTitle,
		c.CompanyId,
		c.[Name] AS Company,
		u.GroupUnitId AS UnitId,
		u.Code AS UnitCode,
		eu.NickName AS UnitPIC,
		g.GroupId AS TeamId,
		g.Code AS TeamCode,
		g.[Name] AS TeamName,
		eg.NickName AS TeamPIC,
		d.DepartmentId,
		d.Code AS DepartmentCode,
		d.[Name] AS DepartmentName,
		ed.NickName AS DepartmentPIC,
		ml.[Name] AS ManagementLevel,
		jl.[Name] AS JobLevel
	FROM dbo.Employee AS e WITH (NOLOCK)
		LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId 
		LEFT JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = e.EmpId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID
		LEFT JOIN dbo.[Department] AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
		LEFT JOIN dbo.[Unit] AS u WITH (NOLOCK) ON d.UnitId = u.UnitId
		LEFT JOIN dbo.[Lookup] l WITH (NOLOCK) ON l.Code = 'JT'
		LEFT JOIN dbo.LookupData jt WITH (NOLOCK) ON l.Id = jt.LookupId AND e.JobTitleId = jt.Id
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		LEFT JOIN Employee eu WITH (NOLOCK) ON eu.EmpId = u.PICEmpId
		LEFT JOIN Employee ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN Employee eg WITH (NOLOCK) ON eg.EmpId = g.PICEmpId
		LEFT JOIN ManagementLevel ml WITH (NOLOCK) ON e.ManagementLevelId = ml.ManagementLevelId
		LEFT JOIN JobLevel jl WITH (NOLOCK) ON e.JobLevelId = jl.JobLevelId
	WHERE 
		(@enable IS NULL OR (ISNULL(e.isDeleted, 0) = 0 AND e.Enabled = @enable))
		AND (@isDelete IS NULL OR e.isDeleted = @isDelete)
		AND (@query IS NULL OR e.NickName LIKE '%' + @query + '%')
		AND (ISNULL( @teamIds, '') = ''  OR e.GroupId IN (SELECT GroupId FROM @GroupsList))
		AND (ISNULL( @companyIds, '') = '' OR ce.CompanyId IN (SELECT CompanyId FROM @CompaniesList))

	SELECT @totalRow = COUNT(*) FROM @Result

	-- Final result
	IF @pageSize IS NULL OR @pageSize <= 0
	BEGIN
		SELECT * FROM @Result
		ORDER BY UnitCode DESC, DepartmentCode DESC, TeamCode DESC
	END
	ELSE
	BEGIN
		SELECT * FROM @Result
		ORDER BY UnitCode DESC, DepartmentCode DESC, TeamCode DESC
		OFFSET (@pageNumber - 1) * @pageSize ROWS
		FETCH NEXT @pageSize ROWS ONLY
	END
END

GO
/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[FnB_Department_GetByLastModifiedDate]
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
Created: 20230220@Quinn.Vo
Task: Get last modified date
DB: FBM
Original: 

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
		,[UnitId]
		,[IsActive]
		,d.[ModifiedDate]
		,d.[IsDeleted]
	FROM dbo.Department AS d WITH (NOLOCK)
	WHERE d.ModifiedDate > @LastModifiedDate
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[FnB_Employee_GetByLastModifiedDate] 
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
Created: 20140320@Quinn.Vo
Task: Get all employee from change date
DB: NexEPA
Original: 

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
		,CASE WHEN ld.OldId IS NOT NULL THEN ld.OldId ELSE ld.Id END  as JobTitleId
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
		,e.EmpId
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

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER  PROCEDURE [dbo].[FnB_Employee_GetSecondmentCompany] 
	@CompanyId SMALLINT
AS
/*
Created: Hank.Nguyen@2025-05-27
Task: Get all secondment employees from change date
DB: NexEPA
Original: 

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
		,e.[Enabled]
		,ISNULL(e.isDeleted, 0) AS IsDeleted
		,e.JoinedDate
		,e.ConfirmedDate
		,es.IsLocal
		,e.GroupId AS TeamId
		,CASE 
			WHEN e.ModifiedDate IS NULL THEN e.CreatedDate
			ELSE e.ModifiedDate
			END AS ModifiedDate
		,es.Unit AS CostCenter
		,e.JobLevelId
		,e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.CompanySecondmentEmployee AS cs WITH (NOLOCK) ON cs.EmpId = e.EmpId
	WHERE cs.CompanyId = @CompanyId 
	ORDER BY e.ModifiedDate
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[FnB_EmployeeCalendar_GetByLastModifiedDate]
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
Created: 20141002@Quinn.Vo
Task: Get employee calendar from change date
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpEmployeeCalendarChange
	(
		EmpId INT,
		WorkDate DATE
	)

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

	SELECT 
	a.UserId,
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
	SELECT
	  tcl.[WorkDate]
      ,e.EmpId AS UserId
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

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
    - 2024-03-21: Added support for secondment employee groups
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NOT NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(HH, - 1, @LastModifiedDate)
	END

	-- Get regular employee groups
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
		,1 as DataSource
	FROM dbo.[Group] AS g WITH (NOLOCK)
	    LEFT JOIN dbo.Department AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
	WHERE g.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR ISNULL(g.ModifiedDate, g.CreatedDate) > @LastModifiedDate)

	UNION

	-- Get secondment employee groups
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
		,2 as DataSource
	FROM dbo.[Group] AS g WITH (NOLOCK)
	    LEFT JOIN dbo.Department AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
	    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.GroupId = g.GroupId
	    INNER JOIN dbo.CompanySecondmentEmployee AS cse WITH (NOLOCK) ON cse.EmpId = e.EmpId
	WHERE cse.CompanyId = @CompanyId
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[FnB_Section_GetByLastModifiedDate]
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
Created: 20230220@Quinn.Vo
Task: Get section by last modified date.
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(YYYY, -10, GETDATE())
	END
	
	SELECT DISTINCT d.[Code]
		,d.[Name]
		,d.[IsActive]
		,d.[ModifiedDate]
		,d.[IsDeleted]
		,d.[DepartmentId]
		,d.[DepartmentId]  AS [SectionId]
	FROM dbo.Department AS d WITH (NOLOCK)
	WHERE d.ModifiedDate > @LastModifiedDate
END

GO


/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[FnB_Unit_GetByLastModifiedDate]
	@LastModifiedDate DATETIME,
	@CompanyId SMALLINT
AS
/*
Created: 20230220@Quinn.Vo
Task: Get last modified date
DB: FBM
Original: 

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
		,u.Code as [Name]
		,u.IsActive
		,u.ModifiedDate
		,u.IsDeleted
	FROM dbo.Unit AS u WITH (NOLOCK)
	WHERE u.ModifiedDate > @LastModifiedDate
END
GO