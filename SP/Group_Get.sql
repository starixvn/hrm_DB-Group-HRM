/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Get] @TeamId INT = NULL
	,@keyWord varchar(20) = null
	,@isDeleted BIT = NULL
	,@CompanyId INT
AS
/*
Created: Tom.Vo@2013-10-21
Task: get group
DB: HRMS
Original:

Revisions:
	20250310@Mira: filter by CompanyId [Redmine: #217976]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tblGroup TABLE (
		GroupId INT
		,NoOfMembers INT
		,TotalLocal INT
		,TotalExpat INT
		)

	INSERT INTO @tblGroup (
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
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,tbl.NoOfMembers
		,tbl.TotalLocal
		,tbl.TotalExpat
		,dept.Code as DepartmentCode
		,sec.SectionId
		,sec.Code
		,sec.[Name]
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Section AS sec WITH (NOLOCK) ON g.SectionId = sec.SectionId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON sec.DepartmentId = dept.DepartmentId
		LEFT JOIN @tblGroup AS tbl ON g.GroupId = tbl.GroupId
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
			 OR LOWER(g.name) like LOWER('%' + @keyWord + '%') 
			 OR LOWER(g.Code) like LOWER('%' + @keyWord + '%') 
			)
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
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
END