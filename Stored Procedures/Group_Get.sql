/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Get]
(
    @CompanyId INT
    ,@TeamId INT = NULL
	,@keyWord varchar(20) = null
	,@isDeleted BIT = NULL
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
		,LocalYearsOfServiceForExtraLeave
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave
		,tbl.NoOfMembers
		,tbl.TotalLocal
		,tbl.TotalExpat
		,g.PICEmpId
		,cpic.[Name] AS PICCompanyName
		,cpic.[CompanyId] AS PICCompanyId
		,ld.NickName as PICNickName
		,dept.DepartmentId
        ,dept.Code
        ,dept.[Name]
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.Employee AS ld WITH (NOLOCK) ON ld.EmpId = g.PICEmpId
		LEFT JOIN dbo.CompanyEmployee cepic WITH (NOLOCK) ON cepic.EmpId = g.PICEmpId
		LEFT JOIN dbo.Company cpic WITH (NOLOCK) ON cpic.CompanyId = cepic.CompanyId
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