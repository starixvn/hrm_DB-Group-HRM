/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_DailyOvertime] @ActorId INT
	,@fromDate DATE
	,@toDate DATE
	,@TeamIds VARCHAR(MAX) = NULL
	,@isLocal BIT = NULL
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
AS
/*
Created: 20250307@Tim
Task: Get daily overtime details report 
DB: HRM_SMS
Original:

Revisions:
    20250307@Tim: initial - [Redmine: #217976]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE
		-- employee status
		@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3

	CREATE TABLE #tmpGroupIds (GroupId INT PRIMARY KEY)
	CREATE TABLE #tmpMembers (EmpId INT PRIMARY KEY)

	INSERT INTO #tmpGroupIds (GroupId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TeamIds, ',')
	WHERE ISNUMERIC(value) = 1

	INSERT INTO #tmpMembers (EmpId)
	SELECT DISTINCT EmpId
	FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1)

	SELECT emp.EmpId
		,emp.NickName
		,emp.FullName
		,emp.Code
		,gr.GroupId
		,gr.[Name] AS Team
		,ot.OvertimeDate AS WorkDate
		,s.ShiftId
		,s.Code AS ShiftCode
		,ot.TimeIn
		,ot.[TimeOut]
		,ot.TotalHours AS ActualWorkingHours
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.Remark
		,empca.IsHoliday
		,empca.IsOffDay
		,ot.[Status] AS StatusId
		,dept.Code as DepartmentCode
	    ,sec.Code as Section
	FROM dbo.OTDailyRequest AS ot WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = ot.EmpId
		INNER JOIN #tmpMembers AS member WITH (NOLOCK) ON emp.EmpId = member.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = emp.EmpId AND empsum.IsTopManager = 0
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.Section AS sec WITH (NOLOCK) ON gr.SectionId = sec.SectionId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON sec.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		AND ot.OvertimeDate = empca.WorkDate
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
	WHERE ot.OvertimeDate BETWEEN @fromDate
			AND @toDate
		AND (
			@EmployeeStatusId IS NULL
			OR (
				@EmployeeStatusId = @Enable
				AND emp.[Enabled] = 1
				AND emp.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Disabled
				AND emp.[Enabled] = 0
				AND emp.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Deleted
				AND emp.isDeleted = 1
				)
			)
		AND (
			emp.NickName LIKE '%' + ISNULL(@Employee, '') + '%'
			OR emp.FullName LIKE '%' + ISNULL(@Employee, '') + '%'
			)
		AND (
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		AND (
			ISNULL(@TeamIds, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tmpGroupIds AS tbl WITH (NOLOCK)
				WHERE emp.GroupId = tbl.GroupId
				)
			)
	ORDER BY ot.OvertimeDate
		,emp.NickName

	DROP TABLE #tmpGroupIds
	DROP TABLE #tmpMembers
END