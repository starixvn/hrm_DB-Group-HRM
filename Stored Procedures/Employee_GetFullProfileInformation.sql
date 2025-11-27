/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
	- 20250714@Mira: get joblevel and mGrade [#Redmine: 232030]
	- 20250812@Mira: tranfer employee [Redmine: #235678]
	20251127@Lilac: get transfer in, out dates [Redmine: #245211]
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
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
	WHERE (
			@isDelete IS NULL
			OR ce.isDeleted = @isDelete
			)
		AND (
			@enable IS NULL
			OR ce.[Enabled] = @enable
			)
		AND (
			@titleId IS NULL
			OR ce.JobTitleId = @titleId
			)
		AND (
			ISNULL(@teamIds, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tmpGroup AS tmpgr WITH (NOLOCK)
				WHERE ce.GroupId = tmpgr.GroupId
				)
			)
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			ISNULL(@query, '') = ''
			OR ce.NickName LIKE '%' + @query + '%'
			OR e.FullName LIKE '%' + @query + '%'
			)

	SELECT DISTINCT ce.EmpId
		,ce.Code
		,e.FullName
		,ce.NickName
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
		,ce.Email
		,e.Qualification
		,e.Major
		,g.[Name] AS TeamName
		,dep.[Name] AS DepartmentName
		,unit.[Name] AS UnitName
		,unit.[Code] AS UnitCode
		,ce.EmployeeCard
		,c.[Name] AS CompanyName
		, sc.[Name] AS SubCompanyName
		,ce.CompanyDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.ResignedReason
		,e.JoinedDate
		,e.MilitaryFromDate
		,e.MilitaryToDate
		,etf.TransferOutDate AS DateTransferOut
		,ett.TransferInDate	AS DateTransferIn
		,jt.[Name] AS JobTitle
		,jl.[Name] AS JobLevel
		,ml.[Name] AS ManagementLevel
		,ce.TeamDate
		,e.Ethnic
		,e.[Native]
		,e.Religion
		,ISNULL(ctry.Nationality, ctry.CountryName) AS Nationality
		,e.PassportNo
		,e.PassportExp
		,ce.PickupRemark
		,e.Skype
		,e.LetsTalk
		,es.CanOT
		,es.SpecialOT
		,es.WorkingDays
		,es.WorkingHours
		,es.OffDaysbyWeek
		,es.AnnualLeaveBalance
		,es.KeepInViewBalance
		,ce.IsSpecialUser 'IsTopManager'
		,es.IsLocal
	FROM #tmpEmployee AS tpl WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = tpl.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		LEFT JOIN dbo.SubCompany AS sc WITH (NOLOCK) ON sc.SubCompanyId = ce.SubCompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId
		INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON g.DepartmentId = dep.DepartmentId
		INNER JOIN dbo.Unit AS unit WITH (NOLOCK) ON dep.UnitId = unit.UnitId
		LEFT JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON tpl.EmpId = es.EmpId
		LEFT JOIN dbo.[Lookup] AS l WITH (NOLOCK) ON l.Code = 'JT'
		LEFT JOIN dbo.[LookupData] AS jt WITH (NOLOCK) ON l.Id = jt.LookupId AND ce.JobTitleId = jt.Id
		LEFT JOIN dbo.[Country] AS ctry WITH (NOLOCK) ON ctry.CountryCode = es.CountryCode
		LEFT JOIN dbo.[JobLevel] AS jl WITH (NOLOCK) ON jl.JobLevelId = ce.JobLevelId AND jl.IsDeleted = 0
		LEFT JOIN dbo.ManagementLevel ml WITH (NOLOCK) ON ce.ManagementLevelId = ml.ManagementLevelId
		OUTER APPLY (
			SELECT TOP 1 TransferOutDate
			FROM dbo.EmployeeTransfer WITH (NOLOCK)
			WHERE FromEmpId = ce.EmpId
			ORDER BY TransferId DESC
		) AS etf
		OUTER APPLY (
			SELECT TOP 1 TransferInDate
			FROM dbo.EmployeeTransfer WITH (NOLOCK)
			WHERE ToEmpId = ce.EmpId
			ORDER BY TransferId DESC
		) AS ett
	ORDER BY ce.EmpId

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
		INNER JOIN dbo.CompanyEmployee AS empsu WITH (NOLOCK) ON su.OwnerId = empsu.EmpId
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

