/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SyncEPA_DisciplineSummary] @LastModifiedDate DATETIME
	,@CompanyId INT
AS
/*
Created: 20171031@Tim.Trinh
Task: sync discipline to EPA
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblDisciplineSummary (
		EmployeeId INT
		,WorkDate DATE
		,ChangeShift DECIMAL(5, 2)
		,MissingCheckInOut DECIMAL(5, 2)
		,LateIn DECIMAL(5, 2)
		,EarlyOut DECIMAL(5, 2)
		,[Absent] DECIMAL(5, 2)
		,UnpaidLeave DECIMAL(5, 2)
		,WorkingUndertime DECIMAL(5, 2)
		,UnpaidLeaveAbsent DECIMAL(5, 2)
		,UnplannedLeave DECIMAL(5, 2)
		,WeekendLeave DECIMAL(5, 2)
		,SevenDaysLeave DECIMAL(5, 2)
		,OtherDisciplines DECIMAL(5, 2)
		,SystemSubtractScore DECIMAL(5, 2)
		,ModifiedDate DATETIME
		,IsDeleted BIT
		)

	CREATE TABLE #tblDisciplineSummaryResult (
		EmployeeId INT
		,WorkDate DATE
		,ChangeShift DECIMAL(5, 2)
		,MissingCheckInOut DECIMAL(5, 2)
		,LateIn DECIMAL(5, 2)
		,EarlyOut DECIMAL(5, 2)
		,[Absent] DECIMAL(5, 2)
		,UnpaidLeave DECIMAL(5, 2)
		,WorkingUndertime DECIMAL(5, 2)
		,UnpaidLeaveAbsent DECIMAL(5, 2)
		,UnplannedLeave DECIMAL(5, 2)
		,WeekendLeave DECIMAL(5, 2)
		,SevenDaysLeave DECIMAL(5, 2)
		,OtherDisciplines DECIMAL(5, 2)
		,SystemSubtractScore DECIMAL(5, 2)
		,ModifiedDate DATETIME
		,IsDeleted BIT
		)

	INSERT INTO #tblDisciplineSummary (
		EmployeeId
		,WorkDate
		,ChangeShift
		,MissingCheckInOut
		,LateIn
		,EarlyOut
		,[Absent]
		,UnpaidLeave
		,WorkingUndertime
		,UnpaidLeaveAbsent
		,UnplannedLeave
		,WeekendLeave
		,SevenDaysLeave
		,OtherDisciplines
		,SystemSubtractScore
		,ModifiedDate
		,IsDeleted
		)
	SELECT CASE WHEN emp.OldEmpId IS NOT NULL THEN emp.OldEmpId ELSE d.EmpId END AS EmpId
		,WorkDate
		,0 AS ChangeShift
		,0 AS MissingCheckInOut
		,0 AS LateIn
		,0 AS EarlyOut
		,0 AS [Absent]
		,0 AS UnpaidLeave
		,0 AS WorkingUndertime
		,0 AS UnpaidLeaveAbsent
		,0 AS UnplannedLeave
		,0 AS WeekendLeave
		,0 AS SevenDaysLeave
		,0 AS OtherDisciplines
		,0 AS SystemSubtractScore
		,MAX(d.ModifiedDate) AS ModifiedDate
		,1
	FROM dbo.Discipline AS d WITH (NOLOCK)
	INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON d.EmpId = emp.EmpId
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId AND ce.CompanyId = @CompanyId
	WHERE d.ModifiedDate > @LastModifiedDate
		AND d.IsDeleted = 1
	GROUP BY d.EmpId
		,emp.OldEmpId
		,WorkDate
	
	INSERT INTO #tblDisciplineSummary (
		EmployeeId
		,WorkDate
		,ChangeShift
		,MissingCheckInOut
		,LateIn
		,EarlyOut
		,[Absent]
		,UnpaidLeave
		,WorkingUndertime
		,UnpaidLeaveAbsent
		,UnplannedLeave
		,WeekendLeave
		,SevenDaysLeave
		,OtherDisciplines
		,SystemSubtractScore
		,ModifiedDate
		,IsDeleted
		)
	SELECT CASE WHEN emp.OldEmpId IS NOT NULL THEN emp.OldEmpId ELSE d.EmpId END AS EmpId
		,d.WorkDate
		,SUM(CASE 
				WHEN d.IsChangeShift = 1
					AND ignore.IsIgnoredChangeShift = 0
					AND cs.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(1)
				ELSE 0
				END) AS ChangeShift
		,SUM(CASE 
				WHEN d.IsMissingCheckInOut = 1
					AND ignore.IsIgnoredMissingCheckInOut = 0
					AND mio.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(2)
				ELSE 0
				END) AS MissingCheckInOut
		,SUM(CASE 
				WHEN d.IsLateIn = 1
					AND ignore.IsIgnoredLateIn = 0
					AND li.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(3)
				ELSE 0
				END) AS LateIn
		,SUM(CASE 
				WHEN d.IsEarlyOut = 1
					AND ignore.IsIgnoredEarlyOut = 0
					AND eo.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(4)
				ELSE 0
				END) AS EarlyOut
		,SUM(CASE 
				WHEN d.IsAbsent = 1
					AND ignore.IsIgnoredAbsent = 0
					AND ab.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(5)
				ELSE 0
				END) AS [Absent]
		,SUM(CASE 
				WHEN d.IsUnpaidLeave = 1
					AND ignore.IsIgnoredUnpaidLeave = 0
					AND upl.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(6)
				ELSE 0
				END) AS UnpaidLeave
		,SUM(CASE 
				WHEN d.IsWorkingUnderTime = 1
					AND ignore.IsIgnoredWorkingUnderTime = 0
					AND wut.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(7)
				ELSE 0
				END) AS WorkingUndertime
		,SUM(CASE 
				WHEN d.IsUnpaidLeaveAbsent = 1
					AND ignore.IsIgnoredUnpaidLeaveAbsent = 0
					AND upla.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(8)
				ELSE 0
				END) AS UnpaidLeaveAbsent
		,SUM(CASE 
				WHEN d.IsUnplannedLeave = 1
					AND ignore.IsIgnoredUnplannedLeave = 0
					AND unplanned.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(9)
				ELSE 0
				END) AS UnplannedLeave
		,SUM(CASE 
				WHEN d.IsWeekendLeave = 1
					AND ignore.IsIgnoredWeekendLeave = 0
					AND unplanned.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(10)
				ELSE 0
				END) AS WeekendLeave
		,SUM(CASE 
				WHEN d.IsSevenDaysLeave = 1
					AND ignore.IsIgnoredSevenDaysLeave = 0
					AND sevendaysleave.DisciplineTypeId IS NOT NULL THEN dbo.fncGetDisciplineScoreById(11)
				ELSE 0
				END) AS SevenDaysLeave
		,0 AS OtherDisciplines
		,SUM(CASE 
				WHEN d.IsChangeShift = 1 THEN dbo.fncGetDisciplineScoreById(1)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsMissingCheckInOut = 1 THEN dbo.fncGetDisciplineScoreById(2)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsLateIn = 1 THEN dbo.fncGetDisciplineScoreById(3)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsEarlyOut = 1 THEN dbo.fncGetDisciplineScoreById(4)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsAbsent = 1 THEN dbo.fncGetDisciplineScoreById(5)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsUnpaidLeave = 1 THEN dbo.fncGetDisciplineScoreById(6)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsWorkingUnderTime = 1 THEN dbo.fncGetDisciplineScoreById(7)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsUnpaidLeaveAbsent = 1 THEN dbo.fncGetDisciplineScoreById(8)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsUnplannedLeave = 1 THEN dbo.fncGetDisciplineScoreById(9)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsWeekendLeave = 1 THEN dbo.fncGetDisciplineScoreById(10)
				ELSE 0
				END) + SUM(CASE 
				WHEN d.IsSevenDaysLeave = 1 THEN dbo.fncGetDisciplineScoreById(11)
				ELSE 0
				END) AS SystemSubtractScore
		,MAX(d.ModifiedDate) AS ModifiedDate
		,0 AS IsDeleted
	FROM dbo.Discipline AS d WITH (NOLOCK)
		INNER JOIN dbo.DisciplineIgnore AS ignore WITH (NOLOCK) ON d.EmpId = ignore.EmpId
		AND d.WorkDate = ignore.WorkDate
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON d.EmpId = emp.EmpId
		AND emp.[Enabled] = 1
		AND ISNULL(emp.isDeleted, 0) = 0
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId AND ce.CompanyId = @CompanyId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId AND gr.CompanyId = @CompanyId
	-- change shift
		LEFT JOIN dbo.DisciplineGroupRule AS cs WITH (NOLOCK) ON cs.DisciplineTypeId = 1
		AND cs.GroupId = emp.GroupId
		AND cs.IsLocal = es.IsLocal
		AND cs.Value = 1
	-- missing check in/out
		LEFT JOIN dbo.DisciplineGroupRule AS mio WITH (NOLOCK) ON mio.DisciplineTypeId = 2
		AND mio.GroupId = emp.GroupId
		AND mio.IsLocal = es.IsLocal
		AND mio.Value = 1
	-- late in
		LEFT JOIN dbo.DisciplineGroupRule AS li WITH (NOLOCK) ON li.DisciplineTypeId = 3
		AND li.GroupId = emp.GroupId
		AND li.IsLocal = es.IsLocal
		AND li.Value = 1
	-- early out
		LEFT JOIN dbo.DisciplineGroupRule AS eo WITH (NOLOCK) ON eo.DisciplineTypeId = 4
		AND eo.GroupId = emp.GroupId
		AND eo.IsLocal = es.IsLocal
		AND eo.Value = 1
	-- absent
		LEFT JOIN dbo.DisciplineGroupRule AS ab WITH (NOLOCK) ON ab.DisciplineTypeId = 5
		AND ab.GroupId = emp.GroupId
		AND ab.IsLocal = es.IsLocal
		AND ab.Value = 1
	-- unpaid leave
		LEFT JOIN dbo.DisciplineGroupRule AS upl WITH (NOLOCK) ON upl.DisciplineTypeId = 6
		AND upl.GroupId = emp.GroupId
		AND upl.IsLocal = es.IsLocal
		AND upl.Value = 1
	-- working under time
		LEFT JOIN dbo.DisciplineGroupRule AS wut WITH (NOLOCK) ON wut.DisciplineTypeId = 7
		AND wut.GroupId = emp.GroupId
		AND wut.IsLocal = es.IsLocal
		AND wut.Value = 1
	-- unpaid leave absent
		LEFT JOIN dbo.DisciplineGroupRule AS upla WITH (NOLOCK) ON upla.DisciplineTypeId = 8
		AND upla.GroupId = emp.GroupId
		AND upla.IsLocal = es.IsLocal
		AND upla.Value = 1
	-- unplanned leave
		LEFT JOIN dbo.DisciplineGroupRule AS unplanned WITH (NOLOCK) ON unplanned.DisciplineTypeId = 9
		AND unplanned.GroupId = emp.GroupId
		AND unplanned.IsLocal = es.IsLocal
		AND unplanned.Value = 1
	-- weekend leave
		LEFT JOIN dbo.DisciplineGroupRule AS weekendleave WITH (NOLOCK) ON weekendleave.DisciplineTypeId = 10
		AND weekendleave.GroupId = emp.GroupId
		AND weekendleave.IsLocal = es.IsLocal
		AND weekendleave.Value = 1
	-- seven days leave
		LEFT JOIN dbo.DisciplineGroupRule AS sevendaysleave WITH (NOLOCK) ON sevendaysleave.DisciplineTypeId = 11
		AND sevendaysleave.GroupId = emp.GroupId
		AND sevendaysleave.IsLocal = es.IsLocal
		AND sevendaysleave.Value = 1
	WHERE d.ModifiedDate > @LastModifiedDate
		AND d.IsDeleted = 0
	GROUP BY d.EmpId
		,emp.OldEmpId
		,d.WorkDate

	INSERT INTO #tblDisciplineSummary (
		EmployeeId
		,WorkDate
		,ChangeShift
		,MissingCheckInOut
		,LateIn
		,EarlyOut
		,[Absent]
		,UnpaidLeave
		,WorkingUndertime
		,UnpaidLeaveAbsent
		,UnplannedLeave
		,WeekendLeave
		,SevenDaysLeave
		,OtherDisciplines
		,SystemSubtractScore
		,ModifiedDate
		,IsDeleted
		)
	SELECT CASE WHEN emp.OldEmpId IS NOT NULL THEN emp.OldEmpId ELSE emp.EmpId END AS EmpId
		,otherdis.WorkDate
		,0 AS ChangeShift
		,0 AS MissingCheckInOut
		,0 AS LateIn
		,0 AS EarlyOut
		,0 AS [Absent]
		,0 AS UnpaidLeave
		,0 AS WorkingUndertime
		,0 AS UnpaidLeaveAbsent
		,0 AS UnplannedLeave
		,0 AS WeekendLeave
		,0 AS SevenDaysLeave
		,CASE WHEN otherdis.IsDeleted = 0 THEN otherdis.Score ELSE 0 END AS OtherDisciplines
		,0 AS SystemSubtractScore
		,otherdis.ModifiedDate
		,otherdis.IsDeleted
	FROM dbo.OtherDiscipline AS otherdis WITH (NOLOCK)
	INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON otherdis.EmpId = emp.EmpId
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId AND ce.CompanyId = @CompanyId
	WHERE otherdis.ModifiedDate > @LastModifiedDate

	INSERT INTO #tblDisciplineSummaryResult (
		EmployeeId
		,WorkDate
		,ChangeShift
		,MissingCheckInOut
		,LateIn
		,EarlyOut
		,[Absent]
		,UnpaidLeave
		,WorkingUndertime
		,UnpaidLeaveAbsent
		,UnplannedLeave
		,WeekendLeave
		,SevenDaysLeave
		,OtherDisciplines
		,SystemSubtractScore
		,ModifiedDate
		,IsDeleted
		)
	SELECT EmployeeId
		,WorkDate
		,SUM(ChangeShift) AS ChangeShift
		,SUM(MissingCheckInOut) AS MissingCheckInOut
		,SUM(LateIn) AS LateIn
		,SUM(EarlyOut) AS EarlyOut
		,SUM([Absent]) AS [Absent]
		,SUM(UnpaidLeave) AS UnpaidLeave
		,SUM(WorkingUndertime) AS WorkingUndertime
		,SUM(UnpaidLeaveAbsent) AS UnpaidLeaveAbsent
		,SUM(UnplannedLeave) AS UnplannedLeave
		,SUM(WeekendLeave) AS WeekendLeave
		,SUM(SevenDaysLeave) AS SevenDaysLeave
		,SUM(OtherDisciplines) AS OtherDisciplines
		,SUM(SystemSubtractScore) AS SystemSubtractScore
		,MAX(ModifiedDate) AS ModifiedDate
		,CAST(MIN(CAST(IsDeleted AS TINYINT)) AS BIT) AS IsDeleted
	FROM #tblDisciplineSummary WITH (NOLOCK)
	GROUP BY EmployeeId
		,WorkDate

	IF (
			SELECT COUNT(1)
			FROM #tblDisciplineSummaryResult WITH (NOLOCK)
			) > 1000
	BEGIN
		UPDATE dis
		SET dis.ModifiedDate = DATEADD(SECOND, - 1, dis.ModifiedDate)
		FROM (
			SELECT TOP 1000 *
			FROM #tblDisciplineSummaryResult WITH (NOLOCK)
			ORDER BY ModifiedDate
				,WorkDate
				,EmployeeId
			) AS d
			INNER JOIN dbo.Discipline AS dis WITH (ROWLOCK, UPDLOCK) ON d.EmployeeId = dis.EmpId
			AND d.WorkDate = dis.WorkDate

		SELECT TOP 1000 *
		FROM #tblDisciplineSummaryResult WITH (NOLOCK)
		ORDER BY ModifiedDate
			,WorkDate
			,EmployeeId
	END
	ELSE
	BEGIN
		SELECT *
		FROM #tblDisciplineSummaryResult WITH (NOLOCK)
		ORDER BY ModifiedDate
			,WorkDate
			,EmployeeId
	END

	DROP TABLE #tblDisciplineSummary

	DROP TABLE #tblDisciplineSummaryResult
END













