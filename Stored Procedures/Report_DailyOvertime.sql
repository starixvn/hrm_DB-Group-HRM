/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_DailyOvertime]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@fromDate DATE
	,@toDate DATE
	,@TeamIds VARCHAR(MAX) = NULL
	,@isLocal BIT = NULL
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
)
AS
/*
    Created: 20250307@Tim
    Task: Get daily overtime details report 
    DB: bodb_HRM
    Original:

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
        20250813@Jay: change db structure [Redmine: #235678]
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
	FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)

	SELECT ce.EmpId
		,ce.NickName
		,e.FullName
		,ce.Code
		,gr.GroupId
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
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
		,dept.Code AS DepartmentCode
	    ,dept.[Name] AS DepartmentName
	FROM dbo.OTDailyRequest AS ot WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ot.EmpId
		INNER JOIN Employee e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN #tmpMembers AS member WITH (NOLOCK) ON ce.EmpId = member.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = ce.EmpId
			AND ce.IsSpecialUser = 0
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON gr.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON ce.EmpId = empca.EmpId
		AND ot.OvertimeDate = empca.WorkDate
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
        AND s.CompanyId = @CompanyId
	WHERE ot.OvertimeDate BETWEEN @fromDate
			AND @toDate
		AND (
			@EmployeeStatusId IS NULL
			OR (
				@EmployeeStatusId = @Enable
				AND ce.[Enabled] = 1
				AND ce.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Disabled
				AND ce.[Enabled] = 0
				AND ce.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Deleted
				AND ce.isDeleted = 1
				)
			)
		AND (
			ce.NickName LIKE '%' + ISNULL(@Employee, '') + '%'
			OR e.FullName LIKE '%' + ISNULL(@Employee, '') + '%'
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
				WHERE ce.GroupId = tbl.GroupId
				)
			)
	ORDER BY ot.OvertimeDate
		,ce.NickName

	DROP TABLE #tmpGroupIds
	DROP TABLE #tmpMembers
END
