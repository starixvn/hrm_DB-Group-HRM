/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetDisableDate] @empId INT
	,@fromDate DATE
	,@toDate DATE
	,@requestId BIGINT = NULL
	,@LeaveTypeId INT,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-10-15
Task: get disable date for request
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE
		-- request status
		@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7

	IF @RequestId IS NOT NULL
	BEGIN
		DECLARE @OldLeaveTypeId INT
			,@OldFromDate DATE
			,@OldToDate DATE

		SELECT @OldLeaveTypeId = LeaveType
			,@OldFromDate = FromDate
			,@OldToDate = ToDate
		FROM dbo.LeaveRequest WITH (NOLOCK)
		WHERE RequestId = @RequestId

		IF @LeaveTypeId != @OldLeaveTypeId
		BEGIN
			EXEC dbo.LeaveRequest_EmployeeCalendar_ResetOffDay @empId = @EmpId
				,@LeaveTypeId = @OldLeaveTypeId
				,@fromDate = @OldFromDate
				,@toDate = @OldToDate
		END
	END

	EXEC dbo.tmpEmployeeCalendar_Insert 
		@CompanyId
		,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @empId

	SELECT tmpca.RequestId
		,tmpca.WorkDate
		,tmpca.ShiftId
		,tmpca.IsHoliday
		,tmpca.IsOffDay
		,tmpca.IsOvertime
		,tmpca.IsLeaveOffday
		,tmpca.IsLeaveDay
		,tmpca.LeaveDay
	INTO #tblEmployeeCalendar
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON emp.EmpId = tmpca.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
		AND tmpca.WorkDate BETWEEN @fromDate
			AND @toDate
	WHERE emp.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId

	SELECT WorkDate
	FROM #tblEmployeeCalendar AS empca WITH (NOLOCK)
	WHERE empca.IsOffDay = 1
		OR empca.IsHoliday = 1
		OR empca.IsOvertime = 1
		OR (
			(
				@RequestId IS NULL
				OR empca.RequestId <> @RequestId
				)
			AND (
				(
					empca.IsLeaveDay = 1
					AND empca.LeaveDay = 1
					)
				OR empca.IsLeaveOffday = 1
				)
			)

	DROP TABLE #tblEmployeeCalendar
END



