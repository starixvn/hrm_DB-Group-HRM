/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_MonthlyOvertime]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusIds VARCHAR(10) = ''
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
)
AS
/*
    Created: 20250307@Tim
    Task: monthly overtime
    DB: bodb_HRM

    Revisions:
        -20250403@Tim: remove section [Redmine: #222886]
        -20250417@Tim: get Unit Code [Redmine: #224530]
        -20250813@Jay: change db structure [Redmine: #235678]
        -20250919@Tim: user status filter [Redmine: #239089]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromDatetmp DATE = @FromDate
		-- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- request status
		,@VerifyStatusId TINYINT = 2
		,@ApproveStatusId TINYINT = 4
		,@ProcessStatusId TINYINT = 6
	DECLARE @tblEmployeeId TABLE (EmpId INT)
    DECLARE @tblStatus TABLE (Id TINYINT)
	DECLARE @tblDate TABLE (WorkDate DATE, IsHoliday BIT)
	DECLARE @tblGroupIds TABLE (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO @tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

    IF ISNULL(@EmployeeStatusIds, '') != ''
    BEGIN
        INSERT INTO @tblStatus (Id)
		SELECT value
		FROM STRING_SPLIT(@EmployeeStatusIds, ',')
    END

	WHILE @fromDatetmp <= @ToDate
	BEGIN
		INSERT INTO @tblDate (
			WorkDate
			,IsHoliday
			)
		VALUES (
			@fromDatetmp
			,CASE 
				WHEN EXISTS (
						SELECT 1
						FROM dbo.Holiday WITH (NOLOCK)
						WHERE CompanyId = @CompanyId
                            AND @fromDatetmp BETWEEN FromDate
								AND ToDate
						) THEN 1
				ELSE 0
				END
			)

		SET @fromDatetmp = DATEADD(DAY, 1, @fromDatetmp)
	END

	INSERT INTO @tblEmployeeId (EmpId)
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
			AND ce.IsSpecialUser = 0
		INNER JOIN @tblGroupIds AS tblgr ON ce.GroupId = tblgr.GroupId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN (
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)
		) AS [member] ON ce.EmpId = [member].EmpId
	WHERE (
			ISNULL(@EmployeeStatusIds, '') = ''
            OR EXISTS (
                SELECT 1
                FROM @tblStatus AS s
                WHERE (s.Id = @Enable AND ce.[Enabled] = 1 AND ce.isDeleted = 0)
                    OR (s.Id = @Disabled AND ce.[Enabled] = 0 AND ce.isDeleted = 0)
                    OR (s.Id = @Deleted AND ce.isDeleted = 1)
                )
			)
		AND (
			ce.NickName LIKE '%' + ISNULL(@Employee, '') + '%'
			OR e.FullName LIKE '%' + ISNULL(@Employee, '') + '%'
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)

	SELECT WorkDate AS [Date]
		,IsHoliday
	FROM @tblDate
	ORDER BY WorkDate

	SELECT ce.EmpId
		,ce.Code
		,ce.NickName
		,e.FullName
        ,ce.[Enabled]
        ,ce.IsDeleted
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
        ,u.Code AS UnitCode
		,tmp.WorkDate
		,s.ShiftId
		,s.Code AS ShiftCode
		,ot.TimeIn
		,ot.[TimeOut]
		,ot.TotalHours AS ActualWorkingHours
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.Remark
		,empca.IsHoliday
		,empca.IsOffDay
		,ot.[Status] AS StatusId
	FROM @tblDate AS tmp
		INNER JOIN dbo.OTDailyRequest AS ot WITH (NOLOCK) ON tmp.WorkDate = ot.OvertimeDate
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ot.EmpId = ce.EmpId
		INNER JOIN dbo.Employee AS e (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN @tblEmployeeId AS empid ON ce.EmpId = empid.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON ce.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId =  gr.DepartmentId
        INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON ce.EmpId = empca.EmpId
		AND ot.OvertimeDate = empca.WorkDate
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
    WHERE ot.[Status] IN (@VerifyStatusId, @ApproveStatusId, @ProcessStatusId)
	ORDER BY tmp.WorkDate
		,ce.NickName
END