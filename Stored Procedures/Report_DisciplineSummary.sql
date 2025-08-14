/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_DisciplineSummary]
(
    @CompanyId SMALLINT
    ,@FromDate DATE
    ,@ToDate DATE
    ,@ApproverId INT
    ,@TeamIds VARCHAR(MAX) = ''
    ,@EmployeeId INT = NULL
    ,@ReasonId INT = NULL
    ,@IsLocal BIT = NULL
    ,@IsShowAll BIT = 0
    ,@RoleIds VARCHAR(1000) = ''
)
AS
/*
    Created: 20191204@Tim.Trinh
    Task: get discipline summary
    DB: bodb_HRM

    Revisions:
        20250404@Tim: add param @RoleIds [Redmine: #222886]
        20250627@Tim: fix bug rule ignored
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
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

	CREATE TABLE #tmpGroupIds (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	CREATE TABLE #tmpEmployeeDiscipline (
		WorkDate DATE
		,EmpId INT
        ,GroupId INT
        ,IsLocal BIT
		,ChangeShift TINYINT
		,MissingCheckInOut TINYINT
		,LateIn TINYINT
		,EarlyOut TINYINT
		,[Absent] TINYINT
		,UnplannedLeave TINYINT
		,WeekendLeave TINYINT
		,UnpaidLeave TINYINT
		,WorkingUnderTime TINYINT
		,UnpaidLeaveAbsent TINYINT
		,SevenDaysLeave TINYINT
		,VerbalWarning TINYINT
		,WrittenWarning TINYINT
		,OtherDiscipline TINYINT
		,OtherDisciplineScore DECIMAL(5, 2)
		)

	INSERT INTO #tmpEmployeeDiscipline (
		WorkDate
		,EmpId
        ,GroupId
        ,IsLocal
		,ChangeShift
		,MissingCheckInOut
		,LateIn
		,EarlyOut
		,[Absent]
		,UnplannedLeave
		,WeekendLeave
		,UnpaidLeave
		,WorkingUnderTime
		,UnpaidLeaveAbsent
		,SevenDaysLeave
		,VerbalWarning
		,WrittenWarning
		,OtherDiscipline
		,OtherDisciplineScore
		)
	SELECT d.WorkDate
		,d.EmpId
        ,ce.GroupId
        ,empsum.IsLocal
		,d.IsChangeShift
		,d.IsMissingCheckInOut
		,d.IsLateIn
		,d.IsEarlyOut
		,d.IsAbsent
		,d.IsUnplannedLeave
		,d.IsWeekendLeave
		,d.IsUnpaidLeave
		,d.IsWorkingUndertime
		,d.IsUnpaidLeaveAbsent
		,d.IsSevenDaysLeave
		,0 AS VerbalWarning
		,0 AS WrittenWarning
		,0 AS OtherDiscipline
		,0 AS OtherDisciplineScore
	FROM dbo.Discipline AS d WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON d.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
	WHERE ce.CompanyId = @CompanyId
        AND d.WorkDate BETWEEN @FromDate AND @ToDate
		AND ce.isDeleted = 0
		AND ce.[Enabled] = 1
        AND d.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tmpGroupIds AS tbl
			WHERE ce.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR ce.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)
	
	UNION ALL
	SELECT dis.WorkDate
		,dis.EmpId
        ,ce.GroupId
        ,empsum.IsLocal
		,0 AS ChangeShift
		,0 AS MissingCheckInOut
		,0 AS LateIn
		,0 AS EarlyOut
		,0 AS [Absent]
		,0 AS UnplannedLeave
		,0 AS WeekendLeave
		,0 AS UnpaidLeave
		,0 AS WorkingUnderTime
		,0 AS UnpaidLeaveAbsent
		,0 AS SevenDaysLeave
		,(CASE WHEN dis.DisciplineTypeId = -1 THEN 1 ELSE 0 END) AS VerbalWarning
		,(CASE WHEN dis.DisciplineTypeId = -2 THEN 1 ELSE 0 END) AS WrittenWarning
		,(CASE WHEN dis.DisciplineTypeId = -3 THEN 1 ELSE 0 END) AS OtherDiscipline
		,dis.Score AS OtherDisciplineScore
	FROM dbo.OtherDiscipline AS dis WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON dis.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
	WHERE ce.CompanyId = @CompanyId
        AND dis.WorkDate BETWEEN @FromDate AND @ToDate
		AND ce.isDeleted = 0
		AND ce.[Enabled] = 1
        AND dis.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tmpGroupIds AS tbl
			WHERE ce.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR ce.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)

    UPDATE tmpdis
    SET tmpdis.ChangeShift = CASE WHEN drule.DisciplineTypeId = @ChangeShiftId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.ChangeShift END
        ,tmpdis.MissingCheckInOut = CASE WHEN drule.DisciplineTypeId = @MissingCheckInOutId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.MissingCheckInOut END
        ,tmpdis.LateIn = CASE WHEN drule.DisciplineTypeId = @LateInId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.LateIn END
        ,tmpdis.EarlyOut = CASE WHEN drule.DisciplineTypeId = @EarlyOutId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.EarlyOut END
        ,tmpdis.[Absent] = CASE WHEN drule.DisciplineTypeId = @AbsentId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.[Absent] END
        ,tmpdis.UnplannedLeave = CASE WHEN drule.DisciplineTypeId = @UnplannedLeaveId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.UnplannedLeave END
        ,tmpdis.UnpaidLeave = CASE WHEN drule.DisciplineTypeId = @UnpaidLeaveId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.UnpaidLeave END
        ,tmpdis.WorkingUnderTime = CASE WHEN drule.DisciplineTypeId = @WorkingUnderTimeId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.WorkingUnderTime END
        ,tmpdis.UnpaidLeaveAbsent = CASE WHEN drule.DisciplineTypeId = @UnpaidLeaveAbsentId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.UnpaidLeaveAbsent END
        ,tmpdis.WeekendLeave = CASE WHEN drule.DisciplineTypeId = @WeekendLeaveId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.WeekendLeave END
        ,tmpdis.SevenDaysLeave = CASE WHEN drule.DisciplineTypeId = @SevenDaysLeaveId AND ISNULL(drule.Value, 0) = 0 THEN 0 ELSE tmpdis.SevenDaysLeave END
    FROM #tmpEmployeeDiscipline AS tmpdis
        LEFT JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON tmpdis.GroupId = drule.GroupId
        AND drule.IsLocal = tmpdis.IsLocal

	CREATE TABLE #tmpEmployeeDisciplineFinalScore (
		WorkDate DATE
		,EmpId INT
		,SystemSubtractScore FLOAT
		,ApproverSubtractScore FLOAT
		)

	INSERT INTO #tmpEmployeeDisciplineFinalScore (
		WorkDate
		,EmpId
		,SystemSubtractScore
		,ApproverSubtractScore
		)
	SELECT tbldis.WorkDate
		,tbldis.EmpId
		,(
            tbldis.ChangeShift * dbo.fncGetDisciplineScoreById(1)
		    + tbldis.MissingCheckInOut * dbo.fncGetDisciplineScoreById(2)
		    + tbldis.LateIn * dbo.fncGetDisciplineScoreById(3)
		    + tbldis.EarlyOut * dbo.fncGetDisciplineScoreById(4)
		    + tbldis.[Absent] * dbo.fncGetDisciplineScoreById(5)
		    + tbldis.UnpaidLeave * dbo.fncGetDisciplineScoreById(6)
		    + tbldis.WorkingUnderTime * dbo.fncGetDisciplineScoreById(7)
		    + tbldis.UnpaidLeaveAbsent * dbo.fncGetDisciplineScoreById(8)
		    + tbldis.UnplannedLeave * dbo.fncGetDisciplineScoreById(9)
		    + tbldis.WeekendLeave * dbo.fncGetDisciplineScoreById(10)
		    + tbldis.SevenDaysLeave * dbo.fncGetDisciplineScoreById(11)
        ) AS SystemSubtractScore
		,CASE WHEN ignored.ApproverSubtractScore IS NOT NULL THEN ignored.ApproverSubtractScore ELSE 0 END
	FROM #tmpEmployeeDiscipline AS tbldis WITH (NOLOCK)
		OUTER APPLY (
		SELECT dis.EmpId
			,dis.WorkDate
			,(
				CASE WHEN dis.ChangeShift = 1 AND ignored.IsIgnoredChangeShift = 0 THEN dbo.fncGetDisciplineScoreById(1) ELSE 0 END
				+ CASE WHEN dis.MissingCheckInOut = 1 AND ignored.IsIgnoredMissingCheckInOut = 0 THEN dbo.fncGetDisciplineScoreById(2) ELSE 0 END
                + CASE WHEN dis.LateIn = 1 AND ignored.IsIgnoredLateIn = 0 THEN dbo.fncGetDisciplineScoreById(3) ELSE 0 END
				+ CASE WHEN dis.EarlyOut = 1 AND ignored.IsIgnoredEarlyOut = 0 THEN dbo.fncGetDisciplineScoreById(4) ELSE 0 END
				+ CASE WHEN dis.[Absent] = 1 AND ignored.IsIgnoredAbsent = 0 THEN dbo.fncGetDisciplineScoreById(5) ELSE 0 END
				+ CASE WHEN dis.UnplannedLeave = 1 AND ignored.IsIgnoredUnplannedLeave = 0 THEN dbo.fncGetDisciplineScoreById(9) ELSE 0 END
				+ CASE WHEN dis.UnpaidLeave = 1 AND ignored.IsIgnoredUnpaidLeave = 0 THEN dbo.fncGetDisciplineScoreById(6) ELSE 0 END
				+ CASE WHEN dis.WorkingUndertime = 1 AND ignored.IsIgnoredWorkingUndertime = 0 THEN dbo.fncGetDisciplineScoreById(7) ELSE 0 END
				+ CASE WHEN dis.UnpaidLeaveAbsent = 1 AND ignored.IsIgnoredUnpaidLeaveAbsent = 0 THEN dbo.fncGetDisciplineScoreById(8) ELSE 0 END
				+ CASE WHEN dis.WeekendLeave = 1 AND ignored.IsIgnoredWeekendLeave = 0 THEN dbo.fncGetDisciplineScoreById(10) ELSE 0 END
				+ CASE WHEN dis.SevenDaysLeave = 1 AND ignored.IsIgnoredSevenDaysLeave = 0 THEN dbo.fncGetDisciplineScoreById(11) ELSE 0 END
			) AS ApproverSubtractScore
		FROM #tmpEmployeeDiscipline AS dis
			INNER JOIN dbo.DisciplineIgnore AS ignored WITH (NOLOCK) ON dis.EmpId = ignored.EmpId
			AND dis.WorkDate = ignored.WorkDate
		WHERE ignored.EmpId = tbldis.EmpId
			AND ignored.WorkDate = tbldis.WorkDate
		) AS ignored
	WHERE (
			tbldis.[Absent] > 0
			OR tbldis.UnplannedLeave > 0
			OR tbldis.WeekendLeave > 0
			OR tbldis.ChangeShift > 0
			OR tbldis.EarlyOut > 0
			OR tbldis.LateIn > 0
			OR tbldis.UnpaidLeave > 0
			OR tbldis.WorkingUnderTime > 0
			OR tbldis.UnpaidLeaveAbsent > 0
			OR tbldis.MissingCheckInOut > 0
			OR tbldis.SevenDaysLeave > 0
			)
		AND tbldis.OtherDisciplineScore = 0

	DECLARE @Is_HR_SA BIT
	DECLARE @tblRole TABLE (RoleId SMALLINT)

	INSERT INTO @tblRole (RoleId)
	SELECT value
	FROM STRING_SPLIT(@RoleIds, ',')

	SET @Is_HR_SA = CASE 
			WHEN EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
					) THEN 1
			ELSE 0
			END

	SELECT SUM(ISNULL(empD.ChangeShift, 0)) AS ChangeShift
		,SUM(ISNULL(empD.MissingCheckInOut, 0)) AS MissingCheckInOut
		,SUM(ISNULL(empD.LateIn, 0)) AS LateIn
		,SUM(ISNULL(empD.EarlyOut, 0)) AS EarlyOut
		,SUM(ISNULL(empD.[Absent], 0)) AS [Absent]
		,SUM(ISNULL(empD.UnplannedLeave, 0)) AS UnplannedLeave
		,SUM(ISNULL(empD.WeekendLeave, 0)) AS WeekendLeave
		,SUM(ISNULL(empD.UnpaidLeave, 0)) AS UnpaidLeave
		,SUM(ISNULL(empD.WorkingUnderTime, 0)) AS WorkingUnderTime
		,SUM(ISNULL(empD.UnpaidLeaveAbsent, 0)) AS UnpaidLeaveAbsent
		,SUM(ISNULL(empD.SevenDaysLeave, 0)) AS SevenDaysLeave
		,SUM(ISNULL(empD.OtherDisciplineScore, 0)) AS OtherDisciplineScore
		,SUM(ISNULL(empD.OtherDisciplineScore, 0) + ISNULL(empF.SystemSubtractScore, 0)) AS SystemSubtractScore
		,SUM(ISNULL(empD.OtherDisciplineScore, 0) + ISNULL(empF.ApproverSubtractScore, 0)) AS ApproverSubtractScore
		,Permission = (CASE 
			WHEN EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId = 8 -- edit discipline
					)
				AND (
					EXISTS (
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
							-- AND emp.EmpId <> @ApproverId
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
					) THEN 2 -- Host
			ELSE 1 END
			)
		,ce.EmpId AS EmployeeId
		,ce.NickName
		,e.FullName
		,ce.Code
		,empSum.IsLocal
		,gr.GroupId AS TeamId
		,gr.[Name] AS TeamName
		,gr.Code AS TeamCode
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		LEFT JOIN #tmpEmployeeDiscipline AS empD ON ce.EmpId = empD.EmpId
		LEFT JOIN #tmpEmployeeDisciplineFinalScore AS empF ON empF.WorkDate = empD.WorkDate
		AND empF.EmpId = empD.EmpId
	WHERE ce.[Enabled] = 1
		AND ce.IsDeleted = 0
		AND ce.CompanyId = @CompanyId
		AND EXISTS (
			SELECT 1
			FROM #tmpGroupIds AS tmpgr
			WHERE ce.GroupId = tmpgr.GroupId
			)
		AND (@EmployeeId IS NULL OR ce.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)
		AND (
			@IsShowAll = 1
			OR (
				@IsShowAll = 0
				AND EXISTS (
					SELECT 1
					FROM #tmpEmployeeDiscipline AS tmpd
					WHERE ce.EmpId = tmpd.EmpId
					)
				)
			)
		AND (
			@Is_HR_SA = 1 -- SA, HR can view all member of company
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
							AND ISNULL(emps.IsDeleted, 0) = 0
						)
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = ce.EmpId
					AND empS.ActionType IN (2, 3) -- Approver and Verifier
					AND ISNULL(empS.IsDeleted, 0) = 0
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE gr.GroupId = grS.GroupId
					AND @ApproverId = grS.OwnerId
					AND grS.ActionType IN (2, 3) -- Approver and Verifier
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ApproverId
							AND empS.EmpId = ce.EmpId
							AND empS.ActionType IN (2, 3)
							AND ISNULL(emps.IsDeleted, 0) = 0
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
			@ReasonId IS NULL
			OR (@ReasonId = @ChangeShiftId AND empD.ChangeShift > 0)
			OR (@ReasonId = @MissingCheckInOutId AND empD.MissingCheckInOut > 0)
			OR (@ReasonId = @LateInId AND empD.LateIn > 0)
			OR (@ReasonId = @EarlyOutId AND empD.EarlyOut > 0)
			OR (@ReasonId = @AbsentId AND empD.[Absent] > 0)
			OR (@ReasonId = @UnplannedLeaveId AND empD.UnplannedLeave > 0)
			OR (@ReasonId = @WeekendLeaveId AND empD.WeekendLeave > 0)
			OR (@ReasonId = @UnpaidLeaveId AND empD.UnpaidLeave > 0)
			OR (@ReasonId = @WorkingUnderTimeId AND empD.WorkingUnderTime > 0)
			OR (@ReasonId = @UnpaidLeaveAbsentId AND empD.UnpaidLeaveAbsent > 0)
			OR (@ReasonId = @SevenDaysLeaveId AND empD.SevenDaysLeave > 0)
			OR (@ReasonId = -1 AND empD.VerbalWarning > 0)
			OR (@ReasonId = -2 AND empD.WrittenWarning > 0)
			OR (@ReasonId = -3 AND empD.OtherDiscipline > 0)
			)
	GROUP BY empD.EmpId
		,ce.EmpId
		,ce.NickName
		,e.FullName
		,ce.Code
		,empSum.IsLocal
		,gr.GroupId
		,gr.[Name]
		,gr.Code
	ORDER BY Permission DESC
		,gr.[Name] ASC
		,ce.Code ASC

	DROP TABLE #tmpEmployeeDiscipline

	DROP TABLE #tmpEmployeeDisciplineFinalScore

	DROP TABLE #tmpGroupIds
END