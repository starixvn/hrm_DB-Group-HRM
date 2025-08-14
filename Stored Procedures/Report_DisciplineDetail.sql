/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_DisciplineDetail]
(
    @CompanyId SMALLINT
    ,@FromDate DATE
    ,@ToDate DATE
    ,@ApproverId INT
    ,@TeamIds VARCHAR(MAX) = ''
    ,@EmployeeId INT = NULL
    ,@ReasonId INT = NULL
    ,@IsLocal BIT = NULL
    ,@HasIgnored BIT = NULL
    ,@RoleIds VARCHAR(1000) = ''
)
AS
/*
    Created: 20191204@Tim.Trinh
    Task: get discipline detail
    DB: bodb_HRM

    Revisions:
        20250404@Tim: add param @RoleIds [Redmine: #222886]
        20250627@Tim: fix bug rule ignored
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroupIds (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	DECLARE @HasEditDisciplineRole INT = 0
	--request type
	DECLARE @ChangeShift TINYINT = 5
		,@CheckIn TINYINT = 1
		,@CheckOut TINYINT = 2
		,@LateIn TINYINT = 3
		,@EarlyOut TINYINT = 4
		,@Leave TINYINT = 6
	-- discipline type
	DECLARE @ChangeShiftId TINYINT = 1
		,@MissingCheckInOutId TINYINT = 2
		,@LateInId TINYINT = 3
		,@EarlyOutId TINYINT = 4
		,@AbsentId TINYINT = 5
		,@UnpaidLeaveId TINYINT = 6
		,@WorkingUnderTimeId TINYINT = 7
		,@UnpaidLeaveAbsentId TINYINT = 8
		,@UnplannedLeaveId TINYINT = 9
		,@WeekendLeaveId TINYINT = 10
		,@SevenDaysLeaveId TINYINT = 11
	DECLARE @tblRole TABLE (RoleId INT)

	CREATE TABLE #tmpDisciplineDetail (
		EmployeeId INT
		,WorkDate DATE
        ,TeamId INT
        ,IsLocal BIT
		,ChangeShiftId INT, ChangeShiftValue TINYINT, ChangeShiftScore DECIMAL(5, 2), ChangeShiftHasViolated BIT, ChangeShiftHasIgnored BIT, ChangeShiftHasApprovedBy BIT
		,MissingCheckInOutId INT, MissingCheckInOutValue TINYINT, MissingCheckInOutScore DECIMAL(5, 2), MissingCheckInOutHasViolated BIT, MissingCheckInOutHasIgnored BIT, MissingCheckInOutHasApprovedBy BIT
		,LateInId INT, LateInValue TINYINT, LateInScore DECIMAL(5, 2), LateInHasViolated BIT, LateInHasIgnored BIT, LateInHasApprovedBy BIT
		,EarlyOutId INT, EarlyOutValue TINYINT, EarlyOutScore DECIMAL(5, 2), EarlyOutHasViolated BIT, EarlyOutHasIgnored BIT, EarlyOutHasApprovedBy BIT
		,AbsentId INT, AbsentValue TINYINT, AbsentScore DECIMAL(5, 2), AbsentHasViolated BIT, AbsentHasIgnored BIT, AbsentHasApprovedBy BIT
		,UnplannedLeaveId INT, UnplannedLeaveValue TINYINT, UnplannedLeaveScore DECIMAL(5, 2), UnplannedLeaveHasViolated BIT, UnplannedLeaveHasIgnored BIT, UnplannedLeaveHasApprovedBy BIT
		,UnpaidLeaveId INT, UnpaidLeaveValue TINYINT, UnpaidLeaveScore DECIMAL(5, 2), UnpaidLeaveHasViolated BIT, UnpaidLeaveHasIgnored BIT, UnpaidLeaveHasApprovedBy BIT
		,WorkingUnderTimeId INT, WorkingUnderTimeValue TINYINT, WorkingUnderTimeScore DECIMAL(5, 2), WorkingUnderTimeHasViolated BIT, WorkingUnderTimeHasIgnored BIT, WorkingUnderTimeHasApprovedBy BIT
		,UnpaidLeaveAbsentId INT, UnpaidLeaveAbsentValue TINYINT, UnpaidLeaveAbsentScore DECIMAL(5, 2), UnpaidLeaveAbsentHasViolated BIT, UnpaidLeaveAbsentHasIgnored BIT, UnpaidLeaveAbsentHasApprovedBy BIT
		,WeekendLeaveId INT, WeekendLeaveValue TINYINT, WeekendLeaveScore DECIMAL(5, 2), WeekendLeaveHasViolated BIT, WeekendLeaveHasIgnored BIT, WeekendLeaveHasApprovedBy BIT
		,SevenDaysLeaveId INT, SevenDaysLeaveValue TINYINT, SevenDaysLeaveScore DECIMAL(5, 2), SevenDaysLeaveHasViolated BIT, SevenDaysLeaveHasIgnored BIT, SevenDaysLeaveHasApprovedBy BIT
		,EmployeeComment NVARCHAR(MAX)
		,ApproverComment NVARCHAR(MAX)
		,IsOutOfControlReason BIT
		)

	INSERT INTO @tblRole (RoleId)
	SELECT value
	FROM STRING_SPLIT(@RoleIds, ',')

	SELECT @HasEditDisciplineRole = 1
	FROM @tblRole
	WHERE RoleId = 8 -- edit discipline

	INSERT INTO #tmpDisciplineDetail
	SELECT DISTINCT ce.EmpId
		,dis.WorkDate
        ,ce.GroupId
        ,empsum.IsLocal
		,@ChangeShiftId AS ChangeShiftId
		,dis.IsChangeShift AS ChangeShiftValue
		,dbo.fncGetDisciplineScoreById(@ChangeShiftId) AS ChangeShiftScore
		,0 AS ChangeShiftHasViolated
		,ignored.IsIgnoredChangeShift AS ChangeShiftHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS ChangeShiftHasApprovedBy
		,@MissingCheckInOutId AS MissingCheckInOutId
		,dis.IsMissingCheckInOut AS MissingCheckInOutValue
		,dbo.fncGetDisciplineScoreById(@MissingCheckInOutId) AS MissingCheckInOutScore
		,0 AS MissingCheckInOutHasViolated
		,ignored.IsIgnoredMissingCheckInOut AS MissingCheckInOutHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND (dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1) THEN 1
			ELSE 0 END
			) AS MissingCheckInOutHasApprovedBy
		,@LateInId AS LateInId
		,dis.IsLateIn AS LateInValue
		,dbo.fncGetDisciplineScoreById(@LateInId) AS LateInScore
		,0 AS LateInHasViolated
		,ignored.IsIgnoredLateIn AS LateInHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS LateInHasApprovedBy
		,@EarlyOutId AS EarlyOutId
		,dis.IsEarlyOut AS EarlyOutValue
		,dbo.fncGetDisciplineScoreById(@EarlyOutId) AS EarlyOutScore
		,0 AS EarlyOutHasViolated
		,ignored.IsIgnoredEarlyOut AS EarlyOutHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS EarlyOutHasApprovedBy
		,@AbsentId AS AbsentId
		,dis.IsAbsent AS AbsentValue
		,dbo.fncGetDisciplineScoreById(@AbsentId) AS AbsentScore
		,0 AS AbsentHasViolated
		,ignored.IsIgnoredAbsent AS AbsentHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS AbsentHasApprovedBy
		,@UnplannedLeaveId AS UnplannedLeaveId
		,dis.IsUnplannedLeave AS UnplannedLeaveValue
		,dbo.fncGetDisciplineScoreById(@UnplannedLeaveId) AS UnplannedLeaveScore
		,0 AS UnplannedLeaveHasViolated
		,ignored.IsIgnoredUnplannedLeave AS UnplannedLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnplannedLeaveHasApprovedBy
		,@UnpaidLeaveId AS UnpaidLeaveId
		,dis.IsUnpaidLeave AS UnpaidLeaveValue
		,dbo.fncGetDisciplineScoreById(@UnpaidLeaveId) AS UnpaidLeaveScore
		,0 AS UnpaidLeaveHasViolated
		,ignored.IsIgnoredUnpaidLeave AS UnpaidLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnpaidLeaveHasApprovedBy
		,@WorkingUnderTimeId AS WorkingUnderTimeId
		,dis.IsWorkingUnderTime AS WorkingUnderTimeValue
		,dbo.fncGetDisciplineScoreById(@WorkingUnderTimeId) AS WorkingUnderTimeScore
		,0 AS WorkingUnderTimeHasViolated
		,ignored.IsIgnoredWorkingUndertime AS WorkingUnderTimeHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS WorkingUnderTimeHasApprovedBy
		,@UnpaidLeaveAbsentId AS UnpaidLeaveAbsentId
		,dis.IsUnpaidLeaveAbsent AS UnpaidLeaveAbsentValue
		,dbo.fncGetDisciplineScoreById(@UnpaidLeaveAbsentId) AS UnpaidLeaveAbsentScore
		,0 AS UnpaidLeaveAbsentHasViolated
		,ignored.IsIgnoredUnpaidLeaveAbsent AS UnpaidLeaveAbsentHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnpaidLeaveAbsentHasApprovedBy
		,@WeekendLeaveId AS WeekendLeaveId
		,dis.IsWeekendLeave AS WeekendLeaveValue
		,dbo.fncGetDisciplineScoreById(@WeekendLeaveId) AS WeekendLeaveScore
		,0 AS WeekendLeaveHasViolated
		,ignored.IsIgnoredWeekendLeave AS WeekendLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS WeekendLeaveHasApprovedBy
		,@SevenDaysLeaveId AS SevenDaysLeaveId
		,dis.IsSevenDaysLeave AS SevenDaysLeaveValue
		,dbo.fncGetDisciplineScoreById(@SevenDaysLeaveId) AS SevenDaysLeaveScore
		,0 AS SevenDaysLeaveHasViolated
		,ignored.IsIgnoredSevenDaysLeave AS SevenDaysLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, ce.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS SevenDaysLeaveHasApprovedBy
		,dis.EmployeeComment
		,dis.ApproverComment
		,dis.IsOutOfControlReason
	FROM dbo.Discipline AS dis WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON  dis.EmpId = ce.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		INNER JOIN dbo.EmployeeSummary AS empSum WITH (NOLOCK) ON ce.EmpId = empSum.EmpId
		INNER JOIN dbo.DisciplineIgnore AS ignored WITH (NOLOCK) ON dis.EmpId = ignored.EmpId
		AND dis.WorkDate = ignored.WorkDate
	WHERE ce.CompanyId = @CompanyId
        AND ce.[Enabled] = 1
		AND ce.IsDeleted = 0
		AND dis.IsDeleted = 0
		AND dis.WorkDate BETWEEN @FromDate AND @ToDate
		AND (@EmployeeId IS NULL OR ce.EmpId = @EmployeeId)
		AND (
			dis.IsChangeShift = 1
			OR dis.IsMissingCheckInOut = 1
			OR dis.IsLateIn = 1
			OR dis.IsEarlyOut = 1
			OR dis.IsAbsent = 1
			OR dis.IsUnplannedLeave = 1
			OR dis.IsUnpaidLeave = 1
			OR dis.IsWorkingUnderTime = 1
			OR dis.IsUnpaidLeaveAbsent = 1
			OR dis.IsWeekendLeave = 1
			OR dis.IsSevenDaysLeave = 1
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpGroupIds AS tbl
			WHERE ce.GroupId = tbl.GroupId
			)
		AND (
			EXISTS (
				SELECT 1
				FROM @tblRole
				WHERE RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = ce.EmpId
					AND empS.ActionType = 8 -- edit discipline
					AND empS.EmpId <> @ApproverId
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE gr.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType = 8 -- edit discipline
					AND ce.EmpId <> @ApproverId
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = ce.EmpId
							AND empS.ActionType = 8
							AND ISNULL(empS.IsDeleted, 0) = 0
						)
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = ce.EmpId
					AND empS.ActionType IN (2, 3)
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE ce.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType IN (2, 3)
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = ce.EmpId
							AND empS.ActionType IN (2, 3)
							AND ISNULL(empS.IsDeleted, 0) = 0
						)
				)
			OR (
				EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId = 1 -- Employee
					)
				AND ce.EmpId = @ApproverId
				)
			)
		AND (
			@IsLocal IS NULL
			OR empSum.IsLocal = @IsLocal
			)
	ORDER BY dis.WorkDate DESC

    UPDATE tmpdis
    SET tmpdis.ChangeShiftValue = CASE WHEN drule.DisciplineTypeId = @ChangeShiftId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.ChangeShiftValue END
        ,tmpdis.MissingCheckInOutValue = CASE WHEN drule.DisciplineTypeId = @MissingCheckInOutId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.MissingCheckInOutValue END
        ,tmpdis.LateInValue = CASE WHEN drule.DisciplineTypeId = @LateInId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.LateInValue END
        ,tmpdis.EarlyOutValue = CASE WHEN drule.DisciplineTypeId = @EarlyOutId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.EarlyOutValue END
        ,tmpdis.AbsentValue = CASE WHEN drule.DisciplineTypeId = @AbsentId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.AbsentValue END
        ,tmpdis.UnplannedLeaveValue = CASE WHEN drule.DisciplineTypeId = @UnplannedLeaveId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.UnplannedLeaveValue END
        ,tmpdis.UnpaidLeaveValue = CASE WHEN drule.DisciplineTypeId = @UnpaidLeaveId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.UnpaidLeaveValue END
        ,tmpdis.WorkingUnderTimeValue = CASE WHEN drule.DisciplineTypeId = @WorkingUnderTimeId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.WorkingUnderTimeValue END
        ,tmpdis.UnpaidLeaveAbsentValue = CASE WHEN drule.DisciplineTypeId = @UnpaidLeaveAbsentId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.UnpaidLeaveAbsentValue END
        ,tmpdis.WeekendLeaveValue = CASE WHEN drule.DisciplineTypeId = @WeekendLeaveId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.WeekendLeaveValue END
        ,tmpdis.SevenDaysLeaveValue = CASE WHEN drule.DisciplineTypeId = @SevenDaysLeaveId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.SevenDaysLeaveValue END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.ChangeShiftHasViolated = CASE WHEN tmpdis.ChangeShiftValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @ChangeShiftId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.MissingCheckInOutHasViolated = CASE WHEN tmpdis.MissingCheckInOutValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @MissingCheckInOutId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.LateInHasViolated = CASE WHEN tmpdis.LateInValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @LateInId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.EarlyOutHasViolated = CASE WHEN tmpdis.EarlyOutValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @EarlyOutId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.AbsentHasViolated = CASE WHEN tmpdis.AbsentValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @AbsentId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.UnplannedLeaveHasViolated = CASE WHEN tmpdis.UnplannedLeaveValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @UnplannedLeaveId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.UnpaidLeaveHasViolated = CASE WHEN tmpdis.UnpaidLeaveValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @UnpaidLeaveId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.WorkingUnderTimeHasViolated = CASE WHEN tmpdis.WorkingUnderTimeValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @WorkingUnderTimeId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.UnpaidLeaveAbsentHasViolated = CASE WHEN tmpdis.UnpaidLeaveAbsentValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @UnpaidLeaveAbsentId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.WeekendLeaveHasViolated = CASE WHEN tmpdis.WeekendLeaveValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @WeekendLeaveId
        AND drule.IsLocal = tmpdis.IsLocal

    UPDATE tmpdis
    SET tmpdis.SevenDaysLeaveHasViolated = CASE WHEN tmpdis.SevenDaysLeaveValue = 1 AND drule.Value = 1 THEN 1 ELSE 0 END
    FROM #tmpDisciplineDetail AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.TeamId = drule.GroupId
        AND drule.DisciplineTypeId = @SevenDaysLeaveId
        AND drule.IsLocal = tmpdis.IsLocal

	SELECT ce.EmpId AS EmployeeId
		,ce.Code
		,ce.NickName
		,emp.FullName
		,dis.IsLocal
		,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,shift.Code AS ShiftName
		,empatt.InFixed AS CheckIn
		,empatt.OutFixed AS CheckOut
		,empatt.LateIn
		,empatt.EarlyOut
		,empatt.TotalWorkHours AS TotalHours
		,dis.*
	FROM #tmpDisciplineDetail AS dis WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON dis.EmployeeId = ce.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON dis.EmployeeId = empatt.EmpId
		AND dis.WorkDate = empatt.AttendanceDate
		LEFT JOIN dbo.[Shift] AS shift WITH (NOLOCK) ON empatt.ShiftId = shift.ShiftId
    WHERE (
            @ReasonId IS NULL
            OR (
                EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @ReasonId
						AND drule.Value = 1
						AND drule.GroupId = ce.GroupId
						AND drule.IsLocal = dis.IsLocal
					)
                AND (
                    (@ReasonId = @ChangeShiftId AND dis.ChangeShiftValue = 1)
                    OR (@ReasonId = @MissingCheckInOutId AND dis.MissingCheckInOutValue = 1)
                    OR (@ReasonId = @LateInId AND dis.LateInValue = 1)
                    OR (@ReasonId = @EarlyOutId AND dis.EarlyOutValue = 1)
                    OR (@ReasonId = @AbsentId AND dis.AbsentValue = 1)
                    OR (@ReasonId = @UnplannedLeaveId AND dis.UnplannedLeaveValue = 1)
                    OR (@ReasonId = @UnpaidLeaveId AND dis.UnpaidLeaveValue = 1)
                    OR (@ReasonId = @WorkingUnderTimeId AND dis.WorkingUnderTimeValue = 1)
                    OR (@ReasonId = @UnpaidLeaveAbsentId AND dis.UnpaidLeaveAbsentValue = 1)
                    OR (@ReasonId = @WeekendLeaveId AND dis.WeekendLeaveValue = 1)
                    OR (@ReasonId = @SevenDaysLeaveId AND dis.SevenDaysLeaveValue = 1)
                )
            )
        )
        AND (
            @HasIgnored IS NULL
            OR (dis.ChangeShiftValue = 1 AND dis.ChangeShiftHasIgnored = @HasIgnored)
            OR (dis.MissingCheckInOutValue = 1 AND dis.MissingCheckInOutHasIgnored = @HasIgnored)
            OR (dis.LateInValue = 1 AND dis.LateInHasIgnored = @HasIgnored)
            OR (dis.EarlyOutValue = 1 AND dis.EarlyOutHasIgnored = @HasIgnored)
            OR (dis.AbsentValue = 1 AND dis.AbsentHasIgnored = @HasIgnored)
            OR (dis.UnplannedLeaveValue = 1 AND dis.UnplannedLeaveHasIgnored = @HasIgnored)
            OR (dis.UnpaidLeaveValue = 1 AND dis.UnpaidLeaveHasIgnored = @HasIgnored)
            OR (dis.WorkingUnderTimeValue = 1 AND dis.WorkingUnderTimeHasIgnored = @HasIgnored)
            OR (dis.UnpaidLeaveAbsentValue = 1 AND dis.UnpaidLeaveAbsentHasIgnored = @HasIgnored)
            OR (dis.WeekendLeaveValue = 1 AND dis.WeekendLeaveHasIgnored = @HasIgnored)
            OR (dis.SevenDaysLeaveValue = 1 AND dis.SevenDaysLeaveHasIgnored = @HasIgnored)
        )
	ORDER BY dis.WorkDate DESC

	SELECT did.EmpId AS EmployeeId
		,ce.NickName AS IgnoreBy
		,did.WorkDate
		,did.DisciplineTypeId
		,did.IgnoreDate
	FROM dbo.DisciplineIgnoreDetail AS did WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = did.IgnoreBy
	WHERE did.EmpId = @EmployeeId
        AND did.WorkDate BETWEEN @FromDate AND @ToDate
		AND ce.CompanyId = @CompanyId

	DROP TABLE #tmpDisciplineDetail

	DROP TABLE #tmpGroupIds
END
