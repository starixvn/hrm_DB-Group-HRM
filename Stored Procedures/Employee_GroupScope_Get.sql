/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GroupScope_Get]
(
    @query NVARCHAR(256) = NULL,
    @teamIds VARCHAR(MAX) = '',
    @enable BIT = NULL,
    @isDelete BIT = NULL,
    @totalRow INT = NULL OUTPUT,
    @titleId INT = NULL,
    @companyIds VARCHAR(MAX) = '',
    @isCtrID BIT = NULL,
    @isOutsource BIT = NULL,
    @actorId INT = NULL
)
AS
/*
	Created: 20250429@Jay.Do
	Task: get employees in group space 
	DB: bodb_HRM

	Revisions:
        20250507@Jay.Do: remove dynamic sql
        20250627@Hank.Nguyen: check GroupId in both Employee and CompanyEmployee tables
        20250801@Lilac.Nguyen: get more info for Profit Center Report [Redmine: #234645]
		20250805@Lilac.Nguyen: get location(CountryCodeISO3) [Redmine: #234645]
		20250815@Jay.Do: enhancement [Redmine: #236138]
		20250814@Lilac: restructure for transfer [Redmine: #235678]
		20250828@Mira: restructure for transfer [Redmine: #235678]
		20250903@Jay.Do: update role [Redmine: #237201]
		20251020@Lilac: rename LocalSalary to BasicSalary [Redmine: #241810]
		20251022@Mira: remove salary info  [Redmine: #241812]

*/
BEGIN
	SET NOCOUNT ON;

    CREATE TABLE #tmpGroup(GroupId INT PRIMARY KEY)

	INSERT INTO #tmpGroup(GroupId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@teamIds, ',')

	CREATE TABLE #tmpCompany(CompanyId SMALLINT PRIMARY KEY, CurrencyCode VARCHAR(20))

    IF ISNULL(@companyIds, '') = ''
    BEGIN
        INSERT INTO #tmpCompany(CompanyId)
        SELECT CompanyId
        FROM dbo.Company WITH (NOLOCK)
    END
    ELSE
    BEGIN
        INSERT INTO #tmpCompany(CompanyId)
	    SELECT DISTINCT c.value
	    FROM STRING_SPLIT(@companyIds, ',') AS c
    END

    UPDATE tmp
    SET tmp.CurrencyCode = (
        SELECT TOP 1 c.CurrencyCode
		FROM dbo.Currency AS c WITH (NOLOCK)
		WHERE c.Id =
		    (
			    SELECT TOP 1 CAST(tmpc.value AS INT)
			    FROM dbo.SystemConfigs AS sc WITH (NOLOCK)
                    CROSS APPLY STRING_SPLIT(sc.[Value], ',') AS tmpc
                WHERE sc.[Key] = 'Currency'
                    AND sc.CompanyId = tmp.CompanyId
		    )
        )
    FROM #tmpCompany AS tmp

    CREATE TABLE #tmpEmployeeInfo(
        CtrId INT,
        EmpId INT PRIMARY KEY,
        EmployeeCode NVARCHAR(50),
        Nickname NVARCHAR(100),
        FullName NVARCHAR(200),
        Gender TINYINT,
        DOB DATE,
        JobTitleId INT, JobTitle NVARCHAR(100),
        [Enabled] BIT,
        JoinedDate DATE,
        ResignedDate DATE, ResignedReason NVARCHAR(300),
        isDeleted BIT, IsLocal BIT, IsSpecial BIT,
        CompanyDate DATE, CompanyId SMALLINT, Company NVARCHAR(200), SubCompany NVARCHAR(200),
        UnitId INT, GroupUnitId INT, UnitCode NVARCHAR(50), UnitPIC NVARCHAR(100), UnitPICEmpId INT, UnitSupporterEmpId VARCHAR(MAX),
        TeamId INT, TeamCode NVARCHAR(50), TeamName NVARCHAR(200), TeamPIC NVARCHAR(100), AccountableArea NVARCHAR(100),
        DepartmentId INT, DepartmentCode NVARCHAR(50), DepartmentName NVARCHAR(200), DepartmentPIC NVARCHAR(100), DepartmentPICId INT, DepartmentSupporterEmpId VARCHAR(MAX),
        ManagementLevelId INT, ManagementLevel NVARCHAR(100),
        JobLevelId INT, JobLevel NVARCHAR(100),
        [Location] NVARCHAR(100),
        Currency NVARCHAR(10),
        CountryName NVARCHAR(100)
	)
    CREATE NONCLUSTERED INDEX IX_tmpEmployeeInfo_CompanyId_EmpId
    ON #tmpEmployeeInfo (CompanyId, EmpId) INCLUDE (ManagementLevelId, JobLevelId, JobTitleId)

	DECLARE @NexcelId SMALLINT = 1, @LumiId SMALLINT = 2,  @NexVisionId SMALLINT = 34

	INSERT INTO #tmpEmployeeInfo(
        CtrId, EmpId,
        EmployeeCode,
        Nickname, FullName,
        Gender,
        DOB,
        JobTitleId,
        [Enabled],
        JoinedDate,
        ResignedDate, ResignedReason,
        isDeleted, IsLocal, IsSpecial,
        CompanyDate, CompanyId, Company, SubCompany,
        UnitId, GroupUnitId, UnitCode, UnitPIC, UnitPICEmpId, UnitSupporterEmpId,
        TeamId, TeamCode, TeamName, TeamPIC, AccountableArea,
        DepartmentId, DepartmentCode, DepartmentName, DepartmentPIC, DepartmentPICId, DepartmentSupporterEmpId,
        ManagementLevelId, JobLevelId,
        [Location],
        Currency,
        CountryName
	)
    SELECT 
		e.CtrId,
		ce.EmpId,
		ce.Code AS EmployeeCode,
		ce.Nickname, e.FullName,
		e.Gender,
		e.DOB,
		ce.JobTitleId,
		ce.[Enabled],
		e.JoinedDate,
		e.ResignedDate, e.ResignedReason,
		ce.isDeleted, s.IsLocal, ce.IsSpecialUser,
		ce.CompanyDate, c.CompanyId, c.[Name] AS Company, sub.Name AS SubCompany,
		u.UnitId, u.GroupUnitId, u.Code AS UnitCode, eu.Nickname AS UnitPIC, u.PICEmpId AS UnitPICEmpId, u.SupporterEmpId AS UnitSupporterEmpId,
		g.GroupId, g.Code, g.[Name], eg.Nickname, g.AccountableArea,
		d.DepartmentId, d.Code AS DepartmentCode, d.[Name], ed.Nickname, d.PICEmpId, d.SupporterEmpId,
		ce.ManagementLevelId, ce.JobLevelId,
		ct.CountryCodeISO3,
		tmpc.CurrencyCode,
		ect.CountryName
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.UserId = e.UserId
        INNER JOIN #tmpCompany AS tmpc ON ce.CompanyId = tmpc.CompanyId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupID = g.GroupID
		INNER JOIN dbo.[Department] AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
		INNER JOIN dbo.[Unit] AS u WITH (NOLOCK) ON d.UnitId = u.UnitId
		LEFT JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = ce.EmpId
		LEFT JOIN dbo.SubCompany AS sub WITH (NOLOCK) ON sub.SubCompanyId = ce.SubCompanyId
		LEFT JOIN dbo.CompanyEmployee AS eu WITH (NOLOCK) ON eu.EmpId = u.PICEmpId
		LEFT JOIN dbo.CompanyEmployee AS ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN dbo.CompanyEmployee AS eg WITH (NOLOCK) ON eg.EmpId = g.PICEmpId
		LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON ct.CountryCode = c.CountryCode
		LEFT JOIN dbo.Country AS ect (NOLOCK) ON s.CountryCode = ect.CountryCode

	WHERE (ce.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId) OR ce.IsSpecialUser = 0)
		AND (@enable IS NULL OR (ISNULL(ce.isDeleted, 0) = 0 AND ce.Enabled = @enable))
		AND (@isDelete IS NULL OR ISNULL(ce.isDeleted, 0) = @isDelete)
		AND (@query IS NULL OR ce.NickName LIKE '%' + @query + '%')
		AND (ISNULL(@teamIds, '') = ''  OR ce.GroupId IN (SELECT GroupId FROM #tmpGroup))
		AND (
			@isCtrID IS NULL
			OR (@isCtrID = 1 AND e.CtrID IS NOT NULL)
			OR (@isCtrID = 0 AND e.CtrID IS NULL)
		)
		AND (
			@isOutsource IS NULL
			OR g.IsOutsource = @isOutsource
		)

    UPDATE e
    SET e.JobTitle = jt.[Name]
    FROM #tmpEmployeeInfo AS e
        INNER JOIN dbo.LookupData AS jt WITH (NOLOCK) ON e.JobTitleId = jt.Id AND jt.CompanyId = e.CompanyId
        INNER JOIN dbo.[Lookup] AS l WITH (NOLOCK) ON l.Id = jt.LookupId AND l.Code = 'JT'
    WHERE e.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId)

    UPDATE e
    SET e.JobLevel = ejt.[Name]
    FROM #tmpEmployeeInfo AS e
        INNER JOIN HRM.dbo.JobTitle AS ejt WITH (NOLOCK) ON ejt.JobTitleId = e.JobTitleId AND ejt.IsDeleted = 0
    WHERE e.CompanyId IN (@NexcelId, @LumiId, @NexVisionId)

    UPDATE e
    SET e.ManagementLevel = ml.[Name]
    FROM #tmpEmployeeInfo AS e
        INNER JOIN dbo.ManagementLevel AS ml WITH (NOLOCK) ON e.ManagementLevelId = ml.ManagementLevelId
    WHERE e.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId)

    UPDATE e
    SET e.JobLevel = jl.[Name]
    FROM #tmpEmployeeInfo AS e
        INNER JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON e.JobLevelId = jl.JobLevelId
    WHERE e.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId)

    UPDATE e
    SET e.ManagementLevel = mg.[Name]
    FROM #tmpEmployeeInfo AS e
        INNER JOIN HRM.dbo.EmployeeManagementGrade AS em WITH (NOLOCK) ON em.EmpId = e.EmpId AND em.IsCurrentUsed = 1 AND ISNULL(em.IsDeleted, 0) = 0
        INNER JOIN HRM.dbo.ManagementGrade AS mg WITH (NOLOCK) ON mg.ManagementGradeId = em.ManagementGradeId AND ISNULL(mg.IsDeleted, 0) = 0
    WHERE e.CompanyId IN (@NexcelId, @LumiId, @NexVisionId)

    UPDATE e
    SET e.JobLevel = jl.[Name]
    FROM #tmpEmployeeInfo AS e
        INNER JOIN HRM.dbo.EmployeeJobGrade ejg WITH (NOLOCK) ON ejg.EmpId = e.EmpId AND ejg.IsCurrentUsed = 1 AND ISNULL(ejg.IsDeleted, 0) = 0
		INNER JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON ejg.JobGradeId = jl.JobLevelId
    WHERE e.CompanyId IN (@NexcelId, @LumiId, @NexVisionId)

    SELECT 
        CtrId,
        EmpId,
        EmployeeCode,
        Nickname,
        FullName,
        Gender,
        DOB,
        JobTitleId,
        JobTitle,
        [Enabled],
        JoinedDate,
        ResignedDate,
        ResignedReason,
        isDeleted,
        IsLocal,
        IsSpecial,
        CompanyDate,
        CompanyId,
        Company,
        SubCompany,
        UnitId,
        GroupUnitId,
        UnitCode,
        UnitPIC,
        UnitPICEmpId,
        UnitSupporterEmpId,
        TeamId,
        TeamCode,
        TeamName,
        TeamPIC,
        AccountableArea,
        DepartmentId,
        DepartmentCode,
        DepartmentName,
        DepartmentPIC,
        DepartmentPICId,
        DepartmentSupporterEmpId,
        ManagementLevelId,
        ManagementLevel,
        JobLevelId,
        JobLevel,
        [Location],
        Currency,
        CountryName
    FROM #tmpEmployeeInfo

    DROP TABLE #tmpCompany
    DROP TABLE #tmpGroup
    DROP TABLE #tmpEmployeeInfo
END