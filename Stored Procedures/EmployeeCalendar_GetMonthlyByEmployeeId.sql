/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
        20250813@Jay: change db structure [Redmine: #235678]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
		,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	SELECT ce.EmpId
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
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON ce.EmpId = empca.EmpId
			AND empca.WorkDate BETWEEN @fromDate
				AND @toDate
		LEFT JOIN dbo.Shift AS shift WITH (NOLOCK) ON shift.ShiftId = empca.ShiftId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId and lv1.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId and lv2.CompanyId = @CompanyId
	WHERE ce.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId
	ORDER BY empca.WorkDate
END