/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[Group_UnitScope_Get]
	@TeamIds varchar(MAX) = '',
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
	20250701@Tim: Show Nexcel, Lumiplus, NexVision [Redmine: #225531]
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @GroupsList TABLE (GroupId INT)

	INSERT INTO @GroupsList (GroupId)
	SELECT value
	FROM STRING_SPLIT(@teamIds, ',')

	CREATE TABLE #tmpGroup (
		GroupId INT PRIMARY KEY
		,NoOfMembers INT
		)

	CREATE TABLE #tmpGroupEmployees (
		GroupId INT,
		EmpId INT,
		PRIMARY KEY (GroupId, EmpId)
	)

	INSERT INTO #tmpGroupEmployees (GroupId, EmpId)
	SELECT DISTINCT emp.GroupId, emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
	WHERE emp.GroupId IS NOT NULL
		AND emp.isDeleted = 0 
		AND emp.[Enabled] = 1
		AND esum.IsLocal IS NOT NULL

	INSERT INTO #tmpGroupEmployees (GroupId, EmpId)
	SELECT DISTINCT ce.GroupId, ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
	WHERE ce.GroupId IS NOT NULL
		AND ce.IsDeleted = 0 
		AND ce.[Enabled] = 1
		AND ce.IsSpecialUser = 0

	INSERT INTO #tmpGroup (
		GroupId
		,NoOfMembers
		)
	SELECT g.GroupId
		,ISNULL(COUNT(DISTINCT tge.EmpId), 0) AS NoOfMembers
	FROM dbo.[Group] AS g WITH (NOLOCK)
		LEFT JOIN #tmpGroupEmployees AS tge ON g.GroupId = tge.GroupId
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
		LEFT JOIN dbo.CompanyEmployee AS gpic WITH (NOLOCK) ON gpic.EmpId = e.EmpId AND ISNULL(gpic.isDeleted, 0) = 0 AND ISNULL(gpic.[Enabled], 1) = 1 AND ISNULL(gpic.IsSpecialUser, 0) = 0
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = d.UnitId
		LEFT JOIN dbo.Employee AS ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN dbo.CompanyEmployee AS cepic WITH (NOLOCK) ON cepic.EmpId = g.PICEmpId AND ISNULL(cepic.isDeleted, 0) = 0 AND ISNULL(cepic.[Enabled], 1) = 1 AND ISNULL(cepic.IsSpecialUser, 0) = 0
		LEFT JOIN dbo.Company AS cpic WITH (NOLOCK) ON cepic.CompanyId = cpic.CompanyId
		LEFT JOIN #tmpGroup AS tbl ON g.GroupId = tbl.GroupId
		LEFT JOIN dbo.Company AS c ON g.CompanyId = c.CompanyId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND g.isDeleted != 1
		AND (ISNULL( @teamIds, '') = ''  OR g.GroupId IN (SELECT GroupId FROM @GroupsList))
	ORDER BY d.Code

    DROP TABLE #tmpGroup
    DROP TABLE #tmpGroupEmployees
END