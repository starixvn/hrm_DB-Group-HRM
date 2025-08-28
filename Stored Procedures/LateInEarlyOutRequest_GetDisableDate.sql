/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_GetDisableDate] @empId INT
	,@fromDate DATE
	,@toDate DATE
	,@requestTypeId TINYINT = 3
	,@requestId BIGINT = NULL
	,@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-09-24
Task: get disable date for request
DB: HRM_SMS
Original:

Revisions:
        20250813@Jay: change db structure [Redmine: #235678]
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
		,tmpca.IsLeaveOffday
		,tmpca.IsLeaveDay
		,tmpca.LeaveDay
	INTO #tblEmployeeCalendar
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON ce.EmpId = tmpca.EmpId
		AND tmpca.WorkDate BETWEEN @fromDate
			AND @toDate
	WHERE ce.EmpId = @EmpId

	SELECT WorkDate
	FROM #tblEmployeeCalendar
	WHERE ShiftId IS NULL
		OR (
			IsLeaveDay = 1
			AND LeaveDay = 1
			)
		OR IsLeaveOffday = 1
		OR (
			IsOffDay = 1
			AND ShiftId IS NULL
			)
		OR (
			IsHoliday = 1
			AND ShiftId IS NULL
			)
		OR EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
				INNER JOIN dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK) ON r.RequestId = lieo.RequestId
				AND lieo.EmpId = @EmpId
				AND WorkDate = lieo.OnDate
				AND r.RequestType = @requestTypeId
				AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
			WHERE @RequestId IS NULL
				OR r.RequestId <> @requestId
			)

	DROP TABLE #tblEmployeeCalendar
END




