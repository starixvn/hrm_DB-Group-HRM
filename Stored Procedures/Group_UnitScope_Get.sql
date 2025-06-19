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