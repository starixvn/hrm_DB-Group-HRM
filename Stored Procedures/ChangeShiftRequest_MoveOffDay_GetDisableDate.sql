/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_MoveOffDay_GetDisableDate] @empId INT
	,@fromDate DATE
	,@toDate DATE
	,@requestId BIGINT = NULL
	,@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-09-24
Task: get disable date for request
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
		,@empIds = @empId

	SELECT tmpca.WorkDate
		,tmpca.ShiftId
		,tmpca.IsOvertime
		,tmpca.ChangeShiftTypeId
		,tmpca.IsKeepInView
		,tmpca.IsHoliday
		,tmpca.IsOffDay
		,tmpca.IsLeaveOffday
		,tmpca.IsLeaveDay
		,tmpca.LeaveDay
	INTO #tblEmployeeCalendar
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON emp.EmpId = tmpca.EmpId
		AND tmpca.WorkDate BETWEEN @fromDate
			AND @toDate
	WHERE emp.EmpId = @EmpId
		AND (
			@requestId IS NULL
			OR ISNULL(tmpca.RequestId, 0) <> @requestId
			)

	SELECT WorkDate
	FROM #tblEmployeeCalendar AS tbl
	WHERE ChangeShiftTypeId IS NOT NULL
		OR IsKeepInView = 1
		OR IsLeaveDay = 1
		OR IsHoliday = 1
		OR IsOvertime = 1
		OR IsLeaveOffday = 1
		OR IsOffDay = 1

	DROP TABLE #tblEmployeeCalendar
END



