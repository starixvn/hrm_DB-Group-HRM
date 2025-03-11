/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId AND ce.CompanyId = @companyId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		AND (
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND (
			@empId IS NULL
			OR emp.EmpId = @empId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tbl
			WHERE emp.GroupId = tbl.GroupId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblJobTitleIds AS tbl
			WHERE emp.JobTitleId = tbl.JobTitleId
			)

	SELECT @EmployeeIds = COALESCE(@EmployeeIds + ',', '') + CAST(EmployeeId AS VARCHAR(10))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @companyId
		,@fromDate = @fromtime
		,@toDate = @totime
		,@empIds = @EmployeeIds
		,@isEnable = 1
		,@isDelete = 0

	SELECT emp.EmpId AS EmployeeId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,gr.[Name] AS Team
		,sec.Code AS SectionCode
		,dep.Code AS DepartmentCode
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmployeeId
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON emp.EmpId = esum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.[Section] AS sec WITH (NOLOCK) ON gr.SectionId = sec.SectionId
		INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON sec.DepartmentId = dep.DepartmentId
	ORDER BY gr.[Name]
		,emp.Code

	SELECT emp.EmpId AS EmployeeId
		,emp.NickName
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
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmployeeId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca ON emp.EmpId = empca.EmpId
		AND empca.WorkDate BETWEEN @fromTime
			AND @toTime
		LEFT JOIN dbo.Shift AS shift WITH (NOLOCK) ON shift.ShiftId = empca.ShiftId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId
		LEFT JOIN dbo.ScheduleArrangementOffDayReplacement AS offrep WITH (NOLOCK) ON emp.EmpId = offrep.EmployeeId
		AND empca.WorkDate = offrep.WorkDate
	ORDER BY emp.NickName
		,empca.WorkDate

	DROP TABLE #tblEmployeeIds
END



