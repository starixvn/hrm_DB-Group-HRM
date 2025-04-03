/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_DisciplineSummaryPerYear] @CompanyId SMALLINT
    ,@FromDate DATE
	,@ToDate DATE
	,@ApproverId INT
	,@TeamIds VARCHAR(MAX) = ''
	,@EmployeeId INT = NULL
	,@IsLocal BIT = NULL
	,@IsShowAll BIT = 0
AS
/*
Created: 20220720@Tim.Trinh
Task: discipline summary by year
DB: HRM
Original:

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpTeam (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	CREATE TABLE #tmpEmployeeDiscipline (
		WorkDate DATE
		,EmpId INT
		,ApproverSubtractScore FLOAT
		,OtherDisciplineScore DECIMAL(5, 2)
		)

	INSERT INTO #tmpEmployeeDiscipline (
		EmpId
		,WorkDate
		,ApproverSubtractScore
		,OtherDisciplineScore
		)
	SELECT emp.EmpId
		,ISNULL(dis.WorkDate, otherdis.WorkDate)
		,CASE 
			WHEN dis.EmpId IS NOT NULL THEN (CASE 
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
			ELSE 0
			END
		,CASE 
			WHEN otherdis.EmpId IS NOT NULL THEN otherdis.Score
			ELSE 0
			END
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
        INNER JOIN dbo.EmployeeSummary AS empSum WITH (NOLOCK) ON emp.EmpId = empSum.EmpId AND empSum.IsTopManager = 0
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		AND gr.IsDeleted = 0
		LEFT JOIN dbo.Discipline AS dis WITH (NOLOCK) ON dis.EmpId = emp.EmpId
		AND dis.IsDeleted = 0
		AND dis.WorkDate BETWEEN @FromDate
			AND @ToDate
		LEFT JOIN dbo.DisciplineIgnore AS ignored WITH (NOLOCK) ON dis.EmpId = ignored.EmpId
		AND dis.WorkDate = ignored.WorkDate
		LEFT JOIN dbo.OtherDiscipline AS otherdis WITH (NOLOCK) ON otherdis.EmpId = emp.EmpId
		AND otherdis.IsDeleted = 0
		AND otherdis.WorkDate BETWEEN @FromDate
			AND @ToDate
		AND dis.WorkDate = otherdis.WorkDate
	WHERE ce.CompanyId = @CompanyId
        AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		AND (
			dis.EmpId IS NOT NULL
			OR otherdis.EmpId IS NOT NULL
			)
		AND EXISTS (
			SELECT 1
			FROM #tmpTeam AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (
			@EmployeeId IS NULL
			OR emp.EmpId = @EmployeeId
			)
		AND (
			@IsLocal IS NULL
			OR empSum.IsLocal = @IsLocal
			)

	DECLARE @Is_HR_SA BIT
	DECLARE @tblRole TABLE (RoleId INT)

	INSERT INTO @tblRole (RoleId)
	SELECT RoleId
	FROM dbo.EmployeeRole WITH (NOLOCK)
	WHERE EmployeeId = @ApproverId

	SET @Is_HR_SA = CASE 
			WHEN EXISTS (
					SELECT 1
					FROM @tblRole
					WHERE RoleId IN (6, 7) -- HR, SA
					) THEN 1
			ELSE 0
			END

	DELETE
	FROM #tmpEmployeeDiscipline WITH (ROWLOCK, UPDLOCK)
	WHERE ApproverSubtractScore = 0
		AND OtherDisciplineScore = 0

	SELECT emp.EmpId AS EmployeeId
		,emp.NickName
		,emp.FullName
		,emp.Code
		,emp.JoinedDate
		,empsum.CompanyDate
		,empsum.IsLocal
		,empsum.MilitaryFromDate
		,empsum.MilitaryToDate
		,gr.[Name] AS Team
		,s.[Name] AS Section
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		AND gr.IsDeleted = 0
		INNER JOIN dbo.Section AS s WITH (NOLOCK) ON gr.SectionId = s.SectionId
		AND s.IsDeleted = 0
	WHERE ce.CompanyId = @CompanyId
        AND emp.[Enabled] = 1
		AND emp.IsDeleted = 0
		AND EXISTS (
			SELECT 1
			FROM #tmpTeam AS tbl WITH (NOLOCK)
			WHERE emp.GroupId = tbl.GroupId
			)
		AND (
			@EmployeeId IS NULL
			OR emp.EmpId = @EmployeeId
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND (
			@IsShowAll = 1
			OR (
				@IsShowAll = 0
				AND EXISTS (
					SELECT 1
					FROM #tmpEmployeeDiscipline WITH (NOLOCK)
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
					AND emp.EmpId != @ApproverId
					AND ISNULL(grS.IsDeleted, 0) = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId != @ApproverId
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
						WHERE empS.OwnerId != @ApproverId
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
	ORDER BY gr.[Name] ASC

	SELECT dis.EmpId AS EmployeeId
		,YEAR(dis.WorkDate) AS [Year]
		,SUM(dis.OtherDisciplineScore + dis.ApproverSubtractScore) AS ApproverSubtractScore
	FROM #tmpEmployeeDiscipline AS dis WITH (NOLOCK)
	GROUP BY dis.EmpId
		,YEAR(dis.WorkDate)
	ORDER BY dis.EmpId
		,YEAR(dis.WorkDate)

	DROP TABLE #tmpEmployeeDiscipline

	DROP TABLE #tmpTeam
END