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
	IF @pageSize IS NULL
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