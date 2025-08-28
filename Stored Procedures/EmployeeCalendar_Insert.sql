/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeCalendar_Insert]
(
    @EmpId INT = NULL
    ,@fromdate DATE
    ,@todate DATE
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: insert calendar
    DB: bodb_HRM

    Revisions:
        20250611@Tim: remove JoinedDate validation
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @MofifiedDate DATETIME = GETDATE()

	CREATE TABLE #tmpDate (
		EmpId INT
		,WorkDate DATE
		,ShiftId INT
		)

	WHILE @FromDate <= @ToDate
	BEGIN
		INSERT INTO #tmpDate (
			EmpId
			,WorkDate
			,ShiftId
			)
		SELECT ce.EmpId
			,@FromDate
			,CASE 
				WHEN DATEPART(dw, @FromDate) = 1 THEN SunShift
				WHEN DATEPART(dw, @FromDate) = 2 THEN MonShift
				WHEN DATEPART(dw, @FromDate) = 3 THEN TueShift
				WHEN DATEPART(dw, @FromDate) = 4 THEN WedShift
				WHEN DATEPART(dw, @FromDate) = 5 THEN ThuShift
				WHEN DATEPART(dw, @FromDate) = 6 THEN FriShift
				WHEN DATEPART(dw, @FromDate) = 7 THEN SatShift
				END
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
			AND empsum.IsDefaultSchedule = 1
			INNER JOIN dbo.EmployeeDefaultShift AS shift WITH (NOLOCK) ON ce.EmpId = shift.EmpId
		WHERE @EmpId IS NULL
			OR ce.EmpId = @EmpId

		INSERT INTO #tmpDate (
			EmpId
			,WorkDate
			,ShiftId
			)
		SELECT ce.EmpId
			,@FromDate
			,ShiftId
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
			AND empsum.IsDefaultSchedule = 0
			OUTER APPLY (
			SELECT TOP 1 shift.ShiftId
			FROM dbo.ScheduleArrangementDefaultShift AS shift WITH (NOLOCK)
			WHERE shift.EmployeeId = ce.EmpId
				--AND shift.ShiftId > 0
				AND shift.FromDate <= @FromDate
			ORDER BY shift.FromDate DESC
			) AS shift
		WHERE @EmpId IS NULL
			OR ce.EmpId = @EmpId

		SET @FromDate = DATEADD(DAY, 1, @FromDate)
	END

	INSERT INTO dbo.EmployeeCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsOffDay
		,IsHoliday
		,IsFixedOffDay
		,IsPublic
		,ModifiedDate
		)
	SELECT ce.EmpId
		,tblc.WorkDate
		,(CASE 
			WHEN (
					empsum.IsLocal = 1
					OR empsum.IsExpatUseHoliday = 1
					)
				AND holiday.Id IS NOT NULL THEN NULL
			ELSE tblc.ShiftId END
			) AS ShiftId
		,(CASE 
			WHEN (
					empsum.IsLocal = 1
					OR empsum.IsExpatUseHoliday = 1
					)
				AND holiday.Id IS NOT NULL THEN 0
			WHEN tblc.ShiftId IS NULL THEN 1
			ELSE 0 END
			) AS IsOffDay
		,(CASE 
			WHEN (
					empsum.IsLocal = 1
					OR empsum.IsExpatUseHoliday = 1
					)
				AND holiday.Id IS NOT NULL THEN 1
			ELSE 0 END
			) AS IsHoliday
		,0 AS IsFixedOffDay
		,1 AS IsPublic
		,@MofifiedDate
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
        INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		AND empsum.IsDefaultSchedule = 1
		INNER JOIN #tmpDate AS tblc ON ce.EmpId = tblc.EmpId
		LEFT JOIN dbo.Holiday AS holiday WITH (NOLOCK) ON ce.CompanyId = holiday.CompanyId
        AND tblc.WorkDate BETWEEN holiday.FromDate
			AND holiday.ToDate
	WHERE ce.[Enabled] = 1
		AND ISNULL(ce.IsDeleted, 0) = 0
		AND (
			@EmpId IS NULL
			OR ce.EmpId = @EmpId
			)
		AND (
			e.ResignedDate IS NULL
			OR e.ResignedDate > tblc.WorkDate
			)
		--AND emp.JoinedDate <= tblc.WorkDate
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
			WHERE empca.EmpId = ce.EmpId
				AND empca.WorkDate = tblc.WorkDate
			)

	INSERT INTO dbo.EmployeeCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsOffDay
		,IsHoliday
		,IsFixedOffDay
		,IsPublic
		,ModifiedDate
		)
	SELECT DISTINCT ce.EmpId
		,tblc.WorkDate
		,(CASE 
			WHEN (
					empsum.IsLocal = 1
					OR empsum.IsExpatUseHoliday = 1
					)
				AND holiday.Id IS NOT NULL THEN NULL
			ELSE tblc.ShiftId END
			) AS ShiftId
		,0 AS IsOffDay
		,(CASE 
			WHEN (
					empsum.IsLocal = 1
					OR empsum.IsExpatUseHoliday = 1
					)
				AND holiday.Id IS NOT NULL THEN 1
			ELSE 0 END
			) AS IsHoliday
		,0 AS IsFixedOffDay
		,1 AS IsPublic
		,@MofifiedDate
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = ce.UserId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = ce.EmpId
		AND empsum.IsDefaultSchedule = 0
		INNER JOIN #tmpDate AS tblc ON ce.EmpId = tblc.EmpId
		LEFT JOIN dbo.Holiday AS holiday WITH (NOLOCK) ON ce.CompanyId = holiday.CompanyId
        AND tblc.WorkDate BETWEEN holiday.FromDate
			AND holiday.ToDate
	WHERE ce.[Enabled] = 1
		AND ISNULL(ce.IsDeleted, 0) = 0
		AND (
			@EmpId IS NULL
			OR ce.EmpId = @EmpId
			)
		AND (
			e.ResignedDate IS NULL
			OR e.ResignedDate > tblc.WorkDate
			)
		--AND emp.JoinedDate <= tblc.WorkDate
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
			WHERE ce.EmpId = empca.EmpId
				AND tblc.WorkDate = empca.WorkDate
			)

	UPDATE empca
	SET empca.ShiftId = tblc.ShiftId
		,empca.ModifiedDate = @MofifiedDate
	FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tmpDate AS tblc WITH (NOLOCK) ON empca.EmpId = tblc.EmpId
		AND empca.WorkDate = tblc.WorkDate
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON empca.EmpId = ce.EmpId
			AND ce.[Enabled] = 1
			AND ce.isDeleted = 0
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
	WHERE empca.ShiftId IS NULL
		AND tblc.ShiftId IS NOT NULL
		AND empca.IsOffDay = 0
		AND empca.IsHoliday = 0
		AND empca.IsLeaveDay = 0
		AND empca.IsKeepInView = 0
		AND empca.ChangeShiftId IS NULL
		--AND emp.JoinedDate <= tblc.WorkDate
		AND (
			e.ResignedDate IS NULL
			OR e.ResignedDate > tblc.WorkDate
			)

	--UPDATE empca
	--SET empca.ShiftId = NULL
	--	,empca.ModifiedDate = @MofifiedDate
	--FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
	--	INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
	--	AND emp.[Enabled] = 1
	--	AND emp.isDeleted = 0
	--WHERE empca.ShiftId IS NOT NULL
	--	AND emp.JoinedDate > empca.WorkDate

	UPDATE empca
	SET empca.IsHoliday = 1
		,empca.ModifiedDate = @MofifiedDate
	FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON empca.EmpId = ce.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		INNER JOIN #tmpDate AS tblc ON ce.EmpId = tblc.EmpId
			AND empca.WorkDate = tblc.WorkDate
	WHERE ce.[Enabled] = 1
		AND ISNULL(ce.IsDeleted, 0) = 0
		AND (
			@EmpId IS NULL
			OR ce.EmpId = @EmpId
			)
		AND (
			emp.ResignedDate IS NULL
			OR emp.ResignedDate > tblc.WorkDate
			)
		--AND emp.JoinedDate <= tblc.WorkDate
		AND empca.IsHoliday = 0
		AND (empsum.IsLocal = 1 OR empsum.IsExpatUseHoliday = 1)
		AND EXISTS (
			SELECT 1
			FROM dbo.Holiday AS holiday WITH (NOLOCK)
			WHERE ce.CompanyId = holiday.CompanyId
                AND tblc.WorkDate BETWEEN holiday.FromDate AND holiday.ToDate
			)

	DROP TABLE #tmpDate
END