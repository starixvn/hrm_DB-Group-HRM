/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[tmpEmployeeCalendar_Insert]
(
    @CompanyId SMALLINT = NULL
    ,@fromDate DATE
	,@toDate DATE
	,@empIds VARCHAR(MAX) = NULL
	,@isEnable BIT = NULL
	,@isDelete BIT = NULL
	,@isUpdateRequestData BIT = 0
)
AS
/*
    Created: Tim.Trinh@2019-10-10
    Task: get employee calendar
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	DECLARE @tempDate DATE = @fromDate
		,@GeneralLeaveId TINYINT = 0
		,@OffDayShiftId SMALLINT = - 1
		-- work type
		,@OffDay TINYINT = 1
		,@LeaveDay TINYINT = 2
		-- leave type
		,@MaternityLeaveId TINYINT = 12
		,@PaternityLeaveId TINYINT = 14
		-- request type
		,@ChangeShiftRequestTypeId TINYINT = 5
		,@LeaveRequestTypeId TINYINT = 6
		,@KeepInViewRequestTypeId TINYINT = 7
		-- change shift type
		,@ChangeShiftTypeId TINYINT = 1
		,@MoveOfDayTypeId TINYINT = 2
		-- kiv type
		,@KeepInViewByDayTypeId TINYINT = 1
		-- request status
		,@PendingStatusId TINYINT = 1
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7

	CREATE TABLE #tempEmployeeIds (
		EmpId INT PRIMARY KEY
        ,JoinedDate DATE
		,ResignedDate DATE
		)

	CREATE TABLE #tempEmployeeCalendar (
		EmpId INT
		,WorkDate DATE
		,ShiftId INT
		,IsOffDay BIT
		,IsHoliday BIT
		,PRIMARY KEY (EmpId, WorkDate)
		)

	IF ISNULL(@empIds, '') <> ''
	BEGIN
		INSERT INTO #tempEmployeeIds (
			EmpId
			,JoinedDate
			,ResignedDate
			)
		SELECT emp.EmpId
			,emp.JoinedDate
			,emp.ResignedDate
		FROM STRING_SPLIT(@empIds, ',') AS tmp
			INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON CAST(tmp.value AS INT) = emp.EmpId
	END
	ELSE
	BEGIN
		INSERT INTO #tempEmployeeIds (
			EmpId
			,JoinedDate
			,ResignedDate
			)
		SELECT EmpId
			,JoinedDate
			,ResignedDate
		FROM dbo.Employee WITH (NOLOCK)
		WHERE (
				@isEnable IS NULL
				OR [Enabled] = @isEnable
				)
			AND (
				@isDelete IS NULL
				OR isDeleted = @isDelete
				)
	END

	INSERT INTO #tempEmployeeCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsOffDay
		,IsHoliday
		)
	SELECT empca.EmpId
		,empca.WorkDate
		,empca.ShiftId
		,ISNULL(empca.IsOffDay, 0)
		,ISNULL(empca.IsHoliday, 0)
	FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
		INNER JOIN #tempEmployeeIds AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		--AND (
		--	empca.ShiftId IS NOT NULL
		--	OR empca.IsOffDay = 1
		--	OR empca.IsHoliday = 1
		--	)

	WHILE @tempDate <= @toDate
	BEGIN
		INSERT INTO #tempEmployeeCalendar (
			EmpId
			,WorkDate
			,ShiftId
			,IsOffDay
			,IsHoliday
			)
		SELECT emp.EmpId
			,@tempDate
			,CASE 
				WHEN DATEPART(dw, @tempDate) = 1 THEN empshift.SunShift
				WHEN DATEPART(dw, @tempDate) = 2 THEN empshift.MonShift
				WHEN DATEPART(dw, @tempDate) = 3 THEN empshift.TueShift
				WHEN DATEPART(dw, @tempDate) = 4 THEN empshift.WedShift
				WHEN DATEPART(dw, @tempDate) = 5 THEN empshift.ThuShift
				WHEN DATEPART(dw, @tempDate) = 6 THEN empshift.FriShift
				WHEN DATEPART(dw, @tempDate) = 7 THEN empshift.SatShift
				END
			,CASE 
				WHEN DATEPART(dw, @tempDate) = 1
					AND ISNULL(empshift.SunShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 2
					AND ISNULL(empshift.MonShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 3
					AND ISNULL(empshift.TueShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 4
					AND ISNULL(empshift.WedShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 5
					AND ISNULL(empshift.ThuShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 6
					AND ISNULL(empshift.FriShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				WHEN DATEPART(dw, @tempDate) = 7
					AND ISNULL(empshift.SatShift, @OffDayShiftId) = @OffDayShiftId THEN 1
				ELSE 0
				END
			,(CASE
			    WHEN (
					    empsum.IsLocal = 1
					    OR (
						    empsum.IsLocal = 0
						    AND empsum.IsExpatUseHoliday = 1
						    )
					    )
				    AND holiday.Id IS NOT NULL THEN 1
			    ELSE 0 END
			    )
		FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
			AND empsum.IsDefaultSchedule = 1
			INNER JOIN dbo.EmployeeDefaultShift AS empshift WITH (NOLOCK) ON emp.EmpId = empshift.EmpId
            LEFT JOIN dbo.Holiday AS holiday WITH (NOLOCK) ON holiday.CompanyId = @CompanyId
            AND @tempDate BETWEEN holiday.FromDate
			    AND holiday.ToDate
		WHERE NOT EXISTS (
				SELECT 1
				FROM #tempEmployeeCalendar AS tbl WITH (NOLOCK)
				WHERE tbl.EmpId = emp.EmpId
					AND tbl.WorkDate = @tempDate
				)

		INSERT INTO #tempEmployeeCalendar (
			EmpId
			,WorkDate
			,ShiftId
			,IsOffDay
			,IsHoliday
			)
		SELECT emp.EmpId
			,@tempDate
			,empshift.ShiftId
			,0
			,(CASE
			    WHEN (
					    empsum.IsLocal = 1
					    OR (
						    empsum.IsLocal = 0
						    AND empsum.IsExpatUseHoliday = 1
						    )
					    )
				    AND holiday.Id IS NOT NULL THEN 1
			    ELSE 0 END
			    )
		FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
			AND empsum.IsDefaultSchedule = 0
            LEFT JOIN dbo.Holiday AS holiday WITH (NOLOCK) ON holiday.CompanyId = @CompanyId
            AND @tempDate BETWEEN holiday.FromDate
			    AND holiday.ToDate
			OUTER APPLY (
			SELECT TOP 1 empshift.ShiftId
			FROM dbo.ScheduleArrangementDefaultShift AS empshift WITH (NOLOCK)
			WHERE empshift.EmployeeId = emp.EmpId
				--AND empshift.ShiftId > 0
				AND empshift.FromDate <= @tempDate
			ORDER BY empshift.FromDate DESC
			) AS empshift
		WHERE NOT EXISTS (
				SELECT 1
				FROM #tempEmployeeCalendar AS tbl WITH (NOLOCK)
				WHERE tbl.EmpId = emp.EmpId
					AND tbl.WorkDate = @tempDate
				)

		SET @tempDate = DATEADD(d, 1, @tempDate)
	END

	UPDATE empca
	SET empca.ShiftId = NULL
		,empca.IsOffDay = 0
		,empca.IsHoliday = 0
	FROM #tempEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
	WHERE (emp.JoinedDate > empca.WorkDate OR emp.ResignedDate <= empca.WorkDate)
		AND (empca.ShiftId IS NOT NULL OR empca.IsOffDay = 1 AND empca.IsHoliday = 1)

	UPDATE empca
	SET empca.ShiftId = tmp.ShiftId
		,empca.IsOffDay = tmp.IsOffDay
		,empca.IsHoliday = tmp.IsHoliday
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS emp WITH (NOLOCK) ON empca.EmpId = emp.EmpId
		INNER JOIN #tempEmployeeCalendar AS tmp WITH (ROWLOCK) ON empca.EmpId = tmp.EmpId
		AND empca.WorkDate = tmp.WorkDate
	WHERE (
			empca.RequestId IS NULL
			OR (
				empca.RequestId IS NOT NULL
				AND (
					empca.RequestTypeId =  @LeaveRequestTypeId
					OR empca.RequestTypeId = @ChangeShiftRequestTypeId
					OR empca.RequestTypeId = @KeepInViewRequestTypeId
					)
				)
			)
		AND (
			ISNULL(empca.ShiftId, 0) != ISNULL(tmp.ShiftId, 0)
			OR empca.IsOffDay != tmp.IsOffDay
			OR empca.IsHoliday != tmp.IsHoliday
			)

	INSERT INTO dbo.tmpEmployeeCalendar (
		EmpId
		,WorkDate
		,ShiftId
		,IsOffDay
		,IsHoliday
		,ModifiedDate
		)
	SELECT tmp.EmpId
		,tmp.WorkDate
		,tmp.ShiftId
		,tmp.IsOffDay
		,tmp.IsHoliday
		,CASE 
			WHEN emp.JoinedDate <= tmp.WorkDate
				AND (
					emp.ResignedDate IS NULL
					OR emp.ResignedDate > tmp.WorkDate
					) THEN GETDATE()
			ELSE NULL
			END
	FROM #tempEmployeeCalendar AS tmp WITH (ROWLOCK)
		INNER JOIN #tempEmployeeIds AS emp WITH (NOLOCK) ON tmp.EmpId = emp.EmpId
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
			WHERE empca.EmpId = tmp.EmpId
				AND empca.WorkDate = tmp.WorkDate
			)

	UPDATE dbo.tmpEmployeeCalendar WITH (ROWLOCK, UPDLOCK)
	SET IsOffDay = 0
		,ModifiedDate = GETDATE()
	WHERE WorkDate BETWEEN @fromDate
			AND @toDate
		AND IsOffDay = 1
		AND IsHoliday = 1

	IF @isUpdateRequestData = 0 RETURN

	-- overtime
	UPDATE empca
	SET empca.IsOvertime = (CASE 
			WHEN overtime.EmpId IS NOT NULL THEN 1
			ELSE 0 END
			)
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		LEFT JOIN dbo.OTDailyRequest AS overtime WITH (NOLOCK) ON empca.EmpId = overtime.EmpId
		AND empca.WorkDate = overtime.OvertimeDate
		AND overtime.[Status] NOT IN (@PendingStatusId, @NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.IsOvertime = 1
				AND overtime.EmpId IS NULL
				)
			OR (
				empca.IsOvertime = 0
				AND overtime.EmpId IS NOT NULL
				)
			)

	-- keep in view
	UPDATE empca
	SET empca.RequestId = kiv.RequestId
		,empca.RequestTypeId = kiv.RequestType
		,empca.IsKeepInView = CASE 
			WHEN kiv.RequestId IS NULL THEN 0
			ELSE 1
			END
		,empca.ShiftId = CASE 
			WHEN kiv.KeepInViewType = @KeepInViewByDayTypeId
				AND kiv.ShiftId IS NOT NULL THEN kiv.ShiftId
			ELSE empca.ShiftId
			END
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		OUTER APPLY (
		SELECT kiv.RequestId
			,kiv.KeepInViewType
			,kiv.ShiftId
			,r.RequestType
		FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON r.RequestId = kiv.RequestId
			AND empca.EmpId = kiv.EmpId
			AND empca.WorkDate = kiv.OnDate
			AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		) AS kiv
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.IsKeepInView = 1
				--AND empca.RequestTypeId = @KeepInViewRequestTypeId
				AND kiv.RequestId IS NULL
				)
			OR (
				empca.IsKeepInView = 0
				AND kiv.RequestId IS NOT NULL
				)
			)

	-- change shift
	UPDATE empca
	SET empca.RequestId = cs.RequestId
		,empca.RequestTypeId = cs.RequestType
		,empca.ShiftId = (CASE 
			WHEN cs.ToShift = @OffDayShiftId THEN NULL
			ELSE cs.ToShift END
			)
		,empca.IsOffDay = (CASE 
			WHEN cs.ToShift = @OffDayShiftId THEN 1
			ELSE empca.IsOffDay END
			)
		,empca.ChangeShiftTypeId = cs.ChangeShiftTypeId
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		OUTER APPLY (
		SELECT r.RequestId
			,r.RequestType
			,@ChangeShiftTypeId AS ChangeShiftTypeId
			,csdt.ToShift
		FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
			INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
			AND empca.EmpId = cs.EmpId
			AND empca.WorkDate = csdt.OnDate
			AND cs.TypeId = @ChangeShiftTypeId
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cs.RequestId = r.RequestId
			AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		) AS cs
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.RequestId IS NOT NULL
				AND empca.RequestTypeId = @ChangeShiftRequestTypeId
				AND empca.ChangeShiftTypeId = @ChangeShiftTypeId
				--AND cs.RequestId IS NULL
				)
			OR (
				empca.RequestId IS NULL
				AND cs.RequestId IS NOT NULL
				)
			)

	-- change shift - move off day
	UPDATE empca
	SET empca.RequestId = cs.RequestId
		,empca.RequestTypeId = cs.RequestType
		,empca.ShiftId = CASE 
			WHEN cs.RequestId IS NOT NULL THEN cs.ToShift
			ELSE NULL
			END
		,empca.IsOffDay = CASE 
			WHEN cs.RequestId IS NOT NULL THEN 0
			ELSE empca.IsOffDay
			END
		,empca.ChangeShiftTypeId = cs.ChangeShiftTypeId
		,empca.MoveOffFromDate = NULL
		,empca.MoveOffToDate = cs.ToDate
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		OUTER APPLY (
		SELECT r.RequestId
			,r.RequestType
			,@MoveOfDayTypeId AS ChangeShiftTypeId
			,csdt.FromShift
			,csdt.ToShift
			,csdt.ToDate
		FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
			INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
			AND empca.EmpId = cs.EmpId
			AND empca.WorkDate = csdt.OnDate
			AND cs.TypeId = @MoveOfDayTypeId
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cs.RequestId = r.RequestId
			AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		) AS cs
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.RequestId IS NOT NULL
				AND empca.RequestTypeId = @ChangeShiftRequestTypeId
				AND empca.ChangeShiftTypeId = @MoveOfDayTypeId
				AND empca.MoveOffToDate IS NOT NULL
				--AND cs.RequestId IS NULL
				)
			OR (
				empca.RequestId IS NULL
				AND cs.RequestId IS NOT NULL
				)
			)

	UPDATE empca
	SET empca.RequestId = cs.RequestId
		,empca.RequestTypeId = cs.RequestType
		,empca.ShiftId = CASE 
			WHEN cs.RequestId IS NOT NULL THEN NULL
			ELSE empca.ShiftId
			END
		,empca.IsOffDay = CASE 
			WHEN cs.RequestId IS NOT NULL THEN 1
			ELSE empca.IsOffDay
			END
		,empca.ChangeShiftTypeId = cs.ChangeShiftTypeId
		,empca.MoveOffFromDate = cs.OnDate
		,empca.MoveOffToDate = NULL
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		OUTER APPLY (
		SELECT r.RequestId
			,r.RequestType
			,@MoveOfDayTypeId AS ChangeShiftTypeId
			,csdt.OnDate
		FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
			INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
			AND empca.EmpId = cs.EmpId
			AND empca.WorkDate = csdt.ToDate
			AND cs.TypeId = @MoveOfDayTypeId
			AND (
				csdt.OnDate BETWEEN @fromDate
					AND @toDate
				OR csdt.ToDate BETWEEN @fromDate
					AND @toDate
				)
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cs.RequestId = r.RequestId
			AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		) AS cs
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.RequestId IS NOT NULL
				AND empca.RequestTypeId = @ChangeShiftRequestTypeId
				AND empca.ChangeShiftTypeId = @MoveOfDayTypeId
				AND empca.MoveOffFromDate IS NOT NULL
				--AND cs.RequestId IS NULL
				)
			OR (
				empca.RequestId IS NULL
				AND cs.RequestId IS NOT NULL
				)
			)

	-- leave request
	CREATE TABLE #tblLeaveRequest (
		RequestId BIGINT
		,EmpId INT
		,WorkDate DATE
		,RequestTypeId SMALLINT
		,LeaveTypeId INT
		,WorkType TINYINT
		)

	CREATE TABLE #tblHalfDayRequest (
		RequestId BIGINT
		,RequestTypeId SMALLINT
		,EmpId INT
		,WorkDate DATE
		,FromTime DATETIME
		,ToTime DATETIME
		,LeaveTypeId INT
		,WorkType TINYINT
		,LeaveDay DECIMAL(2, 1)
		)

	INSERT INTO #tblLeaveRequest (
		RequestId
		,EmpId
		,WorkDate
		,RequestTypeId
		,LeaveTypeId
		,WorkType
		)
	SELECT r.RequestId
		,empca.EmpId
		,empca.WorkDate
		,r.RequestType
		,lrdt.LeaveType
		,lrdt.WorkType
	FROM #tempEmployeeIds AS tblemp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
		INNER JOIN dbo.LeaveRequestDetail AS lrdt WITH (NOLOCK) ON lrdt.EmpId = tblemp.EmpId
		AND lrdt.OnDate = empca.WorkDate
		AND lrdt.WorkType IN (@OffDay, @LeaveDay)
		AND lrdt.IsHalfDay = 0
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lrdt.RequestId = r.RequestId
		AND empca.EmpId = r.EmpId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)

	INSERT INTO #tblLeaveRequest (
		RequestId
		,EmpId
		,WorkDate
		,RequestTypeId
		,LeaveTypeId
		,WorkType
		)
	SELECT r.RequestId
		,empca.EmpId
		,empca.WorkDate
		,r.RequestType
		,lr.LeaveType
		,@LeaveDay AS WorkType
	FROM #tempEmployeeIds AS tblemp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND empca.IsOffDay = 0
		AND empca.IsHoliday = 0
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON lr.EmpId = tblemp.EmpId
		AND empca.WorkDate BETWEEN lr.FromDate
			AND lr.ToDate
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lr.RequestId = r.RequestId
		AND tblemp.EmpId = r.EmpId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
	WHERE NOT EXISTS (
			SELECT 1
			FROM #tblLeaveRequest AS tblreq WITH (NOLOCK)
			WHERE lr.RequestId = tblreq.RequestId
			)
		AND NOT EXISTS (
			SELECT ldt.RequestId
			FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
			WHERE lr.RequestId = ldt.RequestId
			)

	UPDATE empca
	SET empca.RequestId = lr.RequestId
		,empca.RequestTypeId = lr.RequestTypeId
		,empca.LeaveTypeId = lr.LeaveTypeId
		,empca.IsOffDay = CASE 
			WHEN lr.WorkType = @OffDay THEN 1
			ELSE empca.IsOffDay
			END
		,empca.IsLeaveDay = CASE 
			WHEN lr.RequestId IS NOT NULL THEN 1
			ELSE 0
			END
		,empca.IsLeaveOffDay = CASE 
			WHEN lr.WorkType = @OffDay THEN 1
			ELSE 0
			END
		,empca.LeaveDay = CASE 
			WHEN lr.RequestId IS NOT NULL THEN 1
			ELSE 0
			END
		,empca.FromTime = NULL
		,empca.ToTime = NULL
		,empca.LeaveTypeId2 = NULL
		,empca.FromTime2 = NULL
		,empca.ToTime2 = NULL
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON empca.EmpId = tblemp.EmpId
		LEFT JOIN #tblLeaveRequest AS lr ON empca.EmpId = lr.EmpId
		AND empca.WorkDate = lr.WorkDate
	WHERE empca.WorkDate BETWEEN @fromDate
			AND @toDate
		AND (
			(
				empca.RequestId IS NOT NULL
				AND empca.RequestTypeId = @LeaveRequestTypeId
				--AND empca.LeaveDay = 1
				--AND lr.RequestId IS NULL
				)
			OR (
				empca.RequestId IS NULL
				AND lr.RequestId IS NOT NULL
				)
			)

	INSERT INTO #tblHalfDayRequest (
		RequestId
		,RequestTypeId
		,EmpId
		,WorkDate
		,FromTime
		,ToTime
		,LeaveTypeId
		,WorkType
		,LeaveDay
		)
	SELECT r.RequestId
		,r.RequestType
		,r.EmpId
		,lrdt.OnDate
		,lrdt.FromTime
		,lrdt.ToTime
		,lrdt.LeaveType
		,lrdt.WorkType
		,0.5 AS LeaveDay
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tempEmployeeIds AS tblemp WITH (NOLOCK) ON r.EmpId = tblemp.EmpId
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON tblemp.EmpId = ce.EmpId
		INNER JOIN dbo.LeaveRequestDetail AS lrdt WITH (NOLOCK) ON r.RequestId = lrdt.RequestId
		AND r.CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		AND lrdt.IsHalfDay = 1
		AND lrdt.WorkType = @LeaveDay
		AND lrdt.OnDate BETWEEN @fromDate
			AND @toDate
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.CompanyId = ce.CompanyId
        AND lrdt.LeaveType = lv.LeaveTypeId
	WHERE (@CompanyId IS NULL OR ce.CompanyId = @CompanyId)
        AND NOT EXISTS (
			SELECT 1
			FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
			WHERE r.EmpId = empca.EmpId
				AND lrdt.OnDate = empca.WorkDate
				AND (
					empca.LeaveDay = 1
					OR (
						empca.LeaveDay = 0.5
						AND (
							empca.LeaveTypeId = lrdt.LeaveType
							OR empca.LeaveTypeId2 = lrdt.LeaveType
							)
						)
					)
			)

	UPDATE empca
	SET empca.RequestId = rq.RequestId
		,empca.RequestTypeId = rq.RequestTypeId
		,empca.IsLeaveDay = 1
		,empca.LeaveDay = rq.LeaveDay
		,empca.LeaveTypeId = rq.LeaveTypeId
		,empca.FromTime = rq.FromTime
		,empca.ToTime = rq.ToTime
		,empca.LeaveTypeId2 = NULL
		,empca.FromTime2 = NULL
		,empca.ToTime2 = NULL
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblHalfDayRequest AS rq ON empca.EmpId = rq.EmpId
		AND empca.WorkDate = rq.WorkDate
	WHERE empca.LeaveTypeId IS NULL
		OR empca.LeaveDay = 0.5

	UPDATE empca
	SET empca.LeaveDay = CASE 
			WHEN empca.LeaveDay = 1 THEN 1
			ELSE empca.LeaveDay + rq.LeaveDay
			END
		,empca.IsLeaveDay = 1
		,empca.LeaveTypeId2 = rq.LeaveTypeId
		,empca.FromTime2 = rq.FromTime
		,empca.ToTime2 = rq.ToTime
		,empca.ModifiedDate = GETDATE()
	FROM dbo.tmpEmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblHalfDayRequest AS rq ON empca.EmpId = rq.EmpId
		AND empca.WorkDate = rq.WorkDate
	WHERE empca.FromTime <> rq.FromTime
		AND empca.ToTime <> rq.ToTime

	DROP TABLE #tempEmployeeIds

	DROP TABLE #tblLeaveRequest

	DROP TABLE #tempEmployeeCalendar

	DROP TABLE #tblHalfDayRequest
END