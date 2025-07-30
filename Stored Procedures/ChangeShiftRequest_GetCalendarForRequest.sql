/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetCalendarForRequest] @empId INT
	,@typeId TINYINT
	,@fromDate DATE
	,@toDate DATE
	,@requestId BIGINT = NULL
	,@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-09-19
Task: get calendar for request
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ChangeShift TINYINT = 1
		,@MoveOffDay TINYINT = 2

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
		,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @empId

	SELECT tmpca.WorkDate
		,tmpca.ShiftId
		,tmpca.IsOvertime
		,tmpca.RequestId
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
			(
				@requestId IS NULL
				AND tmpca.ChangeShiftTypeId IS NULL
				)
			OR (
				@requestId IS NOT NULL
				AND (
					tmpca.RequestId = @requestId
					OR tmpca.RequestId IS NULL
					)
				)
			)

	IF @TypeId = @ChangeShift
	BEGIN
		SELECT WorkDate
			,IsOffDay
			,tbl.ShiftId
			,[shift].[Name]
		FROM #tblEmployeeCalendar AS tbl WITH (NOLOCK)
			LEFT JOIN dbo.[Shift] AS [shift] WITH (NOLOCK) ON tbl.ShiftId = [shift].ShiftId
		WHERE IsKeepInView = 0
			AND IsOvertime = 0
			AND (
				IsHoliday = 0
				OR (
					IsHoliday = 1
					AND tbl.ShiftId IS NOT NULL
					)
				)
			AND IsLeaveOffday = 0
			AND (
				IsLeaveDay = 0
				OR LeaveDay = 0.5
				)
	END
	ELSE
	BEGIN
		UPDATE tbl
		SET tbl.IsOffDay = 1
		FROM #tblEmployeeCalendar AS tbl WITH (NOLOCK)
			INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON tbl.RequestId = cs.RequestId
			AND cs.TypeId = @MoveOffDay
			INNER JOIN dbo.ChangeShiftRequestDetail AS dt WITH (NOLOCK) ON cs.RequestId = dt.RequestId
			AND tbl.WorkDate = dt.OnDate
		WHERE cs.RequestId = @requestId

		SELECT WorkDate
			,IsOffDay
			,tbl.ShiftId
			,[shift].[Name]
		FROM #tblEmployeeCalendar AS tbl WITH (NOLOCK)
			LEFT JOIN dbo.[Shift] AS [shift] WITH (NOLOCK) ON tbl.ShiftId = [shift].ShiftId
		WHERE ISNULL(tbl.ShiftId, -1) = -1
			AND IsKeepInView = 0
			AND IsLeaveDay = 0
			AND IsHoliday = 0
			AND IsOvertime = 0
			AND IsLeaveOffday = 0
			AND IsOffDay = 1
	END

	DROP TABLE #tblEmployeeCalendar
END