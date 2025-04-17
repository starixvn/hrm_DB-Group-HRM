/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_MonthlyOvertime] @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
AS
/*
Created: 20250307@Tim
Task: monthly overtime
DB: HRM

Revisions:
    20250403@Tim: remove section [Redmine: #222886]
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
	DECLARE @tblDate TABLE (
		WorkDate DATE
		,IsHoliday BIT
		)
	DECLARE @tblGroupIds TABLE (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO @tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
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

	SELECT WorkDate AS [Date]
		,IsHoliday
	FROM @tblDate
	ORDER BY WorkDate

	INSERT INTO @tblEmployeeId (EmpId)
	SELECT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
        AND empsum.IsTopManager = 0
		INNER JOIN @tblGroupIds AS tblgr ON emp.GroupId = tblgr.GroupId
		INNER JOIN (
		SELECT EmpId
		FROM dbo.fnc_GetEmployeeByActorId(@ActorId, 0, 1, @CompanyId)
		) AS [member] ON emp.EmpId = [member].EmpId
	WHERE (
			@EmployeeStatusId IS NULL
			OR (
				@EmployeeStatusId = @Enable
				AND emp.[Enabled] = 1
				AND emp.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Disabled
				AND emp.[Enabled] = 0
				AND emp.isDeleted = 0
				)
			OR (
				@EmployeeStatusId = @Deleted
				AND emp.isDeleted = 1
				)
			)
		AND (
			emp.NickName LIKE '%' + ISNULL(@Employee, '') + '%'
			OR emp.FullName LIKE '%' + ISNULL(@Employee, '') + '%'
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)

	SELECT emp.EmpId
		,emp.Code
		,emp.NickName
		,emp.FullName
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
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
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ot.EmpId = emp.EmpId
		INNER JOIN @tblEmployeeId AS empid ON emp.EmpId = empid.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId =  gr.DepartmentId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		AND ot.OvertimeDate = empca.WorkDate
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
    WHERE ot.[Status] IN (@VerifyStatusId, @ApproveStatusId, @ProcessStatusId)
	ORDER BY tmp.WorkDate
		,emp.NickName
END