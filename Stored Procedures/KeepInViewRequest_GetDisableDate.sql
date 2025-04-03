/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_GetDisableDate] @empId INT
	,@fromDate DATE
	,@toDate DATE
	,@typeId TINYINT = 1
	,@requestId BIGINT = NULL
	,@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-10-16
Task: get disable date for request
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @empId

	SELECT tmpca.WorkDate
		,tmpca.ShiftId
		,tmpca.IsHoliday
		,tmpca.IsOffDay
		,tmpca.IsOvertime
		,tmpca.IsLeaveOffDay
		,tmpca.IsLeaveDay
		,tmpca.LeaveDay
		,tmpca.ChangeShiftTypeId
	INTO #tblEmployeeCalendar
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON emp.EmpId = tmpca.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		AND tmpca.WorkDate BETWEEN @fromDate
			AND @toDate
	WHERE emp.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId

	SELECT WorkDate
	FROM #tblEmployeeCalendar
	WHERE IsOvertime = 1
		OR (
			IsLeaveDay = 1
			AND LeaveDay = 1
			)
		OR IsLeaveOffDay = 1
		OR ChangeShiftTypeId IS NOT NULL
		OR EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
				AND kiv.EmpId = @EmpId
				AND WorkDate = kiv.OnDate
				AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
			WHERE @RequestId IS NULL
				OR r.RequestId <> @requestId
			)
		OR (
			@typeId = 1 -- kiv by day
			AND IsOffDay = 0
			AND IsHoliday = 0
			)

	DROP TABLE #tblEmployeeCalendar
END

