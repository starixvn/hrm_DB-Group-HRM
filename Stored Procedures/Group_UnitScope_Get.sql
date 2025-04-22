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
		,g.MailGroup
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,tbl.NoOfMembers
		,tbl.TotalLocal
		,tbl.TotalExpat
		,g.PICEmpId
		,e.NickName as TeamPIC
		,d.DepartmentId
        ,d.Code AS DepartmentCode
        ,d.[Name] AS DepartmentName
		, d.PICEmpId AS DepartmentPIC
		,u.Code AS UnitCode
		,g.AccountableArea
		,g.CompanyId
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS d WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = g.PICEmpId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = d.UnitId
		LEFT JOIN #tmpGroup AS tbl ON g.GroupId = tbl.GroupId
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

	SELECT mng.GroupId AS TeamId
		,mng.RoleId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
	FROM dbo.GroupManager AS mng WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON mng.GroupId = g.GroupId
		AND  g.isDeleted != 1
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON mng.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) on c.EmpId = emp.EmpId
    WHERE emp.isDeleted = 0
		AND emp.[Enabled] = 1
		AND (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)

    DROP TABLE #tmpGroup
END