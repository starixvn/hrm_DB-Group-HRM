/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Overtime_GetMemberMonthlyRequest] @ActorId INT
	,@EmployeeId INT = NULL
	,@TeamIds VARCHAR(MAX) = NULL
	,@Month DATE = NULL
	,@StatusIds VARCHAR(MAX) = NULL
	,@IsProcessor BIT = 0
	,@OvertimeType SMALLINT = NULL
	,@IsLocal BIT = NULL
	,@CompanyId INT 
AS
/*
Created: Tim.Trinh@2019-07-05
Task: Get member overtime request
DB: HRM

Revisions:
    20250403@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	-- request status
	DECLARE @PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7
	-- overtime type
		,@ALLOvertimeType TINYINT = 0
		,@NormalDay TINYINT = 1
		,@OffDay TINYINT = 2
		,@PublicHoliday TINYINT = 3
		,@SpecialOT TINYINT = 4

	DECLARE @tblStatusIds TABLE (StatusId TINYINT)

	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	CREATE TABLE #tblGroupIds (GroupId INT)

	CREATE TABLE #tblOvertimeType (RequestId INT)

	INSERT INTO #tblOvertimeType (RequestId)
	SELECT otmr.RequestId
	FROM dbo.OTMonthlyRequest AS otmr WITH (NOLOCK)
	WHERE @OvertimeType = @ALLOvertimeType
		OR (@OvertimeType = @NormalDay AND otmr.NormalHours > 0)
		OR (@OvertimeType = @OffDay AND otmr.OffHours > 0)
		OR (@OvertimeType = @PublicHoliday AND otmr.PublicHours > 0)
		OR (@OvertimeType = @SpecialOT AND otmr.SpecialHours > 0)

	IF @EmployeeId IS NULL
	BEGIN
		IF @IsProcessor = 1
		BEGIN
			INSERT INTO #tblEmployeeIds (EmployeeId)
			SELECT emp.EmpId
			FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON emp.EmpId = c.EmpId
			WHERE emp.[Enabled] = 1
				AND emp.isDeleted = 0
				AND c.CompanyId = @CompanyId
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeIds (EmployeeId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 1, 0, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeIds (EmployeeId)
		VALUES (@EmployeeId)
	END

	INSERT INTO @tblStatusIds (StatusId)
	SELECT value
	FROM STRING_SPLIT(@StatusIds, ',')

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END
	
	SELECT req.RequestId
		,req.[Month]
		,req.NormalHours
		,req.OffHours
		,req.PublicHours
		,req.SpecialHours
		,(CASE 
			WHEN att.RequestId IS NOT NULL THEN 1
			ELSE 0 END
			) IsWarning
		,(CASE 
			WHEN (
					@IsProcessor = 0
					AND req.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @NotVerifiedStatusId, @ApprovedStatusId, @RejectedStatusId)
					AND (
						verifier.EmpId = @ActorId
						OR approver.EmpId = @ActorId
						)
					)
				OR @IsProcessor = 1 THEN 1
			ELSE 0 END
			) AS IsHost
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,verifier.EmpId AS VerifierId
		,verifier.NickName AS VerifierNickname
		,verifier.FullName AS VerifierFullName
		,approver.EmpId AS ApproverId
		,approver.NickName AS ApproverNickname
		,approver.FullName AS ApproverFullName
		,req.CurrentStatus AS StatusId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
	FROM dbo.OTMonthlyRequest AS req WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds e WITH (NOLOCK) ON req.EmpId = e.EmployeeId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON req.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN #tblGroupIds AS tblgr WITH (NOLOCK) ON gr.GroupId = tblgr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = req.VerifierId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = req.ApproverId
		LEFT JOIN (
		SELECT DISTINCT ot.RequestId
		FROM dbo.OTDailyRequest AS ot WITH (NOLOCK)
			LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON ot.Schedule = s.ShiftId
			LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON empatt.AttendanceDate = ot.OvertimeDate
			AND empatt.EmpId = ot.EmpId
		WHERE ot.TotalHours - ISNULL(empatt.LateIn, 0) / 60 >= s.TotalHours + 1
		) AS att ON att.RequestId = req.RequestId
	WHERE emp.[Enabled] = 1
		AND emp.isDeleted = 0
        AND (
			@Month IS NULL
			OR req.[Month] = @Month
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND EXISTS (
			SELECT 1
			FROM @tblStatusIds AS tbl
			WHERE req.CurrentStatus = tbl.StatusId
			)
		AND EXISTS (
			SELECT 1
			FROM #tblOvertimeType AS ovt
			WHERE req.RequestId = ovt.RequestId
			)
	ORDER BY IsHost DESC
		,StatusId
		,req.[Month] DESC
		,emp.NickName

	DROP TABLE #tblEmployeeIds

	DROP TABLE #tblGroupIds

	DROP TABLE #tblOvertimeType
END