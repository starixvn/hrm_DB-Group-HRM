/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Dashboard_GetMemberRequest] @EmployeeId INT,
	@Date DATE,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-06-19
Task: show dashboard info for employee
DB: HRM
Original:

Revisions:
Param's Explanation:
	-Jay.Do@20250603: Count member in different company
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromDate DATE = DATEADD(d, - 7, @Date)
		,@toDate DATE = DATEADD(d, 1, @Date)
		,@TotalOvertimePendingByVerifier INT
		,@TotalOvertimePendingByApprover INT
		-- role
		,@VerifierId TINYINT = 2
		,@ApproverId TINYINT = 3
		-- request type
		,@CheckInTypeId TINYINT = 1
		,@CheckOutTypeId TINYINT = 2
		,@LateInTypeId TINYINT = 3
		,@EarlyOutTypeId TINYINT = 4
		,@ChangeShiftTypeId TINYINT = 5
		,@LeaveTypeId TINYINT = 6
		,@KeepInViewTypeId TINYINT = 7
		,@OvertimeTypeId TINYINT = 8
		-- request status
		,@PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7
	DECLARE @tblrole TABLE (RoleId TINYINT)
	DECLARE @tblRequestType TABLE (
		Id TINYINT
		,[Name] NVARCHAR(100)
		)

	INSERT INTO @tblRequestType
	VALUES (
		@CheckInTypeId
		,'Check in/out'
		)
		,(
		@LateInTypeId
		,'Late In/Early Out'
		)
		,(
		@ChangeShiftTypeId
		,'Change Shift'
		)
		,(
		@LeaveTypeId
		,'Leave'
		)
		,(
		@KeepInViewTypeId
		,'Compensation Leave'
		)
		,(
		@OvertimeTypeId
		,'Overtime'
		)

	INSERT INTO @tblrole
	SELECT emprole.RoleId
	FROM dbo.EmployeeRole AS emprole WITH (NOLOCK)
		INNER JOIN dbo.LookupData AS lkdata WITH (NOLOCK) ON emprole.RoleId = lkdata.Value
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emprole.EmployeeId
		INNER JOIN dbo.[Lookup] AS lk WITH (NOLOCK) ON lk.Id = lkdata.LookupId
		AND lk.Code = 'SR' -- System Role
	WHERE emprole.EmployeeId = @EmployeeId
		AND lkdata.CompanyId = @CompanyId
		AND ce.CompanyId = @CompanyId
		AND emprole.RoleId IN (@VerifierId, @ApproverId)

	CREATE TABLE #tblData (
		RoleId TINYINT
		,RequestTypeId TINYINT
		,TotalPending INT
		,TotalApproved INT
		,TotalRejected INT
		,FromDate DATE
		,ToDate DATE
		)

	-- overtime
	SELECT @TotalOvertimePendingByVerifier = COUNT(1)
	FROM dbo.OTMonthlyRequest AS ot WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ot.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ot.EmpId = emp.EmpId
		AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
	WHERE ot.VerifierId = @EmployeeId
		AND ce.CompanyId = @CompanyId
		AND ot.CurrentStatus = @PendingStatusId
		AND (
			ISNULL(ot.NormalHours, 0) <> 0
			OR ISNULL(ot.OffHours, 0) <> 0
			OR ISNULL(ot.PublicHours, 0) <> 0
			OR ISNULL(ot.SpecialHours, 0) <> 0
			)

	SELECT @TotalOvertimePendingByApprover = COUNT(1)
	FROM dbo.OTMonthlyRequest AS ot WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ot.EmpId = emp.EmpId
		AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
	WHERE ot.ApproverId = @EmployeeId
		AND ot.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId)
		AND (
			ISNULL(ot.NormalHours, 0) <> 0
			OR ISNULL(ot.OffHours, 0) <> 0
			OR ISNULL(ot.PublicHours, 0) <> 0
			OR ISNULL(ot.SpecialHours, 0) <> 0
			)

	-- pending
	INSERT INTO #tblData (
		RoleId
		,RequestTypeId
		,TotalPending
		,TotalApproved
		,TotalRejected
		,FromDate
		,ToDate
		)
	SELECT CASE 
			WHEN req.VerifierId = @EmployeeId
				AND req.VerifierId <> req.ApproverId THEN @VerifierId
			WHEN req.ApproverId = @EmployeeId THEN @ApproverId
			END
		,CASE 
			WHEN req.RequestType IN (@CheckInTypeId, @CheckOutTypeId) THEN @CheckInTypeId
			WHEN req.RequestType IN (@LateInTypeId, @EarlyOutTypeId) THEN @LateInTypeId
			WHEN req.RequestType = @ChangeShiftTypeId THEN @ChangeShiftTypeId
			WHEN req.RequestType = @LeaveTypeId THEN @LeaveTypeId
			WHEN req.RequestType = @KeepInViewTypeId THEN @KeepInViewTypeId
			END
		,SUM(CASE 
				WHEN CASE 
						WHEN req.VerifierId = @EmployeeId
							AND req.CurrentStatus = @PendingStatusId THEN 1
						WHEN req.ApproverId = @EmployeeId
							AND req.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId) THEN 1
						ELSE 0
						END = 1 THEN 1
				ELSE 0
				END)
		,SUM(CASE 
				WHEN CASE 
						WHEN req.VerifierId = @EmployeeId
							AND req.CurrentStatus IN (@VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId) THEN 1
						WHEN req.ApproverId = @EmployeeId
							AND req.CurrentStatus IN (@ApprovedStatusId, @ProcessedStatusId) THEN 1
						ELSE 0
						END = 1 THEN 1
				ELSE 0
				END)
		,SUM(CASE 
				WHEN CASE 
						WHEN req.VerifierId = @EmployeeId
							AND req.CurrentStatus IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId) THEN 1
						WHEN req.ApproverId = @EmployeeId
							AND req.CurrentStatus IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId) THEN 1
						ELSE 0
						END = 1 THEN 1
				ELSE 0
				END)
		,MIN(req.CreatedDate) AS FromDate
		,MAX(req.CreatedDate) AS ToDate
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON req.EmpId = emp.EmpId
		AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
	WHERE (
			req.VerifierId = @EmployeeId
			OR req.ApproverId = @EmployeeId
			)
		AND CASE 
			WHEN req.VerifierId = @EmployeeId
				AND req.CurrentStatus = @PendingStatusId THEN 1
			WHEN req.ApproverId = @EmployeeId
				AND req.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId) THEN 1
			ELSE 0
			END = 1
	GROUP BY CASE 
			WHEN req.VerifierId = @EmployeeId
				AND req.VerifierId <> req.ApproverId THEN @VerifierId
			WHEN req.ApproverId = @EmployeeId THEN @ApproverId
			END
		,CASE 
			WHEN req.RequestType IN (@CheckInTypeId, @CheckOutTypeId) THEN @CheckInTypeId
			WHEN req.RequestType IN (@LateInTypeId, @EarlyOutTypeId) THEN @LateInTypeId
			WHEN req.RequestType = @ChangeShiftTypeId THEN @ChangeShiftTypeId
			WHEN req.RequestType = @LeaveTypeId THEN @LeaveTypeId
			WHEN req.RequestType = @KeepInViewTypeId THEN @KeepInViewTypeId
			END
	
	UNION
	SELECT @VerifierId
		,@OvertimeTypeId
		,@TotalOvertimePendingByVerifier
		,0
		,0
		,NULL
		,NULL

	-- approved
	INSERT INTO #tblData (
		RoleId
		,RequestTypeId
		,TotalPending
		,TotalApproved
		,TotalRejected
		)
	SELECT CASE 
			WHEN req.VerifierId = @EmployeeId
				AND req.VerifierId <> req.ApproverId THEN @VerifierId
			WHEN req.ApproverId = @EmployeeId THEN @ApproverId
			END
		,CASE 
			WHEN req.RequestType IN (@CheckInTypeId, @CheckOutTypeId) THEN @CheckInTypeId
			WHEN req.RequestType IN (@LateInTypeId, @EarlyOutTypeId) THEN @LateInTypeId
			WHEN req.RequestType = @ChangeShiftTypeId THEN @ChangeShiftTypeId
			WHEN req.RequestType = @LeaveTypeId THEN @LeaveTypeId
			WHEN req.RequestType = @KeepInViewTypeId THEN @KeepInViewTypeId
			END
		,SUM(CASE 
				WHEN CASE 
						WHEN req.VerifierId = @EmployeeId
							AND req.CurrentStatus = @PendingStatusId THEN 1
						WHEN req.ApproverId = @EmployeeId
							AND req.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId) THEN 1
						ELSE 0
						END = 1 THEN 1
				ELSE 0
				END)
		,SUM(CASE 
				WHEN CASE 
						WHEN req.VerifierId = @EmployeeId
							AND req.CurrentStatus IN (@VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId) THEN 1
						WHEN req.ApproverId = @EmployeeId
							AND req.CurrentStatus IN (@ApprovedStatusId, @ProcessedStatusId) THEN 1
						ELSE 0
						END = 1 THEN 1
				ELSE 0
				END)
		,SUM(CASE 
				WHEN CASE 
						WHEN req.VerifierId = @EmployeeId
							AND CurrentStatus IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId) THEN 1
						WHEN req.ApproverId = @EmployeeId
							AND req.CurrentStatus IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId) THEN 1
						ELSE 0
						END = 1 THEN 1
				ELSE 0
				END)
	FROM dbo.WorkingTimeRequest AS req WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON req.EmpId = emp.EmpId
		AND emp.[Enabled] = 1
		AND emp.isDeleted = 0
	WHERE req.CreatedDate >= @fromdate
		AND req.CreatedDate < @toDate
		AND (
			req.VerifierId = @EmployeeId
			OR req.ApproverId = @EmployeeId
			)
		AND CASE 
			WHEN req.VerifierId = @EmployeeId
				AND req.CurrentStatus = @PendingStatusId THEN 1
			WHEN req.ApproverId = @EmployeeId
				AND req.CurrentStatus IN (@PendingStatusId, @VerifiedStatusId) THEN 1
			ELSE 0
			END = 0
	GROUP BY CASE 
			WHEN req.VerifierId = @EmployeeId
				AND req.VerifierId <> req.ApproverId THEN @VerifierId
			WHEN req.ApproverId = @EmployeeId THEN @ApproverId
			END
		,CASE 
			WHEN req.RequestType IN (@CheckInTypeId, @CheckOutTypeId) THEN @CheckInTypeId
			WHEN req.RequestType IN (@LateInTypeId, @EarlyOutTypeId) THEN @LateInTypeId
			WHEN req.RequestType = @ChangeShiftTypeId THEN @ChangeShiftTypeId
			WHEN req.RequestType = @LeaveTypeId THEN @LeaveTypeId
			WHEN req.RequestType = @KeepInViewTypeId THEN @KeepInViewTypeId
			END
	
	UNION
	SELECT @ApproverId
		,@OvertimeTypeId
		,@TotalOvertimePendingByApprover
		,0
		,0
		
	SELECT tblrole.RoleId
		,tblrole.RequestTypeId
		,tblrole.RequestType
		,SUM(TotalPending) AS TotalPending
		,SUM(TotalApproved) AS TotalApproved
		,SUM(TotalRejected) AS TotalRejected
		,MIN(data.FromDate) AS FromDate
		,MAX(data.ToDate) AS ToDate
	FROM (
		SELECT tblrole.RoleId
			,rqtype.Id AS RequestTypeId
			,rqtype.[Name] AS RequestType
		FROM @tblrole AS tblrole
			,@tblRequestType AS rqtype
		) AS tblrole
		LEFT JOIN #tblData AS data ON tblrole.RoleId = data.RoleId
		AND tblrole.RequestTypeId = data.RequestTypeId
	GROUP BY tblrole.RoleId
		,tblrole.RequestTypeId
		,tblrole.RequestType
	ORDER BY tblrole.RoleId
		,tblrole.RequestTypeId

	DROP TABLE #tblData
END
