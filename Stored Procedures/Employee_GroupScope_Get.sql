/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GroupScope_Get]
(
    @query NVARCHAR(256) = NULL,
    @teamIds VARCHAR(MAX) = '',
    @enable BIT = NULL,
    @isDelete BIT = NULL,
    @pageNumber INT = 1,
    @pageSize INT = NULL,
    @totalRow INT = NULL OUTPUT,
    @titleId INT = NULL,
    @companyIds VARCHAR(MAX) = '',
    @isCtrID BIT = NULL,
    @isOutsource BIT = NULL,
    @hasPermissionViewAll BIT = 0,
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

	DECLARE @NexcelId TINYINT = 1, @LumiId TINYINT = 2,  @NexVisionId TINYINT = 34

	DECLARE @Result TABLE (
		CtrId INT,
		EmpId INT,
		EmployeeCode NVARCHAR(50),
		NickName NVARCHAR(100),
		JobTitleId INT,
		[Enabled] BIT,
		JoinedDate VARCHAR(50),
		ResignedDate VARCHAR(50),
		ResignedReason NVARCHAR(1000),
		isDeleted BIT,
		FullName NVARCHAR(200),
		IsLocal BIT,
		IsSpecial BIT,
		CompanyDate VARCHAR(50),
		JobTitle NVARCHAR(100),
		CompanyId INT,
		Company NVARCHAR(200),
		SubCompany NVARCHAR(200),
		UnitId INT,
		GroupUnitId INT,
		UnitCode NVARCHAR(50),
		UnitPIC NVARCHAR(100),
		TeamId INT,
		TeamCode NVARCHAR(50),
		TeamName NVARCHAR(200),
		TeamPIC NVARCHAR(100),
		AccountableArea  NVARCHAR(100),
		DepartmentId INT,
		DepartmentCode NVARCHAR(50),
		DepartmentName NVARCHAR(200),
		DepartmentPIC NVARCHAR(100),
		ManagementLevel NVARCHAR(100),
		JobLevel NVARCHAR(100),
		[Location] NVARCHAR(100),
		Salary NVARCHAR(100),
		Currency NVARCHAR(10),
		CountryName NVARCHAR(100),
		Gender NVARCHAR(20),
		DOB NVARCHAR(100)
	)

	INSERT INTO @Result
	SELECT 
		e.CtrId,
		ce.EmpId,
		ce.Code AS EmployeeCode,
		ce.NickName,
		ce.JobTitleId,
		ce.[Enabled],
		e.JoinedDate,
		e.ResignedDate,
		e.ResignedReason,
		ce.isDeleted,
		e.FullName,
		s.IsLocal,
		ce.IsSpecialUser AS IsSpecial,
		ce.CompanyDate,
		COALESCE(ejt.[Name], jt.[Name]) AS JobTitle,
		c.CompanyId,
		c.[Name] AS Company,
		sub.Name AS SubCompany,
		u.UnitId,
		u.GroupUnitId,
		u.Code AS UnitCode,
		eu.NickName AS UnitPIC,
		g.GroupId AS TeamId,
		g.Code AS TeamCode,
		g.[Name] AS TeamName,
		eg.NickName AS TeamPIC,
		g.AccountableArea,
		d.DepartmentId,
		d.Code AS DepartmentCode,
		d.[Name] AS DepartmentName,
		ed.NickName AS DepartmentPIC,
		COALESCE(mg.[Name], ml.[Name]) AS ManagementLevel,
		jg.[Name] AS JobLevel,
		ct.CountryCodeISO3 AS [Location],
		CASE
			WHEN ce.Salary IS NOT NULL
				THEN ce.Salary
			WHEN s.IsLocal = 1
				THEN std.LocalSalary
			ELSE std.ExpatSalary
		END AS Salary,
		CASE 
			WHEN ISNULL(scc.[Value], '') <> ''
				THEN (
					SELECT TOP 1 c.CurrencyCode
					FROM dbo.Currency c
					WHERE c.Id =
					(
						SELECT TOP 1 value
						FROM STRING_SPLIT(scc.[Value], ',')
					)
				)
			ELSE ''
		END AS Currency,
		ect.CountryName,
		e.Gender,
		e.DOB
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.UserId = e.UserId AND (ce.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId) OR ce.IsSpecialUser = 0)
		LEFT JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = ce.EmpId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupID = g.GroupID
		LEFT JOIN dbo.[Department] AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
		LEFT JOIN dbo.[Unit] AS u WITH (NOLOCK) ON d.UnitId = u.UnitId
		LEFT JOIN dbo.[Lookup] AS l WITH (NOLOCK) ON l.Code = 'JT'
		LEFT JOIN dbo.LookupData jt WITH (NOLOCK) ON l.Id = jt.LookupId AND ce.JobTitleId = jt.Id
		LEFT JOIN HRM.dbo.JobTitle ejt WITH (NOLOCK) ON ejt.JobTitleId = ce.JobTitleId AND ejt.IsDeleted = 0
		LEFT JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		LEFT JOIN dbo.SubCompany AS sub WITH (NOLOCK) ON sub.SubCompanyId = ce.SubCompanyId
		LEFT JOIN CompanyEmployee eu WITH (NOLOCK) ON eu.EmpId = u.PICEmpId
		LEFT JOIN CompanyEmployee ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN CompanyEmployee eg WITH (NOLOCK) ON eg.EmpId = g.PICEmpId
		LEFT JOIN HRM.dbo.EmployeeManagementGrade em WITH (NOLOCK) ON em.EmpId = ce.EmpId AND em.IsCurrentUsed = 1 AND ISNULL(em.IsDeleted, 0) = 0
		LEFT JOIN HRM.dbo.ManagementGrade AS mg WITH (NOLOCK) ON mg.ManagementGradeId = em.ManagementGradeId AND ISNULL(mg.IsDeleted, 0) = 0
		LEFT JOIN ManagementLevel ml WITH (NOLOCK) ON ce.ManagementLevelId = ml.ManagementLevelId
		LEFT JOIN HRM.dbo.EmployeeJobGrade ejg WITH (NOLOCK) ON ejg.EmpId = ce.EmpId AND ejg.IsCurrentUsed = 1 AND ISNULL(ejg.IsDeleted, 0) = 0
		LEFT JOIN JobLevel jg WITH (NOLOCK) ON COALESCE(ce.JobLevelId, ejg.JobGradeId) = jg.JobLevelId 
		LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON ct.CountryCode = c.CountryCode
		LEFT JOIN dbo.SalaryStructureDetail AS std WITH (NOLOCK) ON std.JobLevelId = e.JobLevelId 
			AND ce.SalaryStructureId = std.SalaryStructureId
		LEFT JOIN dbo.SystemConfigs AS scc ON [Key] = 'Currency'
			AND scc.CompanyId = ce.CompanyId
		LEFT JOIN dbo.Country AS ect (NOLOCK) ON s.CountryCode = ect.CountryCode
	WHERE 
		(@enable IS NULL OR (ISNULL(ce.isDeleted, 0) = 0 AND ce.Enabled = @enable))
		AND (@isDelete IS NULL OR ISNULL(ce.isDeleted, 0) = @isDelete)
		AND (@query IS NULL OR ce.NickName LIKE '%' + @query + '%')
		AND (ISNULL( @teamIds, '') = ''  OR ce.GroupId IN (SELECT GroupId FROM @GroupsList))
		AND (ISNULL( @companyIds, '') = '' OR ce.CompanyId IN (SELECT CompanyId FROM @CompaniesList))
		AND (
			@isCtrID IS NULL
			OR (@isCtrID = 1 AND e.CtrID IS NOT NULL)
			OR (@isCtrID = 0 AND e.CtrID IS NULL)
		)
		AND (
			@isOutsource IS NULL
			OR g.IsOutsource = @isOutsource
		)
        AND (
            @hasPermissionViewAll = 1
            OR u.PICEmpId = @actorId
            OR d.PICEmpId = @actorId
            OR g.PICEmpId = @actorId
        )

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