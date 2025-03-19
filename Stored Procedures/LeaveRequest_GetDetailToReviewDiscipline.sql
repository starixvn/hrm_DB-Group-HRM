/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetDetailToReviewDiscipline] @RequestId BIGINT
AS
/*
Created: 20190426@Quinn.Vo
Task: get leave request detail
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @LeaveType INT
		,@GeneralLeaveType INT = 0
		,@AnnualLeaveType INT = 2
		,@KIVLeaveType INT = 10
		,@UnpaidLeaveType INT = 25
		,@LeaveWorkType TINYINT = 2
		,@TotalDays DECIMAL(5, 1)
        ,@CompanyId SMALLINT

	SELECT @LeaveType = r.LeaveType
		,@TotalDays = r.TotalDays
        ,@CompanyId = ce.CompanyId
	FROM dbo.LeaveRequest AS r WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON r.EmpId = ce.EmpId
	WHERE r.RequestId = @RequestId

	CREATE TABLE #tblLeaveDetail (
		WorkDate DATETIME
		,LeaveTypeId INT
		,LeaveTypeName NVARCHAR(200)
		,IsHalfDay BIT
		,FromTime DATETIME
		,ToTime DATETIME
		,IsFromAfterday BIT
		,IsToAfterday BIT
		)

	CREATE NONCLUSTERED INDEX IX_tblLeaveDetail_WorkDate_LeaveTypeId ON #tblLeaveDetail (
		WorkDate
		,LeaveTypeId
		);

	IF @LeaveType = @GeneralLeaveType
		OR @TotalDays = 0.5
	BEGIN
		INSERT INTO #tblLeaveDetail (
			WorkDate
			,LeaveTypeId
			,LeaveTypeName
			,IsHalfDay
			,FromTime
			,ToTime
			,IsFromAfterday
			,IsToAfterday
			)
		SELECT ldt.OnDate
			,lt.LeaveTypeId
			,lt.[Name]
			,ldt.IsHalfDay
			,ldt.FromTime
			,ldt.ToTime
			,(CASE 
				WHEN CAST(ldt.FromTime AS DATE) > CAST(ldt.OnDate AS DATE) THEN 1
				ELSE 0 END
				) AS IsFromAfterday
			,(CASE 
				WHEN CAST(ldt.ToTime AS DATE) > CAST(ldt.OnDate AS DATE) THEN 1
				ELSE 0 END
				) AS IsToAfterday
		FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			LEFT JOIN dbo.LeaveType AS lt WITH (NOLOCK) ON lt.LeaveTypeId = ldt.LeaveType
            AND lt.CompanyId = @CompanyId
		WHERE ldt.RequestId = @RequestId
			AND ldt.WorkType = @LeaveWorkType
	END
	ELSE IF @LeaveType = @AnnualLeaveType
		OR @LeaveType = @KIVLeaveType
		OR @LeaveType = @UnpaidLeaveType
	BEGIN
		INSERT INTO #tblLeaveDetail (
			WorkDate
			,LeaveTypeId
			,LeaveTypeName
			,IsHalfDay
			)
		SELECT ca.WorkDate
			,lt.LeaveTypeId
			,lt.[Name]
			,0 AS IsHalfDay
		FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
			INNER JOIN dbo.EmployeeCalendar AS ca WITH (NOLOCK) ON lr.EmpId = ca.EmpId
			AND ca.WorkDate BETWEEN lr.FromDate
				AND lr.ToDate
			LEFT JOIN dbo.LeaveType AS lt WITH (NOLOCK) ON lt.LeaveTypeId = lr.LeaveType
            AND lt.CompanyId = @CompanyId
		WHERE lr.RequestId = @RequestId
	END

	SELECT WorkDate
		,IsOffOrHoliday
		,ScheduleStatus
		,IsUnpaidLeaveAbsent
		,IsUnpaidLeave
		,IsAbsent
		,IsUnplannedLeave
		,IsWeekendLeave
		,IsSevenDaysLeave
	FROM dbo.fnc_GetDisciplineDetailByLeaveRequestId(@RequestId)
	ORDER BY WorkDate

	SELECT WorkDate
		,LeaveTypeId
		,LeaveTypeName
		,IsHalfDay
		,FromTime
		,ToTime
		,IsFromAfterday
		,IsToAfterday
	FROM #tblLeaveDetail WITH (NOLOCK)

	DROP TABLE #tblLeaveDetail
END