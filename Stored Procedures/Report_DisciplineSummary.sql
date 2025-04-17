/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_DisciplineSummary] @FromDate DATE
	,@ToDate DATE
	,@ApproverId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@ReasonId INT = NULL
	,@IsLocal BIT = NULL
	,@IsShowAll BIT = 0
	,@CompanyId SMALLINT
    ,@RoleIds VARCHAR(1000) = ''
AS
/*
Created: 20191204@Tim.Trinh
Task: get discipline summary
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

	CREATE TABLE #tblEmployeeDiscipline (
		WorkDate DATE
		,EmpId INT
		,ChangeShift INT
		,MissingCheckInOut INT
		,LateIn INT
		,EarlyOut INT
		,[Absent] INT
		,UnplannedLeave INT
		,WeekendLeave INT
		,UnpaidLeave INT
		,WorkingUnderTime INT
		,UnpaidLeaveAbsent INT
		,SevenDaysLeave INT
		,VerbalWarning INT
		,WrittenWarning INT
		,OtherDiscipline INT
		,OtherDisciplineScore DECIMAL(5, 2)
		)

	INSERT INTO #tblEmployeeDiscipline (
		WorkDate
		,EmpId
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
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 1 -- change shift
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsChangeShift
			ELSE 0 END
			) AS ChangeShift
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 2 -- missing check in / out
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsMissingCheckInOut
			ELSE 0 END
			) AS MissingCheckInOut
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 3 -- late in
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsLateIn
			ELSE 0 END
			) AS LateIn
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 4 -- early out
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsEarlyOut
			ELSE 0 END
			) AS EarlyOut
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 5 -- absent
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsAbsent
			ELSE 0 END
			) AS [Absent]
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 9 -- unplanned leave
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsUnplannedLeave
			ELSE 0 END
			) AS UnplannedLeave
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 10 -- weekend leave
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsWeekendLeave
			ELSE 0 END
			) AS WeekendLeave
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 6 -- unpaid leave
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsUnpaidLeave
			ELSE 0 END
			) AS UnpaidLeave
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 7 -- working under time
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsWorkingUndertime
			ELSE 0 END
			) AS WorkingUnderTime
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 8 -- unpaid leave absent
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsUnpaidLeaveAbsent
			ELSE 0 END
			) AS UnpaidLeaveAbsent
		,(CASE (
				SELECT drule.[Value]
				FROM dbo.DisciplineGroupRule AS drule WITH (NOLOCK)
				WHERE drule.DisciplineTypeId = 11 -- seven days leave
					AND drule.GroupId = emp.GroupId
					AND drule.IsLocal = empSum.IsLocal
				)
			WHEN 1 THEN d.IsSevenDaysLeave
			ELSE 0 END
			) AS SevenDaysLeave
		,0 AS VerbalWarning
		,0 AS WrittenWarning
		,0 AS OtherDiscipline
		,0 AS OtherDisciplineScore
	FROM dbo.Discipline AS d WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON d.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
	WHERE d.WorkDate BETWEEN @FromDate
			AND @ToDate
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
        AND d.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR emp.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)
	
	UNION ALL
	SELECT dis.WorkDate
		,dis.EmpId
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
		,(CASE 
			WHEN dis.DisciplineTypeId = - 1 THEN 1
			ELSE 0 END
			) AS VerbalWarning
		,(CASE 
			WHEN dis.DisciplineTypeId = - 2 THEN 1
			ELSE 0 END
			) AS WrittenWarning
		,(CASE 
			WHEN dis.DisciplineTypeId = - 3 THEN 1
			ELSE 0 END
			) AS OtherDiscipline
		,dis.Score AS OtherDisciplineScore
	FROM dbo.OtherDiscipline AS dis WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON dis.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
	WHERE dis.WorkDate BETWEEN @FromDate
			AND @ToDate
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
        AND dis.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR emp.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)

	CREATE TABLE #tblEmployeeDisciplineFinalScore (
		WorkDate DATE
		,EmpId INT
		,SystemSubtractScore FLOAT
		,ApproverSubtractScore FLOAT
		)

	INSERT INTO #tblEmployeeDisciplineFinalScore (
		WorkDate
		,EmpId
		,SystemSubtractScore
		,ApproverSubtractScore
		)
	SELECT tbldis.WorkDate
		,tbldis.EmpId
		,(tbldis.ChangeShift * dbo.fncGetDisciplineScoreById(1)
		  + tbldis.MissingCheckInOut * dbo.fncGetDisciplineScoreById(2)
		  + tbldis.LateIn * dbo.fncGetDisciplineScoreById(3)
		  + tbldis.EarlyOut * dbo.fncGetDisciplineScoreById(4)
		  + tbldis.[Absent] * dbo.fncGetDisciplineScoreById(5)
		  + tbldis.UnpaidLeave * dbo.fncGetDisciplineScoreById(6)
		  + tbldis.WorkingUnderTime * dbo.fncGetDisciplineScoreById(7)
		  + tbldis.UnpaidLeaveAbsent * dbo.fncGetDisciplineScoreById(8)
		  + tbldis.UnplannedLeave * dbo.fncGetDisciplineScoreById(9)
		  + tbldis.WeekendLeave * dbo.fncGetDisciplineScoreById(10)
		  + tbldis.SevenDaysLeave * dbo.fncGetDisciplineScoreById(11)) AS SystemSubtractScore
		,CASE 
			WHEN ignored.ApproverSubtractScore IS NOT NULL THEN ignored.ApproverSubtractScore
			ELSE 0
			END
	FROM #tblEmployeeDiscipline AS tbldis WITH (NOLOCK)
		OUTER APPLY (
		SELECT dis.EmpId
			,dis.WorkDate
			,(
				(CASE 
					WHEN dis.IsChangeShift = 1
						AND ignored.IsIgnoredChangeShift = 0 THEN dbo.fncGetDisciplineScoreById(1)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsMissingCheckInOut = 1
						AND ignored.IsIgnoredMissingCheckInOut = 0 THEN dbo.fncGetDisciplineScoreById(2)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsLateIn = 1
						AND ignored.IsIgnoredLateIn = 0 THEN dbo.fncGetDisciplineScoreById(3)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsEarlyOut = 1
						AND ignored.IsIgnoredEarlyOut = 0 THEN dbo.fncGetDisciplineScoreById(4)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsAbsent = 1
						AND ignored.IsIgnoredAbsent = 0 THEN dbo.fncGetDisciplineScoreById(5)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnplannedLeave = 1
						AND ignored.IsIgnoredUnplannedLeave = 0 THEN dbo.fncGetDisciplineScoreById(9)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnpaidLeave = 1
						AND ignored.IsIgnoredUnpaidLeave = 0 THEN dbo.fncGetDisciplineScoreById(6)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsWorkingUndertime = 1
						AND ignored.IsIgnoredWorkingUndertime = 0 THEN dbo.fncGetDisciplineScoreById(7)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsUnpaidLeaveAbsent = 1
						AND ignored.IsIgnoredUnpaidLeaveAbsent = 0 THEN dbo.fncGetDisciplineScoreById(8)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsWeekendLeave = 1
						AND ignored.IsIgnoredWeekendLeave = 0 THEN dbo.fncGetDisciplineScoreById(10)
					ELSE 0 END
					) + (CASE 
					WHEN dis.IsSevenDaysLeave = 1
						AND ignored.IsIgnoredSevenDaysLeave = 0 THEN dbo.fncGetDisciplineScoreById(11)
					ELSE 0 END
					)
				) AS ApproverSubtractScore
		FROM dbo.Discipline AS dis WITH (NOLOCK)
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
	DECLARE @tblRole TABLE (RoleId INT)

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
							-- AND emp.EmpId <> @ApproverId
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
					) THEN 2 -- Host
			ELSE 1 END
			)
		,emp.EmpId AS EmployeeId
		,emp.NickName
		,emp.FullName
		,emp.Code
		,empSum.IsLocal
		,gr.GroupId AS TeamId
		,gr.[Name] AS TeamName
		,gr.Code AS TeamCode
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN #tblEmployeeDiscipline AS empD WITH (NOLOCK) ON emp.EmpId = empD.EmpId
		LEFT JOIN #tblEmployeeDisciplineFinalScore AS empF WITH (NOLOCK) ON empF.WorkDate = empD.WorkDate
		AND empF.EmpId = empD.EmpId
	WHERE emp.[Enabled] = 1
		AND emp.IsDeleted = 0
		AND ce.CompanyId = @CompanyId
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (@EmployeeId IS NULL OR emp.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR empsum.IsLocal = @IsLocal)
		AND (
			@IsShowAll = 1
			OR (
				@IsShowAll = 0
				AND EXISTS (
					SELECT 1
					FROM #tblEmployeeDiscipline WITH (NOLOCK)
					WHERE emp.EmpId = EmpId
					)
				)
			)
		AND (
			@Is_HR_SA = 1 -- SA, HR can view all member of company
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
							AND ISNULL(emps.IsDeleted, 0) = 0
						)
				)
			OR EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ApproverId
					AND empS.EmpId = emp.EmpId
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
							AND empS.EmpId = emp.EmpId
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
				AND emp.EmpId = @ApproverId
				)
			)
		AND (
			ISNULL(@ReasonId, '') = ''
			OR (
				@ReasonId = 1
				AND empD.ChangeShift > 0
				)
			OR (
				@ReasonId = 2
				AND empD.MissingCheckInOut > 0
				)
			OR (
				@ReasonId = 3
				AND empD.LateIn > 0
				)
			OR (
				@ReasonId = 4
				AND empD.EarlyOut > 0
				)
			OR (
				@ReasonId = 5
				AND empD.[Absent] > 0
				)
			OR (
				@ReasonId = 9
				AND empD.UnplannedLeave > 0
				)
			OR (
				@ReasonId = 10
				AND empD.WeekendLeave > 0
				)
			OR (
				@ReasonId = 6
				AND empD.UnpaidLeave > 0
				)
			OR (
				@ReasonId = 7
				AND empD.WorkingUnderTime > 0
				)
			OR (
				@ReasonId = 8
				AND empD.UnpaidLeaveAbsent > 0
				)
			OR (
				@ReasonId = 11
				AND empD.SevenDaysLeave > 0
				)
			OR (
				@ReasonId = - 1
				AND empD.VerbalWarning > 0
				)
			OR (
				@ReasonId = - 2
				AND empD.WrittenWarning > 0
				)
			OR (
				@ReasonId = - 3
				AND empD.OtherDiscipline > 0
				)
			)
	GROUP BY empD.EmpId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,emp.Code
		,empSum.IsLocal
		,gr.GroupId
		,gr.[Name]
		,gr.Code
	ORDER BY Permission DESC
		,gr.[Name] ASC
		,emp.Code ASC

	DROP TABLE #tblEmployeeDiscipline

	DROP TABLE #tblEmployeeDisciplineFinalScore

	DROP TABLE #tblGroupIds
END