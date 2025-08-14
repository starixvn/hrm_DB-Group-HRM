/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Overtime_GetMonthlyRequestDetailsById] 
	@RequestId BIGINT,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-07-08
Task: Get monthly overtime request by id.
DB: HRM
Original:

Revisions:
        20250813@Jay: change db structure [Redmine: #235678]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Month DATE
		,@fromDate DATE
		,@toDate DATE
		,@EmployeeId INT
		,@NewRuleApplyFromMonth DATE = '2020/05/01'
		,@empCompanyId INT

	SELECT @Month = [Month]
		,@EmployeeId = o.EmpId
		,@empCompanyId = c.CompanyId
	FROM dbo.OTMonthlyRequest o WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) ON c.EmpId = o.EmpId
	WHERE RequestId = @RequestId

	SELECT @toDate = @Month
		,@fromDate = DATEADD(month, - 1, @Month)

	SELECT @fromDate = CONVERT(VARCHAR(5), YEAR(@fromDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@fromDate)) + '/10'
		,@toDate = CONVERT(VARCHAR(5), YEAR(@toDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@toDate)) + + '/09'

	IF @Month = @NewRuleApplyFromMonth
	BEGIN
		SET @toDate = CONVERT(VARCHAR(5), YEAR(@toDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@toDate)) + '/20'
	END

	IF @Month > @NewRuleApplyFromMonth
	BEGIN
		SET @fromDate = CONVERT(VARCHAR(5), YEAR(@fromDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@fromDate)) + '/21'
		SET @toDate = CONVERT(VARCHAR(5), YEAR(@toDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@toDate)) + '/20'
	END

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @empCompanyId
		,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @EmployeeId

	SELECT ot.RequestId
		,ot.[Month]
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.CurrentStatus AS StatusId
		,ce.EmpId
		,CASE 
			WHEN ce.CompanyId <> @CompanyId THEN ce.NickName + ' (' + ISNULL(c_emp.Name, '') + ')'
			ELSE ce.NickName 
		END AS NickName
		,emp.FullName
		,empsum.WorkingHours
		,empsum.SpecialOT
		,ot.VerifierId
		,CASE 
			WHEN vece.CompanyId <> @CompanyId THEN vece.NickName + ' (' + ISNULL(c_verifier.Name, '') + ')'
			ELSE vece.NickName 
		END AS NickName
		,verifier.FullName
		,ot.ApproverId
		,CASE 
			WHEN apce.CompanyId <> @CompanyId THEN apce.NickName + ' (' + ISNULL(c_approver.Name, '') + ')'
			ELSE apce.NickName 
		END AS NickName
		,approver.FullName
	FROM dbo.OTMonthlyRequest AS ot WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ot.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
		LEFT JOIN dbo.Company AS c_emp WITH (NOLOCK) ON c_emp.CompanyId = ce.CompanyId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ot.VerifierId
		INNER JOIN dbo.Employee AS verifier WITH (NOLOCK) ON vece.UserId = verifier.UserId
		LEFT JOIN dbo.Company AS c_verifier WITH (NOLOCK) ON c_verifier.CompanyId = vece.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ot.ApproverId
		INNER JOIN dbo.Employee AS approver WITH (NOLOCK) ON apce.UserId = approver.UserId
		LEFT JOIN dbo.Company AS c_approver WITH (NOLOCK) ON c_approver.CompanyId = apce.CompanyId
	WHERE ot.RequestId = @RequestId

	SELECT empca.WorkDate
		,COALESCE(sc.ShiftId, scl.ShiftId, s.ShiftId) AS ShiftId
		,COALESCE(sc.Code, scl.Code, s.Code) AS ShiftCode
		,COALESCE(sc.TotalHours, scl.TotalHours, s.TotalHours) AS TotalShiftHours
		,CONVERT(VARCHAR(5), empatt.InFixed, 108) AS [TimeIn]
		,CONVERT(VARCHAR(5), empatt.OutFixed, 108) AS [TimeOut]
		,empatt.TotalWorkHours AS ActualWorkingHours
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.[Remark]
		,empca.IsHoliday
		,empca.IsOffDay
		,empca.IsKeepInView
	FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
		LEFT JOIN dbo.OTDailyRequest AS ot WITH (NOLOCK) ON empca.WorkDate = ot.OvertimeDate
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
