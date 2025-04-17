/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_DisciplineDetail] @FromDate DATE
	,@ToDate DATE
	,@ApproverId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@ReasonId INT = NULL
	,@IsLocal BIT = NULL
	,@HasIgnored BIT = NULL
	,@CompanyId SMALLINT
    ,@RoleIds VARCHAR(1000) = ''
AS
/*
Created: 20191204@Tim.Trinh
Task: get discipline detail
DB: HRM

Revisions:
    20250404@Tim: add param @RoleIds [Redmine: #222886]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblGroupIds (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
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

	CREATE TABLE #tblDisciplineDetail (
		EmployeeId INT
		,WorkDate DATE
		,ChangeShiftId INT
		,ChangeShiftValue INT
		,ChangeShiftScore DECIMAL(5, 2)
		,ChangeShiftHasViolated BIT
		,ChangeShiftHasIgnored BIT
		,ChangeShiftHasApprovedBy BIT
		,MissingCheckInOutId INT
		,MissingCheckInOutValue INT
		,MissingCheckInOutScore DECIMAL(5, 2)
		,MissingCheckInOutHasViolated BIT
		,MissingCheckInOutHasIgnored BIT
		,MissingCheckInOutHasApprovedBy BIT
		,LateInId INT
		,LateInValue INT
		,LateInScore DECIMAL(5, 2)
		,LateInHasViolated BIT
		,LateInHasIgnored BIT
		,LateInHasApprovedBy BIT
		,EarlyOutId INT
		,EarlyOutValue INT
		,EarlyOutScore DECIMAL(5, 2)
		,EarlyOutHasViolated BIT
		,EarlyOutHasIgnored BIT
		,EarlyOutHasApprovedBy BIT
		,AbsentId INT
		,AbsentValue INT
		,AbsentScore DECIMAL(5, 2)
		,AbsentHasViolated BIT
		,AbsentHasIgnored BIT
		,AbsentHasApprovedBy BIT
		,UnplannedLeaveId INT
		,UnplannedLeaveValue INT
		,UnplannedLeaveScore DECIMAL(5, 2)
		,UnplannedLeaveHasViolated BIT
		,UnplannedLeaveHasIgnored BIT
		,UnplannedLeaveHasApprovedBy BIT
		,UnpaidLeaveId INT
		,UnpaidLeaveValue INT
		,UnpaidLeaveScore DECIMAL(5, 2)
		,UnpaidLeaveHasViolated BIT
		,UnpaidLeaveHasIgnored BIT
		,UnpaidLeaveHasApprovedBy BIT
		,WorkingUnderTimeId INT
		,WorkingUnderTimeValue INT
		,WorkingUnderTimeScore DECIMAL(5, 2)
		,WorkingUnderTimeHasViolated BIT
		,WorkingUnderTimeHasIgnored BIT
		,WorkingUnderTimeHasApprovedBy BIT
		,UnpaidLeaveAbsentId INT
		,UnpaidLeaveAbsentValue INT
		,UnpaidLeaveAbsentScore DECIMAL(5, 2)
		,UnpaidLeaveAbsentHasViolated BIT
		,UnpaidLeaveAbsentHasIgnored BIT
		,UnpaidLeaveAbsentHasApprovedBy BIT
		,WeekendLeaveId INT
		,WeekendLeaveValue INT
		,WeekendLeaveScore DECIMAL(5, 2)
		,WeekendLeaveHasViolated BIT
		,WeekendLeaveHasIgnored BIT
		,WeekendLeaveHasApprovedBy BIT
		,SevenDaysLeaveId INT
		,SevenDaysLeaveValue INT
		,SevenDaysLeaveScore DECIMAL(5, 2)
		,SevenDaysLeaveHasViolated BIT
		,SevenDaysLeaveHasIgnored BIT
		,SevenDaysLeaveHasApprovedBy BIT
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

	INSERT INTO #tblDisciplineDetail
	SELECT DISTINCT emp.EmpId
		,dis.WorkDate
		,@ChangeShiftId AS ChangeShiftId
		,dis.IsChangeShift AS ChangeShiftValue
		,dbo.fncGetDisciplineScoreById(@ChangeShiftId) AS ChangeShiftScore
		,(CASE 
			WHEN dis.IsChangeShift = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @ChangeShiftId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS ChangeShiftHasViolated
		,ignored.IsIgnoredChangeShift AS ChangeShiftHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS ChangeShiftHasApprovedBy
		,@MissingCheckInOutId AS MissingCheckInOutId
		,dis.IsMissingCheckInOut AS MissingCheckInOutValue
		,dbo.fncGetDisciplineScoreById(@MissingCheckInOutId) AS MissingCheckInOutScore
		,(CASE 
			WHEN dis.IsMissingCheckInOut = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @MissingCheckInOutId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS MissingCheckInOutHasViolated
		,ignored.IsIgnoredMissingCheckInOut AS MissingCheckInOutHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND (dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1) THEN 1
			ELSE 0 END
			) AS MissingCheckInOutHasApprovedBy
		,@LateInId AS LateInId
		,dis.IsLateIn AS LateInValue
		,dbo.fncGetDisciplineScoreById(@LateInId) AS LateInScore
		,(CASE 
			WHEN dis.IsLateIn = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @LateInId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS LateInHasViolated
		,ignored.IsIgnoredLateIn AS LateInHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS LateInHasApprovedBy
		,@EarlyOutId AS EarlyOutId
		,dis.IsEarlyOut AS EarlyOutValue
		,dbo.fncGetDisciplineScoreById(@EarlyOutId) AS EarlyOutScore
		,(CASE 
			WHEN dis.IsEarlyOut = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @EarlyOutId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS EarlyOutHasViolated
		,ignored.IsIgnoredEarlyOut AS EarlyOutHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS EarlyOutHasApprovedBy
		,@AbsentId AS AbsentId
		,dis.IsAbsent AS AbsentValue
		,dbo.fncGetDisciplineScoreById(@AbsentId) AS AbsentScore
		,(CASE 
			WHEN dis.IsAbsent = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @AbsentId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS AbsentHasViolated
		,ignored.IsIgnoredAbsent AS AbsentHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS AbsentHasApprovedBy
		,@UnplannedLeaveId AS UnplannedLeaveId
		,dis.IsUnplannedLeave AS UnplannedLeaveValue
		,dbo.fncGetDisciplineScoreById(@UnplannedLeaveId) AS UnplannedLeaveScore
		,(CASE 
			WHEN dis.IsUnplannedLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @UnplannedLeaveId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS UnplannedLeaveHasViolated
		,ignored.IsIgnoredUnplannedLeave AS UnplannedLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnplannedLeaveHasApprovedBy
		,@UnpaidLeaveId AS UnpaidLeaveId
		,dis.IsUnpaidLeave AS UnpaidLeaveValue
		,dbo.fncGetDisciplineScoreById(@UnpaidLeaveId) AS UnpaidLeaveScore
		,(CASE 
			WHEN dis.IsUnpaidLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @UnpaidLeaveId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS UnpaidLeaveHasViolated
		,ignored.IsIgnoredUnpaidLeave AS UnpaidLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnpaidLeaveHasApprovedBy
		,@WorkingUnderTimeId AS WorkingUnderTimeId
		,dis.IsWorkingUnderTime AS WorkingUnderTimeValue
		,dbo.fncGetDisciplineScoreById(@WorkingUnderTimeId) AS WorkingUnderTimeScore
		,(CASE 
			WHEN dis.IsWorkingUndertime = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @WorkingUnderTimeId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS WorkingUnderTimeHasViolated
		,ignored.IsIgnoredWorkingUndertime AS WorkingUnderTimeHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS WorkingUnderTimeHasApprovedBy
		,@UnpaidLeaveAbsentId AS UnpaidLeaveAbsentId
		,dis.IsUnpaidLeaveAbsent AS UnpaidLeaveAbsentValue
		,dbo.fncGetDisciplineScoreById(@UnpaidLeaveAbsentId) AS UnpaidLeaveAbsentScore
		,(CASE 
			WHEN dis.IsUnpaidLeaveAbsent = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @UnpaidLeaveAbsentId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS UnpaidLeaveAbsentHasViolated
		,ignored.IsIgnoredUnpaidLeaveAbsent AS UnpaidLeaveAbsentHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS UnpaidLeaveAbsentHasApprovedBy
		,@WeekendLeaveId AS WeekendLeaveId
		,dis.IsWeekendLeave AS WeekendLeaveValue
		,dbo.fncGetDisciplineScoreById(@WeekendLeaveId) AS WeekendLeaveScore
		,(CASE 
			WHEN dis.IsWeekendLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @WeekendLeaveId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS WeekendLeaveHasViolated
		,ignored.IsIgnoredWeekendLeave AS WeekendLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS WeekendLeaveHasApprovedBy
		,@SevenDaysLeaveId AS SevenDaysLeaveId
		,dis.IsSevenDaysLeave AS SevenDaysLeaveValue
		,dbo.fncGetDisciplineScoreById(@SevenDaysLeaveId) AS SevenDaysLeaveScore
		,(CASE 
			WHEN dis.IsSevenDaysLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.GroupId = emp.GroupId
						AND drule.DisciplineTypeId = @SevenDaysLeaveId
						AND drule.Value = 1
						AND drule.IsLocal = empSum.IsLocal
					) THEN 1
			ELSE 0 END
			) AS SevenDaysLeaveHasViolated
		,ignored.IsIgnoredSevenDaysLeave AS SevenDaysLeaveHasIgnored
		,(CASE 
			WHEN @HasEditDisciplineRole = 1
				AND dbo.fncCheckPermissionIgnoreDisciplineInReport(@ApproverId, gr.GroupId, emp.EmpId) = 1 THEN 1
			ELSE 0 END
			) AS SevenDaysLeaveHasApprovedBy
		,dis.EmployeeComment
		,dis.ApproverComment
		,dis.IsOutOfControlReason
	FROM dbo.Discipline AS dis WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON dis.EmpId = emp.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.EmployeeSummary AS empSum WITH (NOLOCK) ON emp.EmpId = empSum.EmpId
		INNER JOIN dbo.DisciplineIgnore AS ignored WITH (NOLOCK) ON dis.EmpId = ignored.EmpId
		AND dis.WorkDate = ignored.WorkDate
	WHERE emp.[Enabled] = 1
		AND emp.IsDeleted = 0
		AND dis.IsDeleted = 0
		AND dis.WorkDate BETWEEN @FromDate
			AND @ToDate
		AND (@EmployeeId IS NULL OR emp.EmpId = @EmployeeId)
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
		AND (
			@ReasonId IS NULL
			OR (
				@ReasonId = @ChangeShiftId
				AND dis.IsChangeShift = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @ChangeShiftId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @MissingCheckInOutId
				AND dis.IsMissingCheckInOut = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @MissingCheckInOutId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @LateInId
				AND dis.IsLateIn = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @LateInId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @EarlyOutId
				AND dis.IsEarlyOut = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @EarlyOutId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @AbsentId
				AND dis.IsAbsent = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @AbsentId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @UnplannedLeaveId
				AND dis.IsUnplannedLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @UnplannedLeaveId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @UnpaidLeaveId
				AND dis.IsUnpaidLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @UnpaidLeaveId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @WorkingUnderTimeId
				AND dis.IsWorkingUndertime = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @WorkingUnderTimeId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @UnpaidLeaveAbsentId
				AND dis.IsUnpaidLeaveAbsent = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @UnpaidLeaveAbsentId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @WeekendLeaveId
				AND dis.IsWeekendLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @WeekendLeaveId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			OR (
				@ReasonId = @SevenDaysLeaveId
				AND dis.IsSevenDaysLeave = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
					WHERE drule.DisciplineTypeId = @SevenDaysLeaveId
						AND drule.Value = 1
						AND drule.GroupId = emp.GroupId
						AND drule.IsLocal = empSum.IsLocal
					)
				)
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
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
					AND empS.EmpId = emp.EmpId
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
					AND emp.EmpId <> @ApproverId
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType = 8
							AND ISNULL(empS.IsDeleted, 0) = 0
						)
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = emp.EmpId
					AND empS.ActionType IN (2, 3)
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE emp.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType IN (2, 3)
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = emp.EmpId
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
				AND emp.EmpId = @ApproverId
				)
			)
		AND (
			@IsLocal IS NULL
			OR empSum.IsLocal = @IsLocal
			)
		AND (
			@HasIgnored IS NULL
			OR (
				@HasIgnored = 1
				AND (
					(
						dis.IsChangeShift = 1
						AND ignored.IsIgnoredChangeShift = 1
						)
					OR (
						dis.IsMissingCheckInOut = 1
						AND ignored.IsIgnoredMissingCheckInOut = 1
						)
					OR (
						dis.IsLateIn = 1
						AND ignored.IsIgnoredLateIn = 1
						)
					OR (
						dis.IsEarlyOut = 1
						AND ignored.IsIgnoredEarlyOut = 1
						)
					OR (
						dis.IsAbsent = 1
						AND ignored.IsIgnoredAbsent = 1
						)
					OR (
						dis.IsUnplannedLeave = 1
						AND ignored.IsIgnoredUnplannedLeave = 1
						)
					OR (
						dis.IsUnpaidLeave = 1
						AND ignored.IsIgnoredUnpaidLeave = 1
						)
					OR (
						dis.IsWorkingUnderTime = 1
						AND ignored.IsIgnoredWorkingUndertime = 1
						)
					OR (
						dis.IsUnpaidLeaveAbsent = 1
						AND ignored.IsIgnoredUnpaidLeaveAbsent = 1
						)
					OR (
						dis.IsWeekendLeave = 1
						AND ignored.IsIgnoredWeekendLeave = 1
						)
					OR (
						dis.IsSevenDaysLeave = 1
						AND ignored.IsIgnoredSevenDaysLeave = 1
						)
					)
				)
			OR (
				@HasIgnored = 0
				AND (
					(
						dis.IsChangeShift = 1
						AND ignored.IsIgnoredChangeShift = 0
						)
					OR (
						dis.IsMissingCheckInOut = 1
						AND ignored.IsIgnoredMissingCheckInOut = 0
						)
					OR (
						dis.IsLateIn = 1
						AND ignored.IsIgnoredLateIn = 0
						)
					OR (
						dis.IsEarlyOut = 1
						AND ignored.IsIgnoredEarlyOut = 0
						)
					OR (
						dis.IsAbsent = 1
						AND ignored.IsIgnoredAbsent = 0
						)
					OR (
						dis.IsUnplannedLeave = 1
						AND ignored.IsIgnoredUnplannedLeave = 0
						)
					OR (
						dis.IsUnpaidLeave = 1
						AND ignored.IsIgnoredUnpaidLeave = 0
						)
					OR (
						dis.IsWorkingUnderTime = 1
						AND ignored.IsIgnoredWorkingUndertime = 0
						)
					OR (
						dis.IsUnpaidLeaveAbsent = 1
						AND ignored.IsIgnoredUnpaidLeaveAbsent = 0
						)
					OR (
						dis.IsWeekendLeave = 1
						AND ignored.IsIgnoredWeekendLeave = 0
						)
					OR (
						dis.IsSevenDaysLeave = 1
						AND ignored.IsIgnoredSevenDaysLeave = 0
						)
					)
				)
			)
	ORDER BY dis.WorkDate DESC

	SELECT emp.EmpId AS EmployeeId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,empsum.IsLocal
		,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,shift.Code AS ShiftName
		,empatt.InFixed AS CheckIn
		,empatt.OutFixed AS CheckOut
		,empatt.LateIn
		,empatt.EarlyOut
		,empatt.TotalWorkHours AS TotalHours
		,dis.*
	FROM #tblDisciplineDetail AS dis WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON dis.EmployeeId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON dis.EmployeeId = empatt.EmpId
		AND dis.WorkDate = empatt.AttendanceDate
		LEFT JOIN dbo.[Shift] AS shift WITH (NOLOCK) ON empatt.ShiftId = shift.ShiftId
	ORDER BY dis.WorkDate DESC

	SELECT did.EmpId AS EmployeeId
		,e.NickName AS IgnoreBy
		,did.WorkDate
		,did.DisciplineTypeId
		,did.IgnoreDate
	FROM dbo.DisciplineIgnoreDetail AS did WITH (NOLOCK)
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = did.IgnoreBy
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
	WHERE did.EmpId = @EmployeeId AND did.WorkDate BETWEEN @FromDate AND @ToDate
		AND ce.CompanyId = @CompanyId

	DROP TABLE #tblDisciplineDetail

	DROP TABLE #tblGroupIds
END