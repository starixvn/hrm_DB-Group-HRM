/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_UnitScope_Get]
(
    @TeamIds varchar(MAX) = '',
    @TeamId INT = NULL
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
        20250701@Hank: show Nexcel, Lumiplus, NexVision [Redmine: #225531]
        20250815@Jay.Do: enhancement [Redmine: #236138]
		20250812@Mira: tranfer employee [Redmine: #235678]
        20250819@Tim: get PICEmpId [Redmine: #235678]
		20250904@Jay: update role [Redmine: #237201]
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @GroupsList TABLE (GroupId INT)

	INSERT INTO @GroupsList (GroupId)
	SELECT value
	FROM STRING_SPLIT(@teamIds, ',')

	CREATE TABLE #tmpGroup (GroupId INT PRIMARY KEY, NoOfMembers INT)

	CREATE TABLE #tmpGroupEmployees (GroupId INT, EmpId INT)

	INSERT INTO #tmpGroupEmployees (GroupId, EmpId)
	SELECT DISTINCT emp.GroupId, emp.EmpId
	FROM dbo.CompanyEmployee AS emp WITH (NOLOCK)
		LEFT JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
	WHERE emp.GroupId IS NOT NULL
		AND emp.isDeleted = 0 
		AND emp.[Enabled] = 1
		AND emp.IsSpecialUser = 0

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
		,et.CtrId AS TeamPICCtrId
		,e.NickName as TeamPIC
		,cpic.[CompanyId] AS TeamPICCompanyId
		,cpic.[Name] AS TeamPICCompany
		,d.DepartmentId
        ,d.Code AS DepartmentCode
        ,d.[Name] AS DepartmentName
		,d.PICEmpId AS DepartmentPICId
		,emped.CtrId AS DepartmentPICCtrId
        ,ed.EmpId AS DepartmentPICEmpId
		,ed.NickName AS DepartmentPIC
		,u.UnitId
		,u.Code AS UnitCode
        ,u.PICEmpId AS UnitPICEmpId
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
		LEFT JOIN dbo.CompanyEmployee AS e WITH (NOLOCK) ON e.EmpId = g.PICEmpId
		LEFT JOIN dbo.Employee AS et WITH (NOLOCK) ON et.UserId = e.UserId
		LEFT JOIN dbo.CompanyEmployee AS gpic WITH (NOLOCK) ON gpic.EmpId = e.EmpId AND ISNULL(gpic.isDeleted, 0) = 0 AND ISNULL(gpic.[Enabled], 1) = 1 AND ISNULL(gpic.IsSpecialUser, 0) = 0
		INNER JOIN dbo.Department AS d WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
		LEFT JOIN dbo.CompanyEmployee AS ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN dbo.Employee AS emped WITH (NOLOCK) ON emped.UserId = ed.UserId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = d.UnitId
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