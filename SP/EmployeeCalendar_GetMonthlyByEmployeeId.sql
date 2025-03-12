/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeCalendar_GetMonthlyByEmployeeId] @fromDate DATE
	,@toDate DATE
	,@empId INT
	,@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-10-31
Task: employee calendar by month
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
		,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	SELECT emp.EmpId
		,empca.WorkDate
		,empca.IsOffDay
		,empca.IsHoliday
		,empca.IsLeaveOffDay
		,empca.IsLeaveDay
		,empca.LeaveDay
		,empca.ShiftId
		,shift.Code
		,shift.[Name]
		,empca.LeaveTypeId
		,lv1.Code
		,lv1.[Name]
		,lv2.LeaveTypeId AS LeaveTypeId2
		,lv2.Code
		,lv2.[Name]
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
		LEFT JOIN dbo.Shift AS shift WITH (NOLOCK) ON shift.ShiftId = empca.ShiftId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId
	WHERE emp.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId
	ORDER BY empca.WorkDate
END

