/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_EmployeeCalendarByWeekly] @empId INT = NULL
	,@fromtime DATE
	,@totime DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@JobTitleId VARCHAR(MAX) = ''
	,@isLocal BIT = NULL
	,@companyId INT
AS
/*
Created: Tom.Vo@2013-11-15
Task: view employee calendar by weekly
DB: HRM_SMS
Original:

Revisions:
	- 20200714@Merlin.Le: Get section and department code
	- 20250408@Hank: remove section [Redmine: #222886]
	20250813@Jay: change db structure [Redmine: #235678]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EmployeeIds VARCHAR(MAX)
	DECLARE @tblGroupIds TABLE (GroupId INT)
	DECLARE @tblJobTitleIds TABLE (JobTitleId INT)
	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	IF ISNULL(@TeamIds, '') <> ''
		INSERT INTO @tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	
	IF ISNULL(@JobTitleId, '') <> ''
		INSERT INTO @tblJobTitleIds (JobTitleId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@JobTitleId, ',')
	ELSE
	BEGIN
		INSERT INTO @tblJobTitleIds (JobTitleId)
		SELECT DISTINCT lk.Id
		FROM dbo.LookupData AS lk WITH (NOLOCK)
		WHERE lk.LookupId = 1
	END

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		AND (
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
	WHERE ce.[Enabled] = 1
		AND ce.isDeleted = 0
		AND ce.CompanyId = @companyId
		AND (
			@empId IS NULL
			OR ce.EmpId = @empId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tbl
			WHERE ce.GroupId = tbl.GroupId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblJobTitleIds AS tbl
			WHERE ce.JobTitleId = tbl.JobTitleId
			)

	SELECT @EmployeeIds = COALESCE(@EmployeeIds + ',', '') + CAST(EmployeeId AS VARCHAR(10))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @companyId
		,@fromDate = @fromtime
		,@toDate = @totime
		,@empIds = @EmployeeIds
		,@isEnable = 1
		,@isDelete = 0

	SELECT ce.EmpId AS EmployeeId
		,ce.Code
		,ce.NickName
		,e.FullName
		,gr.[Name] AS Team
		,dep.Code AS DepartmentCode
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.Employee e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON ce.EmpId = tblemp.EmployeeId
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON ce.EmpId = esum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON gr.DepartmentId = dep.DepartmentId
	ORDER BY gr.[Name]
		,ce.Code

	SELECT ce.EmpId AS EmployeeId
		,ce.NickName
		,empca.WorkDate
		,empca.IsOvertime
		,empca.IsLeaveOffDay
		,empca.ChangeShiftTypeId
		,empca.MoveOffFromDate
		,empca.MoveOffToDate
		,empca.IsHoliday
		,empca.IsOffDay
		,empca.IsLeaveDay
		,empca.IsKeepInView
		,empca.LeaveDay
		,(CASE 
			WHEN offrep.EmployeeId IS NOT NULL THEN 1
			ELSE 0 END
			) AS IsOffDayReplacement
		,shift.ShiftId
		,shift.Code
		,shift.[Name]
		,shift.BeginCheckInTime AS CheckIn
		,shift.BeginCheckOutTime AS CheckOut
		,shift.IsInAfterDay
		,shift.IsOutAfterDay
		,lv1.LeaveTypeId
		,lv1.Code
		,lv1.[Name]
		,empca.FromTime
		,empca.ToTime
		,lv2.LeaveTypeId AS LeaveTypeId2
		,lv2.Code
		,lv2.[Name]
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON ce.EmpId = tblemp.EmployeeId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca ON ce.EmpId = empca.EmpId
		AND empca.WorkDate BETWEEN @fromTime
			AND @toTime
		LEFT JOIN dbo.Shift AS shift WITH (NOLOCK) ON shift.ShiftId = empca.ShiftId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId AND lv1.CompanyId = @companyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId AND lv2.CompanyId = @companyId
		LEFT JOIN dbo.ScheduleArrangementOffDayReplacement AS offrep WITH (NOLOCK) ON ce.EmpId = offrep.EmployeeId
		AND empca.WorkDate = offrep.WorkDate
	ORDER BY ce.NickName
		,empca.WorkDate

	DROP TABLE #tblEmployeeIds
END

