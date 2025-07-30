/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_WorkingHoursSummary]
(
    @CompanyId SMALLINT
    ,@ActorId INT
	,@FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = NULL
	,@isLocal BIT = NULL
	,@Employee NVARCHAR(200) = NULL
	,@EmployeeStatusId TINYINT = NULL
)
AS
/*
    Created: 20250307@Tim
    Task: Working Hours Summary Report
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
*/
BEGIN
	DECLARE @employeeIds VARCHAR(MAX)
		-- employee status
		,@Enable TINYINT = 1
		,@Disabled TINYINT = 2
		,@Deleted TINYINT = 3
		-- leave type
		,@AnnualLeaveTypeId SMALLINT = 2
		,@UnpaidLeaveTypeId SMALLINT = 25
		,@UnpaidLeaveInsuranceTypeId SMALLINT = 41
		,@PaternityLeaveTypeId SMALLINT = 14
		,@MaternityLeaveTypeId SMALLINT = 12
		,@BusinessTripTypeId SMALLINT = 9
		,@BereavementLeaveTypeId SMALLINT = 21
		,@OffsetLeaveTypeId SMALLINT = 27
		,@WeddingLeaveTypeId SMALLINT = 6
		,@SuspendWorkLeaveTypeId SMALLINT = 3
		,@HospitalizationLeaveTypeId SMALLINT = 9
		,@CompanyEventLeaveTypeId SMALLINT = 38
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6
	CREATE TABLE #tblGroupIds (GroupId INT PRIMARY KEY)
	CREATE TABLE #tblEmployeeIds (EmployeeId INT PRIMARY KEY)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupIds (GroupId)
		SELECT DISTINCT value
		FROM STRING_SPLIT(@TeamIds, ',')
		WHERE ISNUMERIC(value) = 1
	END

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT DISTINCT emp.EmpId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		AND empsum.IsTopManager = 0
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
			@isLocal IS NULL
			OR empsum.IsLocal = @isLocal
			)
		AND EXISTS (
			SELECT 1
			FROM #tblGroupIds AS tbl WITH (NOLOCK)
			WHERE tbl.GroupId = emp.GroupId
			)

	SELECT @employeeIds = COALESCE(@employeeIds + ',', '') + CAST(EmployeeId AS VARCHAR(20))
	FROM #tblEmployeeIds WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
        ,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @employeeIds

	SELECT emp.EmpId
		,emp.Code
		,emp.FullName
		,emp.NickName
        ,gr.Code AS TeamCode
		,gr.[Name] AS TeamName
		,dept.Code AS DepartmentCode
		,dept.[Name] AS DepartmentName
		,empsum.WorkingDays
		,empsum.WorkingHours
		,SUM(ISNULL(empatt.TotalWorkHours, 0)) AS TotalWorkingHours
		,SUM(CASE 
				WHEN empca.IsHoliday = 1
					OR empca.IsOffDay = 1
					--OR ISNULL(empatt.TotalWorkHours, 0) = 0
					OR (
						empca.IsLeaveDay = 1
						AND empca.LeaveDay = 1
						) THEN 0
				WHEN empca.IsLeaveDay = 0 THEN 1
				WHEN empca.LeaveDay < 1 THEN 0.5
				ELSE 0
				END) AS PaymentWorkingDays
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @AnnualLeaveTypeId
						OR empca.LeaveTypeId2 = @AnnualLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS AnnualLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @BusinessTripTypeId
						OR empca.LeaveTypeId2 = @BusinessTripTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS BusinessTrip
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @BereavementLeaveTypeId
						OR empca.LeaveTypeId2 = @BereavementLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS BereavementLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @OffsetLeaveTypeId
						OR empca.LeaveTypeId2 = @OffsetLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS OffsetLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @WeddingLeaveTypeId
						OR empca.LeaveTypeId2 = @WeddingLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS WeddingLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @SuspendWorkLeaveTypeId
						OR empca.LeaveTypeId2 = @SuspendWorkLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS SuspendWork
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @HospitalizationLeaveTypeId
						OR empca.LeaveTypeId2 = @HospitalizationLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS HospitalizationLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @UnpaidLeaveTypeId
						OR empca.LeaveTypeId2 = @UnpaidLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS UnpaidLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @UnpaidLeaveInsuranceTypeId
						OR empca.LeaveTypeId2 = @UnpaidLeaveInsuranceTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS UnpaidLeaveInsurance
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @PaternityLeaveTypeId
						OR empca.LeaveTypeId2 = @PaternityLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS PaternityLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @MaternityLeaveTypeId
						OR empca.LeaveTypeId2 = @MaternityLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS MaternityLeave
		,SUM(CASE 
				WHEN empca.IsOffDay = 0
					AND empca.IsHoliday = 0
					AND empca.IsLeaveDay = 1
					AND (
						empca.LeaveTypeId = @CompanyEventLeaveTypeId
						OR empca.LeaveTypeId2 = @CompanyEventLeaveTypeId
						) THEN CASE 
						WHEN ISNULL(empca.LeaveTypeId2, 0) <> 0
							AND ISNULL(empca.LeaveTypeId, 0) <> ISNULL(empca.LeaveTypeId2, 0) THEN 0.5
						ELSE empca.LeaveDay
						END
				ELSE 0
				END) AS CompanyEvent
		,SUM(ISNULL(ot.NormalHours, 0)) AS NormalOvertimeHours
		,SUM(ISNULL(ot.OffHours, 0)) AS OffOvertimeHours
		,SUM(ISNULL(ot.PublicHours, 0)) AS PublicOvertimeHours
		,SUM(ISNULL(ot.SpecialHours, 0)) AS SpecialOvertimeHours
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid WITH (NOLOCK) ON emp.EmpId = empid.EmployeeId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON gr.DepartmentId = dept.DepartmentId
		INNER JOIN dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK) ON emp.EmpId = empca.EmpId
		AND empca.WorkDate BETWEEN @FromDate
			AND @ToDate
		INNER JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON emp.EmpId = empatt.EmpId
		AND empatt.AttendanceDate = empca.WorkDate
		LEFT JOIN dbo.OTDailyRequest AS ot WITH (NOLOCK) ON ot.EmpId = emp.EmpId
		AND empca.WorkDate = ot.OvertimeDate
		AND ot.[Status] IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId)
	GROUP BY emp.EmpId
		,emp.Code
		,emp.NickName
		,emp.FullName
		,empsum.WorkingDays
		,empsum.WorkingHours
        ,gr.Code
		,gr.[Name]
        ,dept.Code
		,dept.[Name]
	ORDER BY emp.NickName

	DROP TABLE #tblGroupIds
	
	DROP TABLE #tblEmployeeIds
END