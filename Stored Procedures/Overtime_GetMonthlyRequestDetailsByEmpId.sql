/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Overtime_GetMonthlyRequestDetailsByEmpId] @EmployeeId INT
	,@Month DATE
	,@FromDate DATE
	,@ToDate DATE
	,@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-07-02
Task: Get monthly overtime request details.
DB: HRM

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @EmployeeId

	SELECT TOP 1 ot.RequestId
		,@Month AS [Month]
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.CurrentStatus AS StatusId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,empsum.WorkingHours
		,empsum.SpecialOT
		,ot.VerifierId
		,verifier.NickName
		,verifier.FullName
		,ot.ApproverId
		,approver.NickName
		,approver.FullName
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		LEFT JOIN dbo.OTMonthlyRequest AS ot WITH (NOLOCK) ON ot.EmpId = emp.EmpId
		AND ot.[Month] = @Month
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON ot.VerifierId = verifier.EmpId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON ot.ApproverId = approver.EmpId
	WHERE emp.EmpId = @EmployeeId

	SELECT empca.WorkDate
		,COALESCE(sc.ShiftId, scl.ShiftId, s.ShiftId) ShiftId
		,COALESCE(sc.Code, scl.Code, s.Code) AS ShiftCode
		,CONVERT(VARCHAR(5), empatt.InFixed, 108) AS [TimeIn]
		,CONVERT(VARCHAR(5), empatt.OutFixed, 108) [TimeOut]
		,empatt.TotalWorkHours AS ActualWorkingHours
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.[Remark]
		,empca.IsHoliday
		,empca.IsOffDay
		,empca.IsKeepInView
		,holiday.TypeId AS HolidayTypeId
	FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
		LEFT JOIN dbo.Holiday AS holiday WITH (NOLOCK) ON holiday.CompanyId = @CompanyId
        AND empca.WorkDate BETWEEN holiday.FromDate
			AND holiday.ToDate
		LEFT JOIN [dbo].OTDailyRequest AS ot WITH (NOLOCK) ON empca.WorkDate = ot.OvertimeDate
		AND ot.EmpId = empca.EmpId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
		LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON empatt.AttendanceDate = empca.WorkDate
		AND empatt.EmpId = empca.EmpId
		LEFT JOIN dbo.[Shift] AS sc WITH (NOLOCK) ON sc.ShiftId = empatt.ShiftId
		LEFT JOIN dbo.[Shift] AS scl WITH (NOLOCK) ON scl.ShiftId = empca.ShiftId
	WHERE empca.EmpId = @employeeId
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
	ORDER BY empca.WorkDate
END