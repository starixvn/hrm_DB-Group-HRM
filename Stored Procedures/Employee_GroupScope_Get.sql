/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
        20250627@Hank.Nguyen: check GroupId in both Employee and CompanyEmployee tables
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
		JoinedDate VARCHAR(50),
		ResignedDate VARCHAR(50),
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
		ISNULL(ce.[Enabled], e.[Enabled]) AS [Enabled],
		e.JoinedDate,
		ISNULL(ce.ResignedDate, e.ResignedDate) AS ResignedDate,
		ISNULL(ce.isDeleted, e.isDeleted) AS isDeleted,
		e.FullName,
		s.IsLocal,
		s.IsTopManager AS IsSpecial,
		ISNULL(ce.CompanyDate, s.CompanyDate) AS CompanyDate,
		COALESCE(ejt.[Name], jt.[Name]) AS JobTitle,
		c.CompanyId,
		c.[Name] AS Company,
		sub.Name AS SubCompany,
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
		COALESCE(mg.[Name], ml.[Name]) AS ManagementLevel,
		jg.[Name] AS JobLevel
	FROM dbo.Employee AS e WITH (NOLOCK)
		LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND (ce.IsSpecialUser IS NULL OR ce.IsSpecialUser = 0)
		LEFT JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = e.EmpId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON COALESCE(e.GroupID, ce.GroupId) = g.GroupID
		LEFT JOIN dbo.[Department] AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
		LEFT JOIN dbo.[Unit] AS u WITH (NOLOCK) ON d.UnitId = u.UnitId
		LEFT JOIN dbo.[Lookup] l WITH (NOLOCK) ON l.Code = 'JT'
		LEFT JOIN dbo.LookupData jt WITH (NOLOCK) ON l.Id = jt.LookupId AND e.JobTitleId = jt.Id
		LEFT JOIN HRM.dbo.JobTitle ejt WITH (NOLOCK) ON ejt.JobTitleId = e.JobTitleId AND ejt.IsDeleted = 0
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		LEFT JOIN dbo.SubCompany sub WITH (NOLOCK) ON sub.SubCompanyId = ce.SubCompanyId
		LEFT JOIN Employee eu WITH (NOLOCK) ON eu.EmpId = u.PICEmpId
		LEFT JOIN Employee ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN Employee eg WITH (NOLOCK) ON eg.EmpId = g.PICEmpId
		LEFT JOIN HRM.dbo.EmployeeManagementGrade em WITH (NOLOCK) ON em.EmpId = e.EmpId AND em.IsCurrentUsed = 1 AND ISNULL(em.IsDeleted, 0) = 0
		LEFT JOIN HRM.dbo.ManagementGrade mg WITH (NOLOCK) ON mg.ManagementGradeId = em.ManagementGradeId AND ISNULL(mg.IsDeleted, 0) = 0
		LEFT JOIN ManagementLevel ml WITH (NOLOCK) ON e.ManagementLevelId = ml.ManagementLevelId
		LEFT JOIN HRM.dbo.EmployeeJobGrade ejg WITH (NOLOCK) ON ejg.EmpId = e.EmpId AND ejg.IsCurrentUsed = 1 AND ISNULL(ejg.IsDeleted, 0) = 0
		LEFT JOIN JobLevel jg WITH (NOLOCK) ON COALESCE(e.JobLevelId, ejg.JobGradeId) = jg.JobLevelId 
	WHERE 
		(@enable IS NULL OR (ISNULL(ISNULL(ce.isDeleted, e.isDeleted), 0) = 0 AND COALESCE(ce.Enabled, e.Enabled) = @enable))
		AND (@isDelete IS NULL OR ISNULL(ISNULL(ce.isDeleted, e.isDeleted), 0) = @isDelete)
		AND (@query IS NULL OR e.NickName LIKE '%' + @query + '%')
		AND (ISNULL( @teamIds, '') = ''  OR COALESCE(ce.GroupId, e.GroupId) IN (SELECT GroupId FROM @GroupsList))
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