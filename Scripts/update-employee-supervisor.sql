USE [bodb_HRM]
GO
/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[fnc_GetEmployeeByActorId] (
	@EmpId INT = NULL
	,@ExcludeUserDelete INT = 1
	,@IsShowUserInTeam BIT = 1
	,@CompanyId INT
	)
RETURNS TABLE
/*
	Created: Quinn.Vo@20151203
	Task: Get employee Id by actor id
	DB: HRM
	Original:

	Revisions:
		Henry.Dinh@2025-04-24: Merge action type 2, 3, 4, 5
	Param's Explanation:

*/
AS
RETURN WITH cteEmployee AS (
		SELECT e.EmpId
		FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId
		WHERE (
				(
					@ExcludeUserDelete = 1
					AND e.isDeleted = 0
					AND e.[Enabled] = 1
					)
				OR @ExcludeUserDelete = 0
				)
			AND (
				@EmpId IS NULL
				OR EXISTS (
					SELECT e1.EmpId
					FROM dbo.Employee AS e1 WITH (NOLOCK)
						INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON e1.EmpId = er.EmployeeId
						AND er.RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
					WHERE e1.EmpId = @EmpId
					)
				)
		
		UNION
		SELECT es.EmpId
		FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON es.EmpId = e.EmpId
			INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId
		WHERE es.OwnerId = @EmpId
			AND (
				(
					@ExcludeUserDelete = 1
					AND e.isDeleted = 0
					AND e.[Enabled] = 1
					)
				OR @ExcludeUserDelete = 0
				)
			AND es.IsDeleted = 0
			AND es.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
		
		UNION
		SELECT e.EmpId
		FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
			INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON gs.GroupId = e.GroupId
			INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId
		WHERE OwnerId = @EmpId
			AND (
				(
					@ExcludeUserDelete = 1
					AND e.isDeleted = 0
					AND e.[Enabled] = 1
					)
				OR @ExcludeUserDelete = 0
				)
			AND gs.IsDeleted = 0
			AND gs.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
				WHERE es.EmpId = e.EmpId
					AND es.ActionType = gs.ActionType
					AND es.IsDeleted = 0
				)
		
		UNION
		SELECT ee.EmpId
		FROM dbo.Employee AS e WITH (NOLOCK)
			INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.GroupId = e.GroupId
			INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId AND ce.CompanyId = @CompanyId
		WHERE e.EmpId = @EmpId
			AND (
				(
					@ExcludeUserDelete = 1
					AND ee.isDeleted = 0
					AND ee.[Enabled] = 1
					)
				OR @ExcludeUserDelete = 0
				)
			AND @IsShowUserInTeam = 1

		UNION
		SELECT @EmpId
		)

SELECT EmpId
FROM cteEmployee

GO

/****** Object:  StoredProcedure [dbo].[EmployeeSupervisor_Get]    Script Date: 4/24/2025 4:10:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeSupervisor_Get] @EmployeeId INT = NULL
	,@ActionType TINYINT = NULL
	,@TeamIds NVARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
AS
/*
	Created: 20140717@Quinn.Vo
	Task: Get list supervisors.
	DB: SMS-HRM
	Original: 

	Revisions:  
		Henry.Dinh@2025-04-24: Remove section and 		Henry.Dinh@2025-04-24: Merge action type 2, 3, 4, 5
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tblGroup (GroupId INT)

	CREATE TABLE #tblEmployeeSupervisor (EmpId INT)

	CREATE TABLE #tblEmployee (
		EmpId INT
		,OwnerId INT
		,ActionType TINYINT
		)

	IF ISNULL( @TeamIds, '') <> ''
	BEGIN		
		INSERT INTO #tblGroup (GroupId)
		SELECT val
		FROM fnc_strSplit( @TeamIds, ',')
	END

	INSERT INTO #tblEmployee (
		EmpId
		,OwnerId
		,ActionType
		)
	SELECT DISTINCT su.EmpId
		,su.OwnerId
		,su.ActionType
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS [owner] WITH (NOLOCK) ON su.OwnerId = [owner].EmpId
		AND ISNULL([owner].isDeleted, 0) = 0
		AND [owner].[Enabled] = 1
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON su.EmpId = emp.EmpId
		AND ISNULL(emp.isDeleted, 0) = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN #tblGroup AS tblgr WITH (NOLOCK) ON gr.GroupId = tblgr.GroupId
	WHERE ISNULL(su.IsDeleted, 0) = 0
		AND su.ActionType IN (2, 3, 4, 5, 8)
		AND (
			@ActionType IS NULL
			OR su.ActionType = @ActionType
			)
		AND ISNULL(@EmployeeId, emp.EmpId) = emp.EmpId
		AND ISNULL(@IsLocal, es.IsLocal) = es.IsLocal
		AND (
			 -- ISNULL( @TeamIds, '') = '' OR 
			tblgr.GroupId IS NOT NULL
			)

	INSERT INTO #tblEmployeeSupervisor(EmpId)
	SELECT DISTINCT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.EmployeeSupervisor AS su WITH (NOLOCK) ON e.EmpId = su.EmpId
		LEFT JOIN #tblGroup AS tblgr WITH (NOLOCK) ON e.GroupId = tblgr.GroupId
	WHERE (
			@ActionType IS NULL
			OR su.ActionType = @ActionType
			)
		AND ISNULL(@EmployeeId, e.EmpId) = e.EmpId
		AND ISNULL(@IsLocal, es.IsLocal) = es.IsLocal
		AND (
			--ISNULL( @TeamIds, '') = '' OR
			tblgr.GroupId IS NOT NULL
			)
		AND e.[Enabled] = 1
		AND ISNULL(e.IsDeleted, 0) = 0
		AND ISNULL(su.IsDeleted, 0) = 0
	ORDER BY e.EmpId

	SELECT DISTINCT e.EmpId
		,e.Code
		,e.NickName
		,e.FullName
		,dep.[Name] AS Department
		,g.GroupId AS TeamId
		,g.Code
		,g.[Name]
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN #tblEmployeeSupervisor AS esu WITH (NOLOCK) ON esu.EmpId = e.EmpId
		LEFT JOIN #tblGroup AS tblgr WITH (NOLOCK) ON g.GroupId = tblgr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
	WHERE ISNULL(e.isDeleted, 0) = 0
		AND ISNULL(e.[Enabled], 1) = 1
		AND ISNULL(@EmployeeId, e.EmpId) = e.EmpId
		AND ISNULL(@IsLocal, es.IsLocal) = es.IsLocal
		AND (
			--ISNULL( @TeamIds, '') = '' OR
			tblgr.GroupId IS NOT NULL
			)
	ORDER BY e.Code

	SELECT DISTINCT emRo.EmployeeId
		,emRo.RoleId
		,loDa.Code
		,loDa.[Name]
	FROM dbo.EmployeeRole AS emRo WITH (NOLOCK)
		INNER JOIN dbo.LookupData AS loDa WITH (NOLOCK) ON emRo.RoleId = loDa.Value
		INNER JOIN dbo.[Lookup] AS look WITH (NOLOCK) ON look.Id = loDa.LookupId
		AND look.Code = 'SR' -- System Role
		INNER JOIN #tblEmployeeSupervisor AS e WITH (NOLOCK) ON e.EmpId = emRo.EmployeeId;

	SELECT DISTINCT su.OwnerId
		,e.NickName
		,e.FullName
		,su.ActionType
		,su.EmpId
		,e1.NickName
		,e1.FullName
		,e1.Code
	FROM #tblEmployee AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.OwnerId = e.EmpId
		AND ISNULL(e.isDeleted, 0) = 0
		AND e.[Enabled] = 1
		INNER JOIN dbo.Employee AS e1 WITH (NOLOCK) ON su.EmpId = e1.EmpId
		AND ISNULL(e1.isDeleted, 0) = 0
		AND e1.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e1.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON e1.GroupId = gr.GroupId
	ORDER BY e1.Code
		,e.NickName
		,su.ActionType

	DROP TABLE #tblEmployee

	DROP TABLE #tblGroup
	
	DROP TABLE #tblEmployeeSupervisor
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetMemberByManager] @supervisorId INT
	,@excludedManager BIT
	,@query NVARCHAR(100)
	,@CompanyId SMALLINT
AS
/*
	Created: Quinn.Vo@20160129
	Task: Get list of employees by manager
	DB: HRM
	Original: 

	Revisions:
		Henry.Dinh@2025-04-24: 		Henry.Dinh@2025-04-24: Merge action type 2, 3, 4, 5
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SET @query = @query + '%'

	CREATE TABLE #tblEmployeeIds (EmpId INT PRIMARY KEY)

	--INSERT INTO #tblEmployeeIds (EmpId)
	--SELECT DISTINCT EmpId
	--FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 1)

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
	WHERE EXISTS (
			SELECT 1
			FROM dbo.EmployeeRole AS erole WITH (NOLOCK)
			WHERE erole.EmployeeId = @supervisorId
				AND erole.RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
			)
	
	UNION
	SELECT es.EmpId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON es.EmpId = emp.EmpId
	WHERE es.OwnerId = @supervisorId
		AND es.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
		AND es.IsDeleted = 0
	
	UNION
	SELECT e.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON gs.GroupId = e.GroupId
	WHERE gs.OwnerId = @supervisorId
		AND gs.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
		AND gs.IsDeleted = 0
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			WHERE es.EmpId = e.EmpId
				AND es.ActionType = gs.ActionType
				AND es.IsDeleted = 0
			)
	
	UNION
	SELECT ee.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.GroupId = emp.GroupId
	WHERE emp.EmpId = @supervisorId
	
	UNION
	SELECT @supervisorId

	SELECT e.EmpId
		,e.NickName
		,e.FullName
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON e.EmpId = tblemp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) ON c.EmpId = e.EmpId
	WHERE (
			e.NickName LIKE @query
			OR e.FullName LIKE @query
			)
		AND e.[Enabled] = 1
		AND e.isDeleted = 0
		AND c.CompanyId = @CompanyId

	DROP TABLE #tblEmployeeIds
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ScheduleArrangement_GetWeekly] @ActorId INT
	,@fromtime DATE
	,@totime DATE
	,@EmpId INT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsIFrame BIT = 0
	,@isLocal BIT = NULL
	,@CompanyId SMALLINT
    ,@IsEditScheduleUnlimited BIT = 0
AS
/*
	Created: Tim.Trinh@2019-04-12
	Task: Get weekly schedules
	DB: HRM

	Revisions:
		Henry.Dinh@2025-04-24: Merge action type 2, 3, 4, 5
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATE = GETDATE()
		,@EmployeeIds VARCHAR(MAX)
		,@ShiftManagerRoleId TINYINT = 4
		,@GeneralLeaveId TINYINT = 0
		,@OffDayShiftId SMALLINT = - 1
		-- request status
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7
	DECLARE @tblGroupIds TABLE (GroupId INT)
	DECLARE @tblDefaultShift TABLE (
		EmployeeId INT
		,ShiftId INT
		)
	CREATE TABLE #tblEmployeeIds (EmpId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO @tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT EmpId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
	WHERE OwnerId = @ActorId  
		AND (
			@EmpId IS NULL
			OR es.EmpId = @EmpId
			)
		AND ActionType = @ShiftManagerRoleId
		AND ISNULL(IsDeleted, 0) = 0
		AND EXISTS (
			SELECT 1
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN @tblGroupIds AS gr ON emp.GroupId = gr.GroupId
			WHERE emp.[Enabled] = 1
				AND emp.isDeleted = 0
				AND es.EmpId = emp.EmpId
			)

	INSERT INTO #tblEmployeeIds (EmpId)
	SELECT emp.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON gs.GroupId = emp.GroupId
	WHERE gs.OwnerId = @ActorId
		AND gs.ActionType = @ShiftManagerRoleId
		AND ISNULL(gs.IsDeleted, 0) = 0
		AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
		AND (
			@EmpId IS NULL
			OR emp.EmpId = @EmpId
			)
		AND EXISTS (
			SELECT 1
			FROM @tblGroupIds AS gr
			WHERE emp.GroupId = gr.GroupId
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblEmployeeIds AS tbl WITH (NOLOCK)
			WHERE tbl.EmpId = emp.EmpId
			)

	IF @IsIFrame = 1
		OR @IsEditScheduleUnlimited = 1
	BEGIN
		INSERT INTO #tblEmployeeIds (EmpId)
		SELECT EmpId
		FROM dbo.Employee AS emp WITH (NOLOCK)
		WHERE [Enabled] = 1
			AND isDeleted = 0
			AND (
				@EmpId IS NULL
				OR emp.EmpId = @EmpId
				)
			AND EXISTS (
				SELECT 1
				FROM @tblGroupIds AS gr
				WHERE emp.GroupId = gr.GroupId
				)
			AND NOT EXISTS (
				SELECT 1
				FROM #tblEmployeeIds AS tbl WITH (NOLOCK)
				WHERE emp.EmpId = tbl.EmpId
				)
	END

	DELETE emp
	FROM #tblEmployeeIds AS emp
	WHERE EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS esum WITH (NOLOCK)
			WHERE emp.EmpId = esum.EmpId
				AND esum.IsTopManager = 1
			)

	SELECT @EmployeeIds = COALESCE(@EmployeeIds + ',', '') + CAST(EmpId AS VARCHAR(10))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId 
		,@fromDate = @fromtime
		,@toDate = @totime
		,@empIds = @EmployeeIds
		,@isEnable = 1
		,@isDelete = 0

	SELECT emp.EmpId
		,tmpca.WorkDate
		,tmpca.ShiftId
		,tmpca.IsOvertime
		,tmpca.IsOffDay
		,tmpca.IsHoliday
		,tmpca.IsKeepInView
		,tmpca.IsLeaveOffDay
		,tmpca.IsLeaveDay
		,tmpca.LeaveTypeId
		,tmpca.FromTime
		,tmpca.ToTime
		,tmpca.LeaveTypeId2
		,tmpca.LeaveDay
		,empca.IsFixedOffDay
		,empca.IsPublic
		,empca.ModifiedBy
		,empca.ModifiedDate
		,(CASE 
			WHEN offrep.EmployeeId IS NOT NULL THEN 1
			ELSE 0 END
			) AS IsOffDayReplacement
		,tmpca.ChangeShiftTypeId
		,tmpca.MoveOffFromDate
		,tmpca.MoveOffToDate
	INTO #tblEmployeeCalendar
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.tmpEmployeeCalendar AS tmpca WITH (NOLOCK) ON emp.EmpId = tmpca.EmpId
		AND tmpca.WorkDate BETWEEN @fromTime
			AND @toTime
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		AND tmpca.WorkDate = empca.WorkDate
		LEFT JOIN dbo.ScheduleArrangementOffDayReplacement AS offrep WITH (NOLOCK) ON emp.EmpId = offrep.EmployeeId
		AND tmpca.WorkDate = offrep.WorkDate
	WHERE @IsIFrame = 0
		OR (
			@IsIFrame = 1
			AND ISNULL(empca.IsPublic, 0) = 1
			)

	IF @IsIFrame = 1
	BEGIN
		DELETE emp
		FROM #tblEmployeeIds AS emp WITH (NOLOCK)
		WHERE NOT EXISTS (
				SELECT 1
				FROM #tblEmployeeCalendar AS empca WITH (NOLOCK)
				WHERE emp.EmpId = empca.EmpId
				)
	END

	INSERT INTO @tblDefaultShift (
		EmployeeId
		,ShiftId
		)
	SELECT emp.EmpId
		,defaultshift.ShiftId
	FROM #tblEmployeeIds AS emp WITH (NOLOCK)
		INNER JOIN dbo.ScheduleArrangementDefaultShift AS defaultshift WITH (NOLOCK) ON emp.EmpId = defaultshift.EmployeeId
	WHERE defaultshift.FromDate = @fromtime

	INSERT INTO @tblDefaultShift (
		EmployeeId
		,ShiftId
		)
	SELECT data.EmployeeId
		,defaultshift.ShiftId
	FROM (
		SELECT EmployeeId
			,MAX(FromDate) AS FromDate
		FROM dbo.ScheduleArrangementDefaultShift WITH (NOLOCK)
		WHERE FromDate < @fromtime
		GROUP BY EmployeeId
		) data
		INNER JOIN dbo.ScheduleArrangementDefaultShift AS defaultshift WITH (NOLOCK) ON data.EmployeeId = defaultshift.EmployeeId
		AND data.FromDate = defaultshift.FromDate
	WHERE NOT EXISTS (
			SELECT 1
			FROM @tblDefaultShift AS tbl
			WHERE defaultshift.EmployeeId = tbl.EmployeeId
			)

	SELECT emp.EmpId AS EmployeeId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,ISNULL(esum.OffDaysbyWeek, 0) AS OffDaysbyWeek
		,emp.PickupRemark
		,arrange.Remark
		,arrange.DisplayOrder
		,esum.IsDefaultSchedule AS IsUsedWeeklyDefaultShift
		,modifier.NickName AS Modifier
		,ec.ModifiedDate
		,gr.GroupId AS TeamId
		,gr.Code
		,gr.[Name]
		,[shift].ShiftId AS DefaultShiftId
		,[shift].Code
		,[shift].[Name]
		,[shift].BeginCheckInTime AS CheckIn
		,[shift].BeginCheckOutTime AS CheckOut
		,[shift].IsInAfterDay
		,[shift].IsOutAfterDay
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		LEFT JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON emp.EmpId = esum.EmpId
		LEFT JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN dbo.ScheduleArrangement AS arrange WITH (NOLOCK) ON emp.EmpId = arrange.EmployeeId
		LEFT JOIN dbo.ScheduleArrangementGroupOrder AS gorder WITH (NOLOCK) ON gr.GroupId = gorder.GroupId
		LEFT JOIN @tblDefaultShift AS defaultshift ON emp.EmpId = defaultshift.EmployeeId
		LEFT JOIN dbo.[Shift] AS [shift] WITH (NOLOCK) ON defaultshift.ShiftId = [shift].ShiftId
		AND ISNULL([shift].IsDisabled, 0) = 0
		OUTER APPLY (
		SELECT TOP 1 ec.ModifiedBy
			,ec.ModifiedDate
		FROM #tblEmployeeCalendar AS ec
		WHERE ec.EmpId = emp.EmpId
			AND ec.ModifiedBy IS NOT NULL
			AND ec.ModifiedDate IS NOT NULL
			AND ec.ModifiedDate = (
				SELECT MAX(ec1.ModifiedDate)
				FROM #tblEmployeeCalendar AS ec1 WITH (NOLOCK)
				WHERE ec.EmpId = ec1.EmpId
				)
		) AS ec
		LEFT JOIN dbo.Employee AS modifier WITH (NOLOCK) ON ec.ModifiedBy = modifier.EmpId
	WHERE EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tblgr
			WHERE emp.GroupId = tblgr.GroupId
			)
			AND (
			@isLocal IS NULL
			OR esum.IsLocal = @isLocal
			)
	ORDER BY ISNULL(gorder.DisplayOrder, 0)
		,gr.Code
		,ISNULL(arrange.DisplayOrder, 0)
		,emp.NickName

	SELECT emp.EmpId AS EmployeeId
		,empca.WorkDate
		,empca.IsOvertime
		,empca.IsLeaveOffDay
		,empca.ChangeShiftTypeId
		,empca.MoveOffFromDate
		,empca.MoveOffToDate
		,empca.IsHoliday
		,empca.IsOffDay
		,empca.IsFixedOffDay
		,empca.IsLeaveDay
		,empca.IsKeepInView
		,empca.LeaveDay
		,empca.IsPublic
		,empca.IsOffDayReplacement
		,(CASE 
			WHEN empca.ModifiedBy IS NOT NULL OR empca.IsPublic = 1 THEN 1
			WHEN @fromTime <= @Today THEN 1
			ELSE 0 END
			) AS IsModified
		,[shift].ShiftId
		,[shift].Code
		,[shift].[Name]
		,[shift].BeginCheckInTime AS CheckIn
		,[shift].BeginCheckOutTime AS CheckOut
		,[shift].IsInAfterDay
		,[shift].IsOutAfterDay
		,lv1.LeaveTypeId
		,lv1.Code
		,lv1.[Name]
		,empca.FromTime
		,empca.ToTime
		,lv2.LeaveTypeId AS LeaveTypeId2
		,lv2.Code
		,lv2.[Name]
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS tblemp WITH (NOLOCK) ON emp.EmpId = tblemp.EmpId
		INNER JOIN #tblEmployeeCalendar AS empca ON emp.EmpId = empca.EmpId
		AND empca.WorkDate BETWEEN @fromTime
			AND @toTime
		LEFT JOIN dbo.[Shift] AS [shift] WITH (NOLOCK) ON [shift].ShiftId = empca.ShiftId
		LEFT JOIN dbo.LeaveType AS lv1 WITH (NOLOCK) ON empca.LeaveTypeId = lv1.LeaveTypeId
        AND lv1.CompanyId = @CompanyId
		LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON empca.LeaveTypeId2 = lv2.LeaveTypeId
        AND lv2.CompanyId = @CompanyId
	WHERE EXISTS (
			SELECT 1
			FROM @tblGroupIds AS tblgr
			WHERE emp.GroupId = tblgr.GroupId
			)
	ORDER BY emp.NickName
		,empca.WorkDate

	SELECT emp.EmpId AS EmployeeId
		,ISNULL(monshift.ShiftId, @OffDayShiftId) AS MonShiftId
		,ISNULL(tueshift.ShiftId, @OffDayShiftId) AS TueShiftId
		,ISNULL(wedshift.ShiftId, @OffDayShiftId) AS WedShiftId
		,ISNULL(thushift.ShiftId, @OffDayShiftId) AS ThuShiftId
		,ISNULL(frishift.ShiftId, @OffDayShiftId) AS FriShiftId
		,ISNULL(satshift.ShiftId, @OffDayShiftId) AS SatShiftId
		,ISNULL(sunshift.ShiftId, @OffDayShiftId) AS SunShiftId
	FROM #tblEmployeeIds AS emp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
		LEFT JOIN dbo.EmployeeDefaultShift AS eds WITH (NOLOCK) ON eds.EmpId = emp.EmpId
		LEFT JOIN dbo.[Shift] AS monshift WITH (NOLOCK) ON eds.MonShift = monshift.ShiftId
		AND ISNULL(monshift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS tueshift WITH (NOLOCK) ON eds.TueShift = tueshift.ShiftId
		AND ISNULL(tueshift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS wedshift WITH (NOLOCK) ON eds.WedShift = wedshift.ShiftId
		AND ISNULL(wedshift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS thushift WITH (NOLOCK) ON eds.ThuShift = thushift.ShiftId
		AND ISNULL(thushift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS frishift WITH (NOLOCK) ON eds.FriShift = frishift.ShiftId
		AND ISNULL(frishift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS satshift WITH (NOLOCK) ON eds.SatShift = satshift.ShiftId
		AND ISNULL(satshift.IsDisabled, 0) = 0
		LEFT JOIN dbo.[Shift] AS sunshift WITH (NOLOCK) ON eds.SunShift = sunshift.ShiftId
		AND ISNULL(sunshift.IsDisabled, 0) = 0
	WHERE ce.CompanyId = @CompanyId

	DROP TABLE #tblEmployeeIds
	DROP TABLE #tblEmployeeCalendar
END