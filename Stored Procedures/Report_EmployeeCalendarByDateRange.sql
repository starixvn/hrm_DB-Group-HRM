/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_EmployeeCalendarByDateRange]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
)
AS
/*
    Created: 20250310@Tim
    Task: get employee calendar by date range.
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
        20250813@Jay: change db structure [Redmine: #235678]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @employeeIds VARCHAR(MAX)
        -- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
	DECLARE @tblGroupIds TABLE (GroupId INT)
	DECLARE @tblEmployeeIds TABLE (EmpId INT)

	IF ISNULL(@TeamIds, '') <> ''
    BEGIN
		INSERT INTO @tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
        WHERE ISNUMERIC(value) = 1
    END

	INSERT INTO @tblEmployeeIds (EmpId)
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN (
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)
		) AS [member] ON ce.EmpId = [member].EmpId
		INNER JOIN Employee e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId AND ce.IsSpecialUser = 0
	WHERE (
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
		AND EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tblgr
			WHERE tblgr.GroupId = ce.GroupId
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)

	SELECT @employeeIds = COALESCE(@employeeIds + ',', '') + CAST(EmpId AS VARCHAR(20))
	FROM @tblEmployeeIds

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
        ,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @employeeIds

	SELECT ce.EmpId AS EmployeeId
		,ce.Code
		,ce.NickName
		,e.FullName
        ,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dept.Code as DepartmentCode
		,dept.[Name] as DepartmentName
		,empca.WorkDate
		,empca.IsOffDay
		,empca.IsHoliday
		,empca.IsLeaveOffDay
		,empca.IsLeaveDay
		,empca.LeaveDay
		,empca.ShiftId
		,[shift].Code
		,[shift].[Name]
		,empca.LeaveTypeId
		,lv1.Code
		,lv1.[Name]
		,lv2.LeaveTypeId AS LeaveTypeId2
		,lv2.Code
		,lv2.[Name]
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN @tblEmployeeIds AS member ON ce.EmpId = member.EmpId
		INNER JOIN Employee e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON ce.EmpId = empca.EmpId
		LEFT JOIN dbo.[Shift] AS [shift] WITH (NOLOCK) ON [shift].ShiftId = empca.ShiftId
        AND [shift].CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId
        AND lv1.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId
        AND lv2.CompanyId = @CompanyId
    WHERE empca.WorkDate BETWEEN @fromDate
		AND @toDate
	ORDER BY ce.NickName
		,empca.WorkDate
END
