/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Overtime_GetMemberMonthlyRequest] @ActorId INT
	,@EmployeeId INT = NULL
	,@TeamIds VARCHAR(MAX) = NULL
	,@Month DATE = NULL
	,@StatusIds VARCHAR(MAX) = NULL
	,@IsProcessor BIT = 0
	,@OvertimeType SMALLINT = NULL
	,@IsLocal BIT = NULL
	,@CompanyId INT 
	,@IsShowCrossCompany BIT = 0
	,@EmployeeStatusIds VARCHAR(10) = ''
AS
/*
Created: Tim.Trinh@2019-07-05
Task: Get member overtime request
DB: HRM

Revisions:
    20250403@Tim: remove section [Redmine: #222886]
	20250813@Jay: change db structure [Redmine: #235678]
	20250924@Henry: filter user status [Redmine: #239089]
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

		-- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3

	DECLARE @tblStatusIds TABLE (StatusId TINYINT)
    DECLARE @tblStatusEmpIds TABLE (Id TINYINT)

	CREATE TABLE #tblEmployeeIds (EmployeeId INT, CompanyId INT)

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


	IF ISNULL(@EmployeeStatusIds, '') != ''
    BEGIN
        INSERT INTO @tblStatusEmpIds (Id)
		SELECT value
		FROM STRING_SPLIT(@EmployeeStatusIds, ',')
    END

	IF @EmployeeId IS NULL
	BEGIN
		IF @IsProcessor = 1
		BEGIN
			INSERT INTO #tblEmployeeIds (EmployeeId)
			SELECT ce.EmpId
			FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
			WHERE (
					@EmployeeStatusIds IS NULL
					OR EXISTS (
						SELECT 1
						FROM @tblStatusEmpIds AS s
						WHERE (s.Id = @Enable AND ce.[Enabled] = 1 AND ce.isDeleted = 0)
							OR (s.Id = @Disabled AND ce.[Enabled] = 0 AND ce.isDeleted = 0)
							OR (s.Id = @Deleted AND ce.isDeleted = 1)
						)
				)
				AND ce.CompanyId = @CompanyId
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeIds (EmployeeId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId_CrossCompany(@ActorId, @EmployeeStatusIds, 0, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeIds (EmployeeId)
		VALUES (@EmployeeId)
	END

	UPDATE #tblEmployeeIds
	SET CompanyId = ce.CompanyId
	FROM #tblEmployeeIds AS eid WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = eid.EmployeeId

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
		,ce.[Enabled]
        ,ce.IsDeleted
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
						vece.EmpId = @ActorId
						OR apce.EmpId = @ActorId
						)
					)
				OR @IsProcessor = 1 THEN 1
			ELSE 0 END
			) AS IsHost
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,u.Code AS UnitCode
		,vece.EmpId AS VerifierId
		,CASE 
			WHEN vece.CompanyId <> @CompanyId THEN vece.NickName + ' (' + verifierCompany.[Name] + ')'
			ELSE vece.NickName 
		END AS VerifierNickname
		,verifier.FullName AS VerifierFullName
		,apce.EmpId AS ApproverId
		,CASE 
			WHEN apce.CompanyId <> @CompanyId THEN apce.NickName + ' (' + approverCompany.[Name] + ')'
			ELSE apce.NickName 
		END AS ApproverNickname
		,approver.FullName AS ApproverFullName
		,req.CurrentStatus AS StatusId
		,ce.EmpId
		,CASE 
			WHEN e.CompanyId <> @CompanyId THEN ce.NickName + ' (' + c.[Name] + ')'
			ELSE ce.NickName 
		END AS NickName
		,emp.FullName
	FROM dbo.OTMonthlyRequest AS req WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds e WITH (NOLOCK) ON req.EmpId = e.EmployeeId
		INNER JOIN dbo.CompanyEmployee ce (NOLOCK) ON req.EmpId = ce.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = e.CompanyId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON gr.GroupId = ce.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = dep.UnitId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = req.VerifierId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.UserId = vece.UserId
		LEFT JOIN dbo.Company AS verifierCompany WITH (NOLOCK) ON verifierCompany.CompanyId = vece.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = req.ApproverId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.UserId = apce.UserId
		LEFT JOIN dbo.Company AS approverCompany WITH (NOLOCK) ON approverCompany.CompanyId = apce.CompanyId
		LEFT JOIN (
		SELECT DISTINCT ot.RequestId
		FROM dbo.OTDailyRequest AS ot WITH (NOLOCK)
			LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON ot.Schedule = s.ShiftId
			LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON empatt.AttendanceDate = ot.OvertimeDate
			AND empatt.EmpId = ot.EmpId
		WHERE ot.TotalHours - ISNULL(empatt.LateIn, 0) / 60 >= s.TotalHours + 1
		) AS att ON att.RequestId = req.RequestId
	WHERE (
			@EmployeeStatusIds IS NULL
            OR EXISTS (
                SELECT 1
                FROM @tblStatusEmpIds AS s
                WHERE (s.Id = @Enable AND ce.[Enabled] = 1 AND ce.isDeleted = 0)
                    OR (s.Id = @Disabled AND ce.[Enabled] = 0 AND ce.isDeleted = 0)
                    OR (s.Id = @Deleted AND ce.isDeleted = 1)
                )
			)
        AND (
			@Month IS NULL
			OR req.[Month] = @Month
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
		AND (
			EXISTS (
				SELECT 1
				FROM #tblGroupIds AS tblgr WITH (NOLOCK)
				WHERE tblgr.GroupId = ce.GroupId
				)
			OR (@IsShowCrossCompany = 1 AND EXISTS (
				SELECT 1
				FROM #tblEmployeeIds AS tblemp WITH (NOLOCK)
				WHERE tblemp.EmployeeId = ce.EmpId AND tblemp.CompanyId <> @CompanyId
				AND (req.VerifierId = @ActorId OR req.ApproverId = @ActorId)
			))
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
		,ce.NickName

	DROP TABLE #tblEmployeeIds

	DROP TABLE #tblGroupIds

	DROP TABLE #tblOvertimeType
END

