/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
	SELECT OwnerId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
	WHERE EmpId = @ActorId
		AND (
			@EmpId IS NULL
			OR es.OwnerId = @EmpId
			)
		AND ActionType = @ShiftManagerRoleId
		AND ISNULL(IsDeleted, 0) = 0
		AND EXISTS (
			SELECT 1
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN @tblGroupIds AS gr ON emp.GroupId = gr.GroupId
			WHERE emp.[Enabled] = 1
				AND emp.isDeleted = 0
				AND es.OwnerId = emp.EmpId
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