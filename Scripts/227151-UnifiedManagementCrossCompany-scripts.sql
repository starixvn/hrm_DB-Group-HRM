USE [bodb_HRM]
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

CREATE OR ALTER FUNCTION [dbo].[fnc_GetEmployeeByActorId_CrossCompany] (
	@EmpId INT = NULL
	,@ExcludeUserDelete INT = 1
	,@IsShowUserInTeam BIT = 1
	,@CompanyId INT
	)
RETURNS TABLE
/*
	Created: Hank.Nguyen@20250606
	Task: Get employee Id by actor id
	DB: bodb_HRM

	Revisions:
        20250606@Hank: add @IsShowCrossCompany
	Param's Explanation:
*/
AS
RETURN
WITH cteByRole AS (
	SELECT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId
	WHERE @EmpId IS NULL
	   OR EXISTS (
			SELECT 1
			FROM dbo.Employee AS emp WITH (NOLOCK)
                INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON emp.EmpId = er.EmployeeId
			WHERE er.EmployeeId = @EmpId
                AND er.RoleId IN (6, 7, 12) -- HR, SA, HR Assistant
	   )
),
cteBySupervisor AS (
	SELECT e.EmpId
	FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
	    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE es.OwnerId = @EmpId
	  AND es.IsDeleted = 0
	  AND es.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
),
cteByGroupSupervisor AS (
	SELECT e.EmpId
	FROM dbo.GroupSupervisor AS gs WITH (NOLOCK)
	    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON gs.GroupId = e.GroupId
	WHERE gs.OwnerId = @EmpId
	  AND gs.IsDeleted = 0
	  AND gs.ActionType IN (2, 3, 4, 5) -- verifier, approver, shift manager, on behalf request
	  AND e.EmpId NOT IN (
			SELECT es.EmpId
			FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
			WHERE es.EmpId = e.EmpId
			  AND es.ActionType = gs.ActionType
			  AND es.IsDeleted = 0
		)
),
cteBySameGroup AS (
	SELECT ee.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
	    INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.GroupId = e.GroupId
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId AND ce.CompanyId = @CompanyId
	WHERE e.EmpId = @EmpId AND @IsShowUserInTeam = 1
),
cteBySelf AS (
	SELECT ce.EmpId
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
	WHERE ce.EmpId = @EmpId AND ce.CompanyId = @CompanyId
),
cteAll AS (
	SELECT EmpId FROM cteByRole
	UNION ALL
	SELECT EmpId FROM cteBySupervisor
	UNION ALL
	SELECT EmpId FROM cteByGroupSupervisor
	UNION ALL
	SELECT EmpId FROM cteBySameGroup
	UNION ALL
	SELECT EmpId FROM cteBySelf
)

SELECT DISTINCT e.EmpId
FROM cteAll AS ca
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = ca.EmpId
WHERE (
    (@ExcludeUserDelete = 1 AND e.isDeleted = 0 AND e.[Enabled] = 1)
	OR @ExcludeUserDelete = 0
    )

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetByEmployee] @EmpId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-09-27
Task: get change shift request
DB: HRM

Revisions:
	- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SELECT wkr.RequestId
		,cs.TypeId
		,cs.FromDate
		,cs.ToDate
		,wkr.Remark
		,wkr.CurrentStatus
		,wkr.CreatedDate
		,wkr.VerifiedDate
		,wkr.ApprovedDate
		,wkr.HRDate AS ProcessedDate
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,verifier.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN verifier.NickName + ' (' + vec.[Name]  +')'
				ELSE verifier.NickName
		END NickName
		,verifier.FullName
		,approver.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN approver.NickName + ' (' + apc.[Name]  +')'
				ELSE approver.NickName
		END NickName
		,approver.FullName
		,hr.EmpId AS HRId
		,hr.NickName
		,hr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.WorkingTimeRequest AS wkr WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wkr.RequestId = cs.RequestId
		AND (
			(
				cs.FromDate BETWEEN @fromdate
					AND @todate
				AND cs.ToDate >= @todate
				)
			OR (
				cs.FromDate <= @fromdate
				AND @todate BETWEEN cs.FromDate
					AND cs.ToDate
				)
			OR cs.ToDate BETWEEN @fromdate
				AND @todate
			)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON cs.EmpId = emp.EmpId
		AND emp.EmpId = @EmpId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = wkr.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = wkr.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = approver.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.EmpId = wkr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = cs.RequestId ORDER BY LogDate DESC)
	ORDER BY wkr.CreatedDate DESC
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetById] 
	@RequestId BIGINT,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-09-20
Task: get request by id
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT wkr.RequestId
		,cs.TypeId
		,cs.FromDate
		,cs.ToDate
		,wkr.Remark
		,wkr.CurrentStatus
		,wkr.CreatedDate
		,wkr.VerifiedDate
		,wkr.ApprovedDate
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,ce.CompanyId
		,empsum.IsTopManager
		,verifier.EmpId AS VerifierId
		,verifier.NickName
		,verifier.FullName
		,vece.CompanyId
		,approver.EmpId AS ApproverId
		,approver.NickName
		,approver.FullName
		,apce.CompanyId
	FROM dbo.WorkingTimeRequest AS wkr WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wkr.RequestId = cs.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON cs.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = cs.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = wkr.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON verifier.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = wkr.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON approver.EmpId = apce.EmpId
	WHERE wkr.RequestId = @RequestId
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetHistoryById] @RequestId BIGINT,
	@CompanyId INT = NULL
AS
/*
Created: Tim.Trinh@2019-09-24
Task: view request history
DB: HRM

Revisions:
- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SELECT r.RequestId
		,r.RequestType AS RequestTypeId
		,r.LogDate AS InsertedDate
		,cs.TypeId
		,cs.FromDate
		,cs.ToDate
		,r.Remark
		,r.CurrentStatus
		,r.CreatedDate
		,emp.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN emp.NickName + ' (' + c.[Name]  +')'
				ELSE emp.NickName
		END NickName
		,emp.FullName
		,gr.[Name] AS Team
		,verifier.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN verifier.NickName + ' (' + vec.[Name]  +')'
				ELSE verifier.NickName
		END NickName
		,verifier.FullName
		,approver.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN approver.NickName + ' (' + apc.[Name]  +')'
				ELSE approver.NickName
		END NickName
		,approver.FullName
		,m.EmpId AS ModifierId
		,m.NickName
		,m.FullName
	FROM dbo.WorkingTimeRequestHistory AS r WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
		INNER JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = r.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		INNER JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = r.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = approver.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = r.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(r.ModifiedBy, r.CreatedBy) = m.EmpId
	WHERE r.RequestId = @RequestId
	ORDER BY r.LogDate DESC
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_GetByDate] @EmpId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190624
Task: Get Check In/Out request by empId & date range.
DB: HRM
Original:

Revisions:
	- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT mis.RequestId
		,mis.OnDate
		,wk.RequestType AS RequestTypeId
		,mis.RequestTime
		,mis.ReasonId
		,wk.Remark
		,mis.RefNo
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,mis.EmpId
		,e.NickName
		,e.FullName
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.CheckInOutRequest AS mis WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON mis.RequestId = wk.RequestId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON mis.OnDate = cl.WorkDate
		AND mis.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON mis.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = mis.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = mis.RequestId ORDER BY LogDate DESC)
	WHERE (
			@EmpId IS NULL
			OR mis.EmpId = @EmpId
			)
		AND ce.CompanyId = @CompanyId
		AND mis.OnDate BETWEEN @FromDate
			AND @ToDate
	ORDER BY wk.CreatedDate DESC
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_GetById] 
	@RequestId INT,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190624
Task: Get Check in/out request by RequestId.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT cio.RequestId
		,cio.OnDate
		,wk.RequestType AS RequestTypeId
		,cio.RequestTime
		,cio.ReasonId
		,wk.Remark
		,cio.RefNo
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,cio.EmpId
		,emp.NickName
		,emp.FullName
		,ce.CompanyId
		,empsum.IsTopManager
		,ve.EmpId AS VerifierId
		,ve.NickName
		,vece.CompanyId
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,apce.CompanyId
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
	FROM dbo.CheckInOutRequest AS cio WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON cio.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON cio.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON cio.OnDate = empca.WorkDate
		AND cio.EmpId = empca.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = cio.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON empca.ShiftId = sh.ShiftId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON ve.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON ap.EmpId = apce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
	WHERE cio.RequestId = @RequestId
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_GetHistoryById] @RequestId BIGINT,
	@CompanyId INT = NULL
AS
/*
Created: Quinn.Vo@20190624
Task: Get Check In/Out request history by RequestId.
DB: HRM
Original:

Revisions:
- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT mis.RequestId
		,mis.OnDate
		,wk.RequestType AS RequestTypeId
		,mis.RequestTime
		,mis.ReasonId
		,wk.Remark
		,mis.RefNo
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,wk.LogDate AS InsertedDate
		,mis.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN e.NickName + ' (' + c.[Name]  +')'
				ELSE e.NickName
		END NickName
		,e.FullName
		,g.GroupId AS TeamId
		,g.Code
		,g.[Name] AS Team
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,m.EmpId AS ModifierId
		,m.NickName
		,m.FullName
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.CheckInOutRequestHistory AS mis WITH (NOLOCK) ON wk.HistoryId = mis.HistoryId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON mis.OnDate = cl.WorkDate
		AND mis.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON mis.EmpId = e.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(wk.ModifiedBy,wk.CreatedBy) = m.EmpId
	WHERE mis.RequestId = @RequestId
	ORDER BY wk.LogDate DESC
END

GO

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
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Domain_ByCompanyId_Get] 
	@CompanyId INT
AS
/*
Created: Jay.Do@20250605
Task: Get Domain by company id
DB: HRM_SMS
Original: 

Revisions: 
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		TOP 1
		Domain
	FROM dbo.CompanySite WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetVerifierAndApprover] @EmpId INT
	,@RequestType TINYINT
	,@CompanyId INT = NULL
AS
/*
Created: 20160609@Quinn.Vo
Task: Get list verifier and approver for employee when create/edit request.
DB: HRM
Original:

Revisions:
	- Jay.Do@20250602: show company with nick name for employee in different company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Supervisors TABLE (OwnerId INT, ActionType INT)

	INSERT INTO @Supervisors (OwnerId, ActionType)
	SELECT DISTINCT OwnerId, ActionType
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
	WHERE su.EmpId = @EmpId
		AND (
			@RequestType IS NULL
			OR su.RequestType = @RequestType
			)
		AND su.ActionType IN (2, 3)
		AND su.IsDeleted = 0
	UNION
	SELECT DISTINCT su.OwnerId, ActionType
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.GroupId = e.GroupId
	WHERE e.EmpId = @EmpId
		AND (
			@RequestType IS NULL
			OR su.RequestType = @RequestType
			)
		AND su.ActionType IN (2, 3)
		AND su.IsDeleted = 0

	SELECT DISTINCT OwnerId
		,ee.FullName
		 ,CASE 
		 	WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
		 		THEN ee.NickName + ' (' + c.[Name]  +')'
		 		ELSE ee.NickName
		 END NickName
		,ee.Email
	FROM @Supervisors AS su
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON su.OwnerId = ee.EmpId
		 INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId
		 INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE ActionType = 2

	SELECT DISTINCT OwnerId
		,ee.FullName
		 ,CASE 
		 	WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
		 		THEN ee.NickName + ' (' + c.[Name]  +')'
		 		ELSE ee.NickName
		 END NickName
		,ee.Email
	FROM @Supervisors AS su
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON su.OwnerId = ee.EmpId
		 INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId
		 INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE ActionType = 3
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_GetByDate] @EmpId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190604
Task: Get Keep In View request by empId & date range.
DB: HRM
Original:

Revisions:
	- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT kiv.RequestId
		,kiv.KeepInViewType AS KeepInViewTypeId
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,kiv.IsHalfDay
		,wk.Remark
		,kiv.RefNo
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,kiv.EmpId
		,e.NickName
		,e.FullName
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON kiv.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON kiv.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = kiv.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = kiv.RequestId ORDER BY LogDate DESC)
	WHERE (
			@EmpId IS NULL
			OR kiv.EmpId = @EmpId
			)
		AND ce.CompanyId = @CompanyId
		AND kiv.OnDate BETWEEN @FromDate
			AND @ToDate
	ORDER BY wk.CreatedDate DESC
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_GetById] @RequestId INT,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190606
Task: Get Keep In View request by RequestId.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT kiv.RequestId
		,kiv.KeepInViewType AS KeepInViewTypeId
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,kiv.IsHalfDay
		,kiv.ShiftId
		,wk.Remark
		,kiv.RefNo
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,shift.[Name] AS ShiftName
		,kiv.EmpId
		,emp.NickName
		,emp.FullName
		,ce.CompanyId
		,empsum.IsTopManager
		,ve.EmpId AS VerifierId
		,ve.NickName
		,vece.CompanyId
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,apce.CompanyId
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
	FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON kiv.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON kiv.EmpId = emp.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON ve.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON ap.EmpId = apce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON kiv.EmpId = empca.EmpId
		AND kiv.OnDate = empca.WorkDate
		LEFT JOIN dbo.Shift AS shift WITH (NOLOCK) ON empca.ShiftId = shift.ShiftId
	WHERE kiv.RequestId = @RequestId
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_GetHistoryById] @RequestId INT,
	@CompanyId INT = NULL
AS
/*
Created: Quinn.Vo@20190606
Task: Get Keep In View request history by RequestId.
DB: HRM
Original:

Revisions:
- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT kiv.RequestId
		,kiv.KeepInViewType AS KeepInViewTypeId
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,kiv.IsHalfDay
		,wk.Remark
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,wk.LogDate AS InsertedDate
		,kiv.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN e.NickName + ' (' + c.[Name]  +')'
				ELSE e.NickName
		END NickName
		,e.FullName
		,g.[Name] AS Team
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,m.EmpId AS ModifierId
		,m.NickName
		,m.FullName
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequestHistory AS kiv WITH (NOLOCK) ON wk.HistoryId = kiv.HistoryId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON kiv.EmpId = e.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(wk.ModifiedBy,wk.CreatedBy) = m.EmpId
	WHERE kiv.RequestId = @RequestId
	ORDER BY wk.LogDate DESC
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_GetByDate] @EmpId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190626
Task: Get late in/early out request by empId & date range.
DB: HRM
Original:

Revisions:
	- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT le.RequestId
		,le.OnDate
		,wk.RequestType AS RequestTypeId
		,le.LateInMins
		,le.EarlyOutMins
		,le.ReasonId
		,wk.Remark
		,le.RefNo
		,CASE 
			WHEN wk.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END AS ActualLateInEarlyOut
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,le.EmpId
		,e.NickName
		,e.FullName
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.LateInEarlyOutRequest AS le WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON le.RequestId = wk.RequestId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON le.OnDate = cl.WorkDate
		AND le.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON le.EmpId = att.EmpId
		AND le.OnDate = att.AttendanceDate
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON le.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = le.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = le.RequestId ORDER BY LogDate DESC)
	WHERE (
			@EmpId IS NULL
			OR le.EmpId = @EmpId
			)
		AND ce.CompanyId = @CompanyId
		AND le.OnDate BETWEEN @FromDate
			AND @ToDate
	ORDER BY wk.CreatedDate DESC
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_GetById] @RequestId INT
AS
/*
Created: Quinn.Vo@20190626
Task: Get late in/early out request by RequestId.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT lieo.RequestId
		,lieo.OnDate
		,lieo.LateInMins
		,lieo.EarlyOutMins
		,lieo.ReasonId
		,wk.Remark
		,lieo.RefNo
		,wk.RequestType AS RequestTypeId
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,lieo.EmpId
		,emp.NickName
		,emp.FullName
        ,ce.CompanyId
		,empsum.IsTopManager
		,ve.EmpId AS VerifierId
		,ve.NickName
		,vece.CompanyId
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,apce.CompanyId
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
	FROM dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON lieo.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON lieo.EmpId = emp.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = lieo.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON ve.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON ap.EmpId = apce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
	WHERE lieo.RequestId = @RequestId
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_GetHistoryById] @RequestId BIGINT,
	@CompanyId INT = NULL
AS
/*
Created: Quinn.Vo@20190626
Task: Get late in/early out request history by RequestId.
DB: HRM
Original: 

Revisions:    
- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT le.RequestId
		,le.OnDate
		,wk.RequestType AS RequestTypeId
		,le.LateInMins
		,le.EarlyOutMins
		,le.ReasonId
		,wk.Remark
		,le.RefNo
		,CASE 
			WHEN wk.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END AS ActualLateInEarlyOut
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,wk.LogDate AS InsertedDate
		,le.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN e.NickName + ' (' + c.[Name]  +')'
				ELSE e.NickName
		END NickName
		,e.FullName
		,g.[Name] AS Team
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,m.EmpId AS ModifierId
		,m.NickName
		,m.FullName
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.LateInEarlyOutRequestHistory AS le WITH (NOLOCK) ON wk.HistoryId = le.HistoryId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON le.OnDate = cl.WorkDate
		AND le.EmpId = cl.EmpId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON le.EmpId = att.EmpId
		AND le.OnDate = att.AttendanceDate
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON le.EmpId = e.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(wk.ModifiedBy,wk.CreatedBy) = m.EmpId
	WHERE le.RequestId = @RequestId
	ORDER BY wk.LogDate DESC
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetByDate] @EmpId INT,
	@FromDate DATETIME,
	@ToDate DATETIME,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190619
Task: Get leave request by empId & date range.
DB: HRM
Original:

Revisions:
	- Jay.Do@20250602: show company with nick name for employee in different company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT lr.RequestId
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,wk.Remark
		,lr.RefNo
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,wk.VerifiedStatus
		,wk.ApprovedStatus
		,wk.HRStatus AS ProcessedStatus
		,lr.LeaveType AS LeaveTypeId
		,lv.[Name]
		,lr.EmpId
		,e.NickName
		,e.FullName
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON lr.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON lr.EmpId = e.EmpId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lr.LeaveType = lv.LeaveTypeId
		AND lv.CompanyId = @CompanyId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = lr.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = lr.RequestId ORDER BY LogDate DESC)
	WHERE lr.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId
		AND (
			(
				lr.FromDate >= @fromdate
				AND lr.FromDate <= @todate
				AND lr.ToDate >= @todate
				)
			OR (
				lr.FromDate <= @fromdate
				AND lr.ToDate >= @todate
				)
			OR (
				lr.ToDate >= @fromdate
				AND lr.ToDate <= @todate
				)
			)
	ORDER BY wk.CreatedDate DESC

	SELECT ldt.RequestId
		,ldt.OnDate
		,ldt.WorkType
		,ldt.LeaveType AS LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,ldt.IsHalfDay
		,ldt.FromTime
		,ldt.ToTime
	FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON ldt.LeaveType = lv.LeaveTypeId
		AND lv.CompanyId = @CompanyId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ldt.EmpId
	WHERE lr.EmpId = @EmpId
		AND ce.CompanyId = @CompanyId
		AND (
			(
				lr.FromDate >= @fromdate
				AND lr.FromDate <= @todate
				AND lr.ToDate >= @todate
				)
			OR (
				lr.FromDate <= @fromdate
				AND lr.ToDate >= @todate
				)
			OR (
				lr.ToDate >= @fromdate
				AND lr.ToDate <= @todate
				)
			)
END

GO
/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetById] @RequestId BIGINT,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190617
Task: Get Leave request by RequestId.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT lr.RequestId
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,hl.IsHospitalApplication
		,wk.Remark
		,lr.RefNo
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,lr.LeaveType AS LeaveTypeId
		,lv.[Name]
		,lr.EmpId
		,e.NickName
		,e.FullName
		,ce.CompanyId
		,empsum.IsTopManager
		,ve.EmpId AS VerifierId
		,ve.NickName
		,Ve.FullName
		,vece.CompanyId
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,apce.CompanyId
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
	FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON lr.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON lr.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = lr.EmpId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON e.EmpId = empsum.EmpId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lr.LeaveType = lv.LeaveTypeId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON ve.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON ap.EmpId = apce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.HospitalLeave AS hl WITH (NOLOCK) ON hl.RequestId = lr.RequestId
	WHERE lr.RequestId = @RequestId
        AND lv.CompanyId = @CompanyId

	SELECT ldt.RequestId
		,ldt.OnDate
		,ldt.WorkType
		,ldt.LeaveType AS LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,ldt.IsHalfDay
		,ldt.FromTime
		,ldt.ToTime
	FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON ldt.LeaveType = lv.LeaveTypeId
	WHERE ldt.RequestId = @RequestId
        AND lv.CompanyId = @CompanyId
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetHistoryById] @RequestId BIGINT
	,@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190617
Task: Get Leave request history by RequestId.
DB: HRM
Original:

Revisions:
	- Jay.Do@20250602: show company with nick name for employee in different company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT wk.HistoryId
		,lr.RequestId
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,wk.Remark
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,wk.LogDate AS InsertedDate
		,lr.LeaveType AS LeaveTypeId
		,lv.[Name]
		,lr.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
				THEN e.NickName + ' (' + c.[Name]  +')'
				ELSE e.NickName
		END NickName
		,e.FullName
		,g.[Name] AS Team
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,m.EmpId AS ModifierId
		,m.NickName
		,m.FullName
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequestHistory AS lr WITH (NOLOCK) ON wk.HistoryId = lr.HistoryId
		AND lr.RequestId = @RequestId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON lr.EmpId = e.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lr.LeaveType = lv.LeaveTypeId
        AND lv.CompanyId = @CompanyId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS m WITH (NOLOCK) ON ISNULL(wk.ModifiedBy,wk.CreatedBy) = m.EmpId
	ORDER BY wk.LogDate DESC

	SELECT wk.HistoryId
		,ldt.RequestId
		,ldt.OnDate
		,ldt.WorkType
		,ldt.LeaveType AS LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,ldt.IsHalfDay
		,ldt.FromTime
		,ldt.ToTime
	FROM dbo.WorkingTimeRequestHistory AS wk WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequestDetailHistory AS ldt WITH (NOLOCK) ON wk.HistoryId = ldt.HistoryId
		AND ldt.RequestId = @RequestId
		INNER JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON ldt.LeaveType = lv.LeaveTypeId
        AND lv.CompanyId = @CompanyId
END

GO

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
	,@IsShowCrossCompany BIT = 0
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
			FROM dbo.fnc_GetEmployeeByActorId_CrossCompany(@ActorId, 1, 0, @CompanyId)
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
		,u.Code AS UnitCode
		,verifier.EmpId AS VerifierId
		,CASE 
			WHEN verifierCE.CompanyId <> @CompanyId THEN verifier.NickName + ' (' + verifierCompany.[Name] + ')'
			ELSE verifier.NickName 
		END AS VerifierNickname
		,verifier.FullName AS VerifierFullName
		,approver.EmpId AS ApproverId
		,CASE 
			WHEN approverCE.CompanyId <> @CompanyId THEN approver.NickName + ' (' + approverCompany.[Name] + ')'
			ELSE approver.NickName 
		END AS ApproverNickname
		,approver.FullName AS ApproverFullName
		,req.CurrentStatus AS StatusId
		,emp.EmpId
		,CASE 
			WHEN e.CompanyId <> @CompanyId THEN emp.NickName + ' (' + c.[Name] + ')'
			ELSE emp.NickName 
		END AS NickName
		,emp.FullName
	FROM dbo.OTMonthlyRequest AS req WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds e WITH (NOLOCK) ON req.EmpId = e.EmployeeId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON req.EmpId = emp.EmpId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = e.CompanyId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON gr.GroupId = emp.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = dep.UnitId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = req.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS verifierCE WITH (NOLOCK) ON verifierCE.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company AS verifierCompany WITH (NOLOCK) ON verifierCompany.CompanyId = verifierCE.CompanyId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = req.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS approverCE WITH (NOLOCK) ON approverCE.EmpId = approver.EmpId
		LEFT JOIN dbo.Company AS approverCompany WITH (NOLOCK) ON approverCompany.CompanyId = approverCE.CompanyId
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
		AND (
			EXISTS (
				SELECT 1
				FROM #tblGroupIds AS tblgr WITH (NOLOCK)
				WHERE tblgr.GroupId = emp.GroupId
				)
			OR (@IsShowCrossCompany = 1 AND EXISTS (
				SELECT 1
				FROM #tblEmployeeIds AS tblemp WITH (NOLOCK)
				WHERE tblemp.EmployeeId = emp.EmpId AND tblemp.CompanyId <> @CompanyId
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
		,emp.NickName

	DROP TABLE #tblEmployeeIds

	DROP TABLE #tblGroupIds

	DROP TABLE #tblOvertimeType
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Overtime_GetMonthlyRequestByEmpId] @EmployeeId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-07-02
Task: get monthly overtime
DB: HRM

Revisions:
	- Jay.do@20250603: handle cross company [Redmine: #227151]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATE = GETDATE()
		,@tmpFromDate DATE = @FromDate

	CREATE TABLE #tblMonth ([Month] DATE)

	WHILE @tmpFromDate <= @toDate
	BEGIN
		INSERT INTO #tblMonth ([Month])
		VALUES (@tmpFromDate)

		SET @tmpFromDate = DATEADD(MONTH, 1, @tmpFromDate)
	END

	SELECT request.RequestId
		,cl.[Month]
		,request.VerifiedDate
		,request.ApprovedDate
		,request.NormalHours
		,request.OffHours
		,request.PublicHours
		,request.SpecialHours
		,request.CurrentStatus AS StatusId
		,verifier.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN verifier.NickName + ' (' + vec.[Name]  +')'
				ELSE verifier.NickName
		END NickName
		,verifier.FullName
		,approver.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN approver.NickName + ' (' + apc.[Name]  +')'
				ELSE approver.NickName
		END NickName
		,approver.FullName
	FROM #tblMonth AS cl
		LEFT JOIN dbo.OTMonthlyRequest AS request WITH (NOLOCK) ON request.[Month] = cl.[Month]
		AND request.[Month] BETWEEN @fromdate
			AND @todate
		AND request.EmpId = @EmployeeId
		LEFT JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = request.EmpId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.empid = request.VerifierId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.empid = request.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = approver.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = request.EmpId
	    AND ce.CompanyId = @CompanyId
	WHERE EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmployeeId
				AND CanOT = 1
			)
	ORDER BY cl.[Month] DESC

	DROP TABLE #tblMonth
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Overtime_GetMonthlyRequestDetailsById] 
	@RequestId BIGINT,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-07-08
Task: Get monthly overtime request by id.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Month DATE
		,@fromDate DATE
		,@toDate DATE
		,@EmployeeId INT
		,@NewRuleApplyFromMonth DATE = '2020/05/01'
		,@empCompanyId INT

	SELECT @Month = [Month]
		,@EmployeeId = o.EmpId
		,@empCompanyId = c.CompanyId
	FROM dbo.OTMonthlyRequest o WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) ON c.EmpId = o.EmpId
	WHERE RequestId = @RequestId

	SELECT @toDate = @Month
		,@fromDate = DATEADD(month, - 1, @Month)

	SELECT @fromDate = CONVERT(VARCHAR(5), YEAR(@fromDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@fromDate)) + '/10'
		,@toDate = CONVERT(VARCHAR(5), YEAR(@toDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@toDate)) + + '/09'

	IF @Month = @NewRuleApplyFromMonth
	BEGIN
		SET @toDate = CONVERT(VARCHAR(5), YEAR(@toDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@toDate)) + '/20'
	END

	IF @Month > @NewRuleApplyFromMonth
	BEGIN
		SET @fromDate = CONVERT(VARCHAR(5), YEAR(@fromDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@fromDate)) + '/21'
		SET @toDate = CONVERT(VARCHAR(5), YEAR(@toDate)) + '/' + CONVERT(VARCHAR(2), MONTH(@toDate)) + '/20'
	END

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @empCompanyId
		,@fromDate = @fromDate
		,@toDate = @toDate
		,@empIds = @EmployeeId

	SELECT ot.RequestId
		,ot.[Month]
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.CurrentStatus AS StatusId
		,emp.EmpId
		,CASE 
			WHEN ce_emp.CompanyId <> @CompanyId THEN emp.NickName + ' (' + ISNULL(c_emp.Name, '') + ')'
			ELSE emp.NickName 
		END AS NickName
		,emp.FullName
		,empsum.WorkingHours
		,empsum.SpecialOT
		,ot.VerifierId
		,CASE 
			WHEN ce_verifier.CompanyId <> @CompanyId THEN verifier.NickName + ' (' + ISNULL(c_verifier.Name, '') + ')'
			ELSE verifier.NickName 
		END AS NickName
		,verifier.FullName
		,ot.ApproverId
		,CASE 
			WHEN ce_approver.CompanyId <> @CompanyId THEN approver.NickName + ' (' + ISNULL(c_approver.Name, '') + ')'
			ELSE approver.NickName 
		END AS NickName
		,approver.FullName
	FROM dbo.OTMonthlyRequest AS ot WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ot.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce_emp WITH (NOLOCK) ON ce_emp.EmpId = emp.EmpId
		LEFT JOIN dbo.Company AS c_emp WITH (NOLOCK) ON c_emp.CompanyId = ce_emp.CompanyId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		INNER JOIN dbo.Employee AS verifier WITH (NOLOCK) ON ot.VerifierId = verifier.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce_verifier WITH (NOLOCK) ON ce_verifier.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company AS c_verifier WITH (NOLOCK) ON c_verifier.CompanyId = ce_verifier.CompanyId
		INNER JOIN dbo.Employee AS approver WITH (NOLOCK) ON ot.ApproverId = approver.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce_approver WITH (NOLOCK) ON ce_approver.EmpId = approver.EmpId
		LEFT JOIN dbo.Company AS c_approver WITH (NOLOCK) ON c_approver.CompanyId = ce_approver.CompanyId
	WHERE ot.RequestId = @RequestId

	SELECT empca.WorkDate
		,COALESCE(sc.ShiftId, scl.ShiftId, s.ShiftId) AS ShiftId
		,COALESCE(sc.Code, scl.Code, s.Code) AS ShiftCode
		,COALESCE(sc.TotalHours, scl.TotalHours, s.TotalHours) AS TotalShiftHours
		,CONVERT(VARCHAR(5), empatt.InFixed, 108) AS [TimeIn]
		,CONVERT(VARCHAR(5), empatt.OutFixed, 108) AS [TimeOut]
		,empatt.TotalWorkHours AS ActualWorkingHours
		,ot.NormalHours
		,ot.OffHours
		,ot.PublicHours
		,ot.SpecialHours
		,ot.[Remark]
		,empca.IsHoliday
		,empca.IsOffDay
		,empca.IsKeepInView
	FROM dbo.tmpEmployeeCalendar AS empca WITH (NOLOCK)
		LEFT JOIN dbo.OTDailyRequest AS ot WITH (NOLOCK) ON empca.WorkDate = ot.OvertimeDate
		AND ot.EmpId = empca.EmpId
		LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
		LEFT JOIN dbo.EmployeeAttendance AS empatt WITH (NOLOCK) ON empatt.AttendanceDate = empca.WorkDate
		AND empatt.EmpId = empca.EmpId
		LEFT JOIN dbo.[Shift] AS sc WITH (NOLOCK) ON sc.ShiftId = empatt.ShiftId
		LEFT JOIN dbo.[Shift] AS scl WITH (NOLOCK) ON scl.ShiftId = empca.ShiftId
	WHERE empca.EmpId = @employeeId
		AND empca.WorkDate BETWEEN @fromDate
			AND @toDate
	ORDER BY empca.WorkDate
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetRequestByCreateDate_AllType]
(
    @CompanyId SMALLINT
    ,@SupervisorId INT = NULL
    ,@empid INT = NULL
    ,@TeamIds VARCHAR(MAX) = ''
    ,@fromdate DATETIME
    ,@todate DATETIME
    ,@status VARCHAR(MAX) = NULL
    ,@role VARCHAR(MAX) = ''
    ,@isLocal BIT = NULL
    ,@requestType INT = NULL
    ,@leaveTypeId INT = NULL
	,@isShowCrossCompany BIT = 0
)
AS
/*
    Created: Tom.Vo@2013-11-04
    Task: Get Request By Date
    DB: bodb_HRM

    Revisions:
        20250403@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	CREATE TABLE #tblstatus (Currentstatus TINYINT)

	CREATE TABLE #tblGroupsList (GroupId INT PRIMARY KEY)

	CREATE TABLE #tblEmployeeId (
		EmpId INT PRIMARY KEY, 
		CompanyId INT 
	)

	CREATE TABLE #tblRequestId (RequestId INT PRIMARY KEY)

	CREATE TABLE #tblTotalDaysRequestInMonth (
		EmpId INT
		,RequestType TINYINT
		,TotalDaysRequest INT
		)

	CREATE TABLE #tblRequestInDaily (
		RequestID BIGINT
		,EmpId INT
		,RequestType TINYINT
		,InOutMins INT
		,ActualInOutMins INT
		,RequestedTime DATETIME
		,FromDate DATETIME
		,ToDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 1)
		,IsHalfDay BIT
		,IsWarning BIT
		,KeepInViewType TINYINT
		)

	CREATE TABLE #tblGeneralLeaveDetail (
		RequestId BIGINT
		,LeaveCountDetails NVARCHAR(MAX)
		)

	IF ISNULL(@status, '') <> ''
	BEGIN
		INSERT INTO #tblstatus (Currentstatus)
		SELECT value
		FROM STRING_SPLIT(@status, ',')
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupsList (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empid IS NULL
	BEGIN
		IF @SupervisorID IS NULL
		OR @role LIKE '%6%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpID)
			SELECT e.EmpId
			FROM dbo.Employee AS e WITH (NOLOCK)
		END
		ELSE IF @role LIKE '%2%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			EXEC dbo.Request_GetMemberByActorId @EmpId = @SupervisorId
				,@ExcludeUserDelete = 1
				,@IsShowUserInTeam = 0
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 1, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeId (EmpID)
		VALUES (@empid)
	END

	
	UPDATE #tblEmployeeId
	SET CompanyId = ce.CompanyId
	FROM #tblEmployeeId AS eid WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = eid.EmpId


	INSERT INTO #tblRequestId (RequestId)
	SELECT r.RequestId
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS eid WITH (NOLOCK) ON r.EmpId = eid.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = eid.empID
		AND e.isDeleted = 0
		LEFT JOIN dbo.EmployeeSummary AS e_s WITH (NOLOCK) ON e_s.EmpId = eid.EmpId
	WHERE (
			@requestType = 0
			OR (
				@requestType = 1
				AND r.RequestType IN (1, 2)
				)
			OR (
				@requestType = 2
				AND r.RequestType IN (3, 4)
				)
			OR (
				@requestType = 3
				AND r.RequestType = 5
				)
			OR (
				@requestType = 4
				AND r.RequestType = 6
				)
			OR (
				@requestType = 5
				AND r.RequestType = 7
				)
			)
		AND (
			(
				@empid IS NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
						WHERE tblemp.EmpId = r.EmpId
						)
					OR r.VerifierId = @SupervisorID
					OR r.ApproverId = @SupervisorID
					)
				)
			OR (
				@empid IS NOT NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
						WHERE tblemp.EmpId = r.EmpId
						)
					)
				)
			)
		AND (
			ISNULL(@status, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tblstatus AS tblstatus WITH (NOLOCK)
				WHERE tblstatus.Currentstatus = r.CurrentStatus
				)
			)
		AND (
			e.GroupId IS NULL
			OR EXISTS (
				SELECT 1
				FROM #tblGroupsList AS tblgr WITH (NOLOCK)
				WHERE tblgr.GroupId = e.GroupId
				)
			OR (@isShowCrossCompany = 1 AND EXISTS (
				SELECT 1
				FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
				WHERE tblemp.EmpId = r.EmpId AND tblemp.CompanyId <> @CompanyId
				AND (r.VerifierId = @SupervisorId OR r.ApproverId = @SupervisorId)
			))
			)
		AND (
			@isLocal IS NULL
			OR e_s.IsLocal = @isLocal
			)
		AND r.CreatedDate BETWEEN @fromdate
			AND @todate

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		
		AND (
			DATEDIFF(MM, inout.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, inout.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(MM, lr.FromDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(MM, cs.FromDate, @fromdate) = 0
			OR DATEDIFF(MM, cs.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT @empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE wt.EmpId = @empid
		AND wt.currentstatus = 6
		AND (
			DATEDIFF(MM, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,count(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(MM, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(MM, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
			WHERE tblemp.EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,ActualInOutMins
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,inout.OnDate
		,inout.OnDate
		,0
		,CASE 
			WHEN wt.RequestType = 3 THEN inout.LateInMins
			ELSE inout.EarlyOutMins
			END
		,CASE 
			WHEN wt.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON inout.EmpId = att.EmpId
		AND inout.OnDate = att.AttendanceDate

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,CASE 
			WHEN ldt.FromTime IS NULL THEN lr.FromDate
			ELSE ldt.FromTime
			END
		,CASE 
			WHEN ldt.ToTime IS NULL THEN lr.ToDate
			ELSE ldt.ToTime
			END
		,lr.TotalDays
		,1
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
	WHERE lr.TotalDays = 0.5
		AND ldt.IsHalfDay = 1

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,0
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE lr.TotalDays <> 0.5

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,FromShift
		,ToShift
		,KeepInViewType
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.OnDate
		,lr.OnDate
		,lr.OnDate
		,lr.FromTime
		,lr.ToTime
		,CASE 
			WHEN lr.IsHalfDay = 0 THEN 1
			ELSE 0.5
			END TotalDays
		,NULL
		,NULL
		,lr.KeepInViewType
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,IsWarning
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftId
		,CASE 
			WHEN ISNULL(att.TotalWorkHours, 0) = 0 THEN 1
			ELSE 0
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON lr.OnDate = att.AttendanceDate
		AND lr.EmpId = att.EmpId
	WHERE wt.CurrentStatus = 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftId
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
	WHERE wt.CurrentStatus <> 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate
		,count(1) TotalDays
		,MAX(csd.FromShift) FromShift
		,MAX(csd.ToShift) ToShift
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
		INNER JOIN dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK) ON csd.RequestId = cs.RequestId
	GROUP BY wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate

	INSERT INTO #tblGeneralLeaveDetail (
		RequestId
		,LeaveCountDetails
		)
	SELECT DISTINCT wt.RequestId
		,STUFF((
				SELECT ', ' + (
						CAST(SUM(CASE 
									WHEN rd1.IsHalfDay = 0 THEN 1
									ELSE 0.5
									END) AS NVARCHAR(100)) + ' days ' + lt1.Code
						)
				FROM dbo.LeaveRequestDetail AS rd1 WITH (NOLOCK)
					INNER JOIN dbo.LeaveType AS lt1 WITH (NOLOCK) ON lt1.LeaveTypeId = rd1.LeaveType
                    AND lt1.CompanyId = @CompanyId
				WHERE rd1.RequestId = rd.RequestId
					AND rd1.LeaveType <> 0
				GROUP BY rd1.RequestId
					,rd1.LeaveType
					,lt1.Code
				FOR XML PATH('')
				), 1, 2, '') AS LeaveCountDetails
	FROM (
		SELECT rq.RequestId
			,CreatedDate
			,EmpId
		FROM dbo.WorkingTimeRequest AS rq WITH (NOLOCK)
			INNER JOIN #tblRequestId AS r WITH (NOLOCK) ON r.RequestId = rq.RequestId
		) AS wt
		INNER JOIN #tblRequestInDaily AS rd WITH (NOLOCK) ON wt.RequestId = rd.RequestID
		INNER JOIN #tblRequestId AS r1 WITH (NOLOCK) ON r1.RequestId = rd.RequestId
	ORDER BY wt.RequestId

	SELECT r.RequestId
		,r.RequestType
		,r.Currentstatus AS [Status]
		,r.empID
		,rd.FromDate
		,rd.ToDate
		,rd.TotalDays
		,rd.IsHalfDay
		,rd.RequestedTime AS RequestedDate
		,rd.FromTime
		,rd.ToTime
		,rd.KeepInViewType
		,gdt.LeaveCountDetails
		,lv.LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,r.Remark
		,ISNULL(rm.TotalDaysRequest, 0) TotalDaysRequestInMonth
		,u.Code AS UnitCode
		,CASE 
			WHEN r.RequestType IN (1, 2) THEN inoutmiss.ReasonId
			WHEN r.RequestType IN (3, 4) THEN inout.ReasonId
			ELSE 0
			END [ReasonId]
		,CASE 
			WHEN r.RequestType IN (1, 2, 6, 7) THEN lr.RefNo
			WHEN r.RequestType IN (3, 4) THEN inout.RefNo
			WHEN r.RequestType IN (5) THEN NULL
			END RefNo
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN s1.ShiftID
			ELSE s3.ShiftID END
			) AS FromShiftId
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShiftName
		,s2.ShiftID AS ToShiftId
		,(CASE 
			WHEN s2.ShiftID IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShiftName
		,s2.[Name] AS ToShiftName
		,csr.TypeId AS ChangeShiftType
		,rd.InOutMins AS TotalMinutes
		,rd.ActualInOutMins
		,r.CreatedDate
		,e.EmpId AS RequesterId
		,CASE
            WHEN tmpEmp.CompanyId <> @CompanyId THEN e.NickName + ' (' + ISNULL(company.Name, '') + ')'
            ELSE e.NickName
        END AS RequesterNickName
		,e.FullName AS RequesterFullName
		,g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dep.DepartmentId
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,company.[Name] AS CompanyName
		,tmpEmp.CompanyId
		,verifier.EmpId AS VerifierId
		,CASE
            WHEN verifierCE.CompanyId <> @CompanyId THEN verifier.NickName + ' (' + ISNULL(verifierCompany.Name, '') + ')'
            ELSE verifier.NickName
        END AS VerifierNickName
        ,verifier.FullName AS VerifierFullName
		,r.VerifiedDate
		,r.VerifiedStatus
		,approver.EmpId AS ApproverId
        ,CASE
            WHEN approverCE.CompanyId <> @CompanyId THEN approver.NickName + ' (' + ISNULL(approverCompany.Name, '') + ')'
            ELSE approver.NickName
        END AS ApproverNickName
		,approver.FullName AS ApproverFullName
		,r.ApprovedDate
		,r.ApprovedStatus
		,hr.NickName AS ProcessedByNickName
		,hr.FullName AS ProcessedByFullName
		,r.HRDate AS ProcessedDate
		,r.HRStatus AS ProcessedStatus
		,r.ModifiedDate
		,ISNULL(rd.IsWarning, 0) AS IsWarning
		,r.ReworkCount
		,dbo.fnc_GetAnnualLeaveBalance(r.EmpId, rd.FromDate, r.RequestId) AS AnnualLeaveBalance
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblRequestInDaily AS rd WITH (NOLOCK) ON r.RequestId = rd.RequestID
		INNER JOIN #tblRequestId AS rq WITH (NOLOCK) ON r.RequestId = rq.RequestId
		INNER JOIN #tblEmployeeId AS tmpEmp WITH (NOLOCK) ON tmpEmp.EmpId = r.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = tmpEmp.empID
		INNER JOIN dbo.Company AS company WITH (NOLOCK) ON company.CompanyId = tmpEmp.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = dep.UnitId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.empid = r.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS verifierCE WITH (NOLOCK) ON verifierCE.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company AS verifierCompany WITH (NOLOCK) ON verifierCompany.CompanyId = verifierCE.CompanyId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.empid = r.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS approverCE WITH (NOLOCK) ON approverCE.EmpId = approver.EmpId
		LEFT JOIN dbo.Company AS approverCompany WITH (NOLOCK) ON approverCompany.CompanyId = approverCE.CompanyId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.empid = r.HRId
		LEFT JOIN #tblTotalDaysRequestInMonth AS rm ON r.empID = rm.empid
		AND r.RequestType = rm.RequestType
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS C WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftID = rd.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftID = rd.ToShift
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftID = c.ShiftID
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeID = lr.LeaveType
        AND lv.CompanyId = tmpEmp.CompanyId
	WHERE (@leaveTypeId IS NULL OR lr.LeaveType = @leaveTypeId)
	ORDER BY r.CreatedDate DESC

	SELECT csrd.RequestId
		,csrd.OnDate
		,csrd.ToDate
	FROM #tblRequestId AS r WITH (NOLOCK)
		INNER JOIN ChangeShiftRequest AS csr WITH (NOLOCK) ON csr.RequestId = r.RequestId
		INNER JOIN ChangeShiftRequestDetail AS csrd WITH (NOLOCK) ON csr.RequestId = csrd.RequestId

	DROP TABLE #tblstatus

	DROP TABLE #tblGroupsList

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblTotalDaysRequestInMonth

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestId
END

GO


/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetRequestByRequestDate_AllType] 
(
    @CompanyId SMALLINT
    ,@SupervisorId INT = NULL
    ,@empid INT = NULL
    ,@TeamIds VARCHAR(MAX) = ''
    ,@fromdate DATETIME
    ,@todate DATETIME
    ,@status VARCHAR(MAX) = NULL
    ,@role VARCHAR(MAX) = ''
    ,@isLocal BIT = NULL
    ,@requestType INT = NULL
    ,@leaveTypeId INT = NULL
    ,@isShowCrossCompany BIT = 0
)
AS
/*
    Created: Tom.Vo@2013-11-04
    Task: get all emp request list
    DB: bodb_HRM

    Revisions:
        20250403@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	-- work type
	DECLARE @OffDay TINYINT = 1
		,@LeaveDay TINYINT = 2
		,@Onduty TINYINT = 3

	CREATE TABLE #tblstatus (Currentstatus TINYINT)

	CREATE TABLE #tblGroupsList (GroupId INT)

	CREATE TABLE #tblEmployeeId (
		EmpId INT PRIMARY KEY, 
		CompanyId INT
	)

	CREATE TABLE #tblRequestId (RequestId INT)

	CREATE TABLE #tblTotalDaysRequestInMonth (
		empid INT
		,RequestType TINYINT
		,TotalDaysRequest INT
		)

	CREATE TABLE #tblRequestInDaily (
		RequestId BIGINT
		,empid INT
		,RequestType TINYINT
		,InOutMins INT
		,ActualInOutMins INT
		,RequestedTime DATETIME
		,FromDate DATETIME
		,ToDate DATETIME
		,FromTime DATETIME
		,ToTime DATETIME
		,FromShift INT
		,ToShift INT
		,TotalDays NUMERIC(18, 1)
		,IsHalfDay BIT
		,IsWarning BIT
		,KeepInViewType TINYINT
		)

	CREATE TABLE #tblGeneralLeaveDetail (
		RequestId BIGINT
		,LeaveCountDetails NVARCHAR(MAX)
		)

	IF ISNULL(@status, '') <> ''
	BEGIN
		INSERT INTO #tblstatus (Currentstatus)
		SELECT value
		FROM STRING_SPLIT(@status, ',')
	END

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tblGroupsList (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	IF @empid IS NULL
	BEGIN
		IF @SupervisorId IS NULL
			OR @role LIKE '%6%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpID)
			SELECT DISTINCT e.EmpId
			FROM dbo.Employee AS e WITH (NOLOCK)
		END
		ELSE IF @role LIKE '%2%'
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			EXEC dbo.Request_GetMemberByActorId @EmpId = @SupervisorId
				,@ExcludeUserDelete = 1
				,@IsShowUserInTeam = 0
		END
		ELSE
		BEGIN
			INSERT INTO #tblEmployeeId (EmpId)
			SELECT EmpId
			FROM dbo.fnc_GetEmployeeByActorId(@SupervisorId, 1, 1, @CompanyId)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #tblEmployeeId (EmpId)
		VALUES (@empid)
	END

	UPDATE #tblEmployeeId
	SET CompanyId = ce.CompanyId
	FROM #tblEmployeeId AS eid WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = eid.EmpId

	INSERT INTO #tblRequestId (RequestId)
	SELECT r.RequestId
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblEmployeeId AS eid WITH (NOLOCK) ON r.EmpId = eid.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = eid.empID
		AND e.isDeleted = 0
		INNER JOIN dbo.EmployeeSummary AS e_s WITH (NOLOCK) ON e_s.EmpId = eid.EmpId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.KeepInViewRequest AS ke WITH (NOLOCK) ON r.RequestId = ke.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS mi WITH (NOLOCK) ON r.RequestId = mi.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON r.RequestId = cs.RequestId
	WHERE (
			@requestType = 0
			OR (
				@requestType = 1
				AND r.RequestType IN (1, 2)
				)
			OR (
				@requestType = 2
				AND r.RequestType IN (3, 4)
				)
			OR (
				@requestType = 3
				AND r.RequestType = 5
				)
			OR (
				@requestType = 4
				AND r.RequestType = 6
				)
			OR (
				@requestType = 5
				AND r.RequestType = 7
				)
			)
		AND (
			(
				@empid IS NULL
				AND (
					EXISTS (
						SELECT 1
						FROM #tblEmployeeId WITH (NOLOCK)
						WHERE EmpId = r.EmpId
						)
					OR r.VerifierId = @SupervisorID
					OR r.ApproverId = @SupervisorID
					)
				)
			OR (
				@empid IS NOT NULL
				AND EXISTS (
					SELECT 1
					FROM #tblEmployeeId WITH (NOLOCK)
					WHERE EmpId = r.EmpId
					)
				)
			)
		AND (
			ISNULL(@status, '') = ''
			OR r.currentstatus IN (
				SELECT Currentstatus
				FROM #tblstatus WITH (NOLOCK)
				)
			)
		AND (
			e.GroupId IS NULL
			OR e.GroupId IN (
				SELECT GroupId
				FROM #tblGroupsList WITH (NOLOCK)
				)
			OR (@isShowCrossCompany = 1 AND EXISTS (
				SELECT 1
				FROM #tblEmployeeId AS tblemp WITH (NOLOCK)
				WHERE tblemp.EmpId = r.EmpId AND tblemp.CompanyId <> @CompanyId
				AND (r.VerifierId = @SupervisorId OR r.ApproverId = @SupervisorId)
			))
			)
		AND (
			@isLocal IS NULL
			OR e_s.IsLocal = @isLocal
			)
		AND (
			(
				r.RequestType IN (3, 4)
				AND (
					inout.OnDate BETWEEN @fromdate
						AND @todate
					)
				)
			OR (
				r.RequestType = 6
				AND (
					(
						lr.FromDate >= @fromdate
						AND lr.FromDate <= @todate
						AND lr.ToDate >= @todate
						)
					OR (
						lr.FromDate <= @fromdate
						AND lr.ToDate >= @todate
						)
					OR lr.ToDate BETWEEN @fromdate
						AND @todate
					)
				)
			OR (
				r.RequestType = 7
				AND ke.OnDate BETWEEN @fromdate
					AND @todate
				)
			OR (
				r.RequestType IN (1, 2)
				AND mi.OnDate BETWEEN @fromdate
					AND @todate
				)
			OR (
				r.RequestType = 5
				AND (
					(
						cs.FromDate >= @fromdate
						AND cs.FromDate <= @todate
						AND cs.ToDate >= @todate
						)
					OR (
						cs.FromDate <= @fromdate
						AND cs.FromDate <= @todate
						AND cs.ToDate >= @todate
						)
					OR cs.ToDate BETWEEN @fromdate
						AND @todate
					)
				)
			)
		AND (
			@leaveTypeId IS NULL
			OR lr.LeaveType = @leaveTypeId
			)

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(M, inout.OnDate, @fromdate) = 0
			OR DATEDIFF(M, inout.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(M, lr.FromDate, @fromdate) = 0
			OR DATEDIFF(M, lr.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(M, cs.FromDate, @fromdate) = 0
			OR DATEDIFF(M, cs.ToDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT @empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE wt.EmpId = @empid
		AND wt.currentstatus = 6
		AND DATEDIFF(M, lr.OnDate, @fromdate) = 0
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.RequestType

	INSERT INTO #tblTotalDaysRequestInMonth (
		empid
		,RequestType
		,TotalDaysRequest
		)
	SELECT wt.empid
		,wt.RequestType
		,COUNT(1)
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON ee.EmpId = wt.EmpId
	WHERE wt.currentstatus = 6
		AND (
			DATEDIFF(M, lr.OnDate, @fromdate) = 0
			OR DATEDIFF(M, lr.OnDate, @todate) = 0
			)
		AND EXISTS (
			SELECT 1
			FROM #tblEmployeeId
			WHERE EmpId = wt.EmpId
			)
	GROUP BY wt.empid
		,wt.RequestType

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,InOutMins
		,ActualInOutMins
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,inout.OnDate
		,inout.OnDate
		,0
		,CASE 
			WHEN wt.RequestType = 3 THEN inout.LateInMins
			ELSE inout.EarlyOutMins
			END
		,CASE 
			WHEN wt.RequestType = 3 THEN att.LateIn
			ELSE att.EarlyOut
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON wt.RequestId = inout.RequestId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON inout.EmpId = att.EmpId
		AND inout.OnDate = att.AttendanceDate

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.ToDate
		,CASE 
			WHEN ldt.FromTime IS NULL THEN lr.FromDate
			ELSE ldt.FromTime
			END
		,CASE 
			WHEN ldt.ToTime IS NULL THEN lr.ToDate
			ELSE ldt.ToTime
			END
		,lr.TotalDays
		,1
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.LeaveRequestDetail AS ldt WITH (NOLOCK) ON lr.RequestId = ldt.RequestId
	WHERE lr.TotalDays = 0.5
		AND ldt.IsHalfDay = 1

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,IsHalfDay
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.FromDate
		,lr.FromDate
		,lr.ToDate
		,lr.TotalDays
		,0
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
	WHERE lr.TotalDays <> 0.5

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,FromTime
		,ToTime
		,TotalDays
		,FromShift
		,ToShift
		,IsHalfDay
		,KeepInViewType
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.OnDate
		,lr.OnDate
		,lr.OnDate
		,lr.FromTime
		,lr.ToTime
		,CASE 
			WHEN lr.IsHalfDay = 0 THEN 1
			ELSE 0.5
			END TotalDays
		,NULL
		,NULL
		,lr.IsHalfDay
		,lr.KeepInViewType
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.KeepInViewRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,IsWarning
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftID
		,CASE 
			WHEN ISNULL(att.TotalWorkHours, 0) = 0 THEN 1
			ELSE 0
			END
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
		LEFT JOIN dbo.EmployeeAttendance AS att WITH (NOLOCK) ON lr.OnDate = att.AttendanceDate
		AND lr.EmpId = att.EmpId
	WHERE wt.CurrentStatus = 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,RequestedTime
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,lr.RequestTime
		,lr.OnDate
		,lr.OnDate
		,1 TotalDays
		,ec.ShiftID
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.CheckInOutRequest AS lr WITH (NOLOCK) ON wt.RequestId = lr.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS ec WITH (NOLOCK) ON ec.WorkDate = lr.OnDate
		AND ec.EmpId = lr.EmpId
	WHERE wt.CurrentStatus <> 4

	INSERT INTO #tblRequestInDaily (
		RequestID
		,empid
		,RequestType
		,FromDate
		,ToDate
		,TotalDays
		,FromShift
		,ToShift
		)
	SELECT wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate
		,COUNT(1) TotalDays
		,MAX(csd.FromShift) FromShift
		,MAX(csd.ToShift) ToShift
	FROM dbo.WorkingTimeRequest AS wt WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON wt.RequestId = rq.RequestId
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wt.RequestId = cs.RequestId
		INNER JOIN dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK) ON csd.RequestId = cs.RequestId
	GROUP BY wt.RequestID
		,wt.EmpId
		,wt.RequestType
		,cs.FromDate
		,cs.ToDate

	INSERT INTO #tblGeneralLeaveDetail (
		RequestId
		,LeaveCountDetails
		)
	SELECT DISTINCT wt.RequestId
		,STUFF((
				SELECT ', ' + CAST(SUM(LeaveDay) AS NVARCHAR(100)) + CASE 
						WHEN SUM(LeaveDay) > 1 THEN ' days '
						ELSE ' day '
						END + Code
				FROM (
					SELECT RequestId
						,CASE 
							WHEN IsOffDay = 1 THEN 'Off'
							ELSE CASE 
									WHEN IsHoliday = 1 THEN 'PH'
									ELSE Code
									END
							END AS Code
						,CASE 
							WHEN IsOffDay <> 1
								AND IsHoliday <> 1 THEN LeaveDay
							ELSE 1
							END AS LeaveDay
					FROM (
						SELECT ldt.RequestId
							,ldt.LeaveType AS LeaveTypeId
							,lt1.Code
							,CASE 
								WHEN ldt.LeaveType <> 0
									AND ldt.IsHalfDay = 0 THEN 1
								WHEN ldt.LeaveType <> 0
									AND ldt.IsHalfDay = 1 THEN 0.5
								ELSE 0
								END AS LeaveDay
							,CASE 
								WHEN (
										ldt.WorkType = 1
										OR (
											WorkType <> @Onduty
											AND cl.IsOffDay = 1
											)
										) THEN 1
								ELSE 0
								END AS IsOffDay
							,CASE 
								WHEN (
										ldt.WorkType = 1
										OR (
											WorkType <> @Onduty
											AND cl.IsHoliday = 1
											)
										) THEN 1
								ELSE 0
								END AS IsHoliday
						FROM dbo.LeaveRequestDetail AS ldt WITH (NOLOCK)
							INNER JOIN #tblRequestId AS r ON r.RequestId = ldt.RequestId
							LEFT JOIN dbo.LeaveType AS lt1 WITH (NOLOCK) ON lt1.LeaveTypeId = ldt.LeaveType
                            AND lt1.CompanyId = @CompanyId
							LEFT JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON ldt.OnDate = cl.WorkDate
							AND ldt.EmpId = cl.EmpId
						WHERE ldt.WorkType <> @Onduty
						) AS a
					WHERE a.LeaveTypeId <> 0
						OR a.IsOffDay = 1
						OR a.IsHoliday = 1
					) AS b
				WHERE b.RequestId = wt.RequestId
				GROUP BY b.RequestId
					,b.Code
				FOR XML PATH('')
				), 1, 2, '') AS LeaveCountDetails
	FROM (
		SELECT rq.RequestId
			,CreatedDate
			,EmpId
		FROM dbo.WorkingTimeRequest AS rq WITH (NOLOCK)
			INNER JOIN #tblRequestId AS r ON r.RequestId = rq.RequestId
		) AS wt

	SELECT r.RequestId
		,r.RequestType
		,r.Currentstatus AS [Status]
		,r.empID
		,rd.FromDate
		,rd.ToDate
		,rd.TotalDays
		,rd.IsHalfDay
		,rd.RequestedTime AS RequestedDate
		,rd.FromTime
		,rd.ToTime
		,rd.KeepInViewType
		,gdt.LeaveCountDetails
		,lv.LeaveTypeId
		,lv.[Name] AS LeaveTypeName
		,r.Remark
		,ISNULL(rm.TotalDaysRequest, 0) TotalDaysRequestInMonth
		,u.Code AS UnitCode
		,CASE 
			WHEN r.RequestType IN (1, 2) THEN inoutmiss.ReasonId
			WHEN r.RequestType IN (3, 4) THEN inout.ReasonId
			ELSE 0
			END [ReasonId]
		,CASE 
			WHEN r.RequestType IN (1, 2, 6, 7) THEN lr.RefNo
			WHEN r.RequestType IN (3, 4) THEN inout.RefNo
			WHEN r.RequestType IN (5) THEN NULL
			END RefNo
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN s1.ShiftID
			ELSE s3.ShiftID END
			) AS FromShiftId
		,(CASE 
			WHEN r.RequestType IN (1, 2, 5, 7) THEN (CASE 
					WHEN s1.ShiftID IS NULL THEN 'OFF'
					ELSE s1.[Name] END
					)
			ELSE s3.[Name] END
			) AS FromShiftName
		,s2.ShiftID AS ToShiftId
		,(CASE 
			WHEN s2.ShiftID IS NULL THEN 'OFF'
			ELSE s2.[Name] END
			) AS ToShiftName
		,s2.[Name] AS ToShiftName
		,csr.TypeId AS ChangeShiftType
		,rd.InOutMins AS TotalMinutes
		,rd.ActualInOutMins
		,r.CreatedDate
		,e.EmpId AS RequesterId
		,CASE
            WHEN tmpEmp.CompanyId <> @CompanyId THEN e.NickName + ' (' + ISNULL(company.Name, '') + ')'
            ELSE e.NickName
        END AS RequesterNickName
		,e.FullName AS RequesterFullName
		,g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dep.DepartmentId
		,dep.Code AS DepartmentCode
        ,dep.[Name] AS DepartmentName
		,company.[Name] AS CompanyName
		,tmpEmp.CompanyId
		,verifier.EmpId AS VerifierId
		,CASE
            WHEN verifierCE.CompanyId <> @CompanyId THEN verifier.NickName + ' (' + ISNULL(verifierCompany.Name, '') + ')'
            ELSE verifier.NickName
        END AS VerifierNickName
        ,verifier.FullName AS VerifierFullName
		,r.VerifiedDate
		,r.VerifiedStatus
		,approver.EmpId AS ApproverId
        ,CASE
            WHEN approverCE.CompanyId <> @CompanyId THEN approver.NickName + ' (' + ISNULL(approverCompany.Name, '') + ')'
            ELSE approver.NickName
        END AS ApproverNickName
		,approver.FullName AS ApproverFullName
		,approverCompany.[Name] AS ApproverCompanyName
		,r.ApprovedDate
		,r.ApprovedStatus
		,hr.NickName AS ProcessedByNickName
		,hr.FullName AS ProcessedByFullName
		,r.HRDate AS ProcessedDate
		,r.HRStatus AS ProcessedStatus
		,r.ModifiedDate
		,ISNULL(rd.IsWarning, 0) AS IsWarning
		,r.ReworkCount
		,dbo.fnc_GetAnnualLeaveBalance(r.EmpId, rd.FromDate, r.RequestId) AS AnnualLeaveBalance
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN #tblRequestId AS rq ON r.RequestId = rq.RequestId
		INNER JOIN #tblRequestInDaily AS rd ON r.RequestId = rd.RequestID
		INNER JOIN #tblEmployeeId AS tmpEmp WITH (NOLOCK) ON tmpEmp.EmpId = r.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.empID = tmpEmp.empID
		INNER JOIN dbo.Company AS company WITH (NOLOCK) ON company.CompanyId = tmpEmp.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = dep.UnitId
		LEFT JOIN dbo.LateInEarlyOutRequest AS inout WITH (NOLOCK) ON r.RequestId = inout.RequestId
		LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON r.RequestId = lr.RequestId
		LEFT JOIN dbo.CheckInOutRequest AS inoutmiss WITH (NOLOCK) ON r.RequestId = inoutmiss.RequestId
		LEFT JOIN dbo.ChangeShiftRequest AS csr WITH (NOLOCK) ON r.RequestId = csr.RequestId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.empid = r.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS verifierCE WITH (NOLOCK) ON verifierCE.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company AS verifierCompany WITH (NOLOCK) ON verifierCompany.CompanyId = verifierCE.CompanyId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.empid = r.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS approverCE WITH (NOLOCK) ON approverCE.EmpId = approver.EmpId
		LEFT JOIN dbo.Company AS approverCompany WITH (NOLOCK) ON approverCompany.CompanyId = approverCE.CompanyId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.empid = r.HRId
		LEFT JOIN #tblTotalDaysRequestInMonth AS rm ON r.empID = rm.empid
		AND r.RequestType = rm.RequestType
		LEFT JOIN #tblGeneralLeaveDetail AS gdt ON r.RequestId = gdt.RequestId
		LEFT JOIN dbo.EmployeeCalendar AS c WITH (NOLOCK) ON c.empid = r.empid
		AND c.WorkDate = convert(VARCHAR(10), rd.FromDate, 111)
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftID = rd.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftID = rd.ToShift
		LEFT JOIN dbo.[Shift] AS s3 WITH (NOLOCK) ON s3.ShiftID = c.ShiftID
		LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON lv.LeaveTypeID = lr.LeaveType
        AND lv.CompanyId = tmpEmp.CompanyId
	WHERE (@leaveTypeId IS NULL OR lr.LeaveType = @leaveTypeId)
	ORDER BY r.CreatedDate DESC

	SELECT csrd.RequestId
		,csrd.OnDate
		,csrd.ToDate
	FROM #tblRequestId AS r
		INNER JOIN ChangeShiftRequest AS csr WITH (NOLOCK) ON csr.RequestId = r.RequestId
		INNER JOIN ChangeShiftRequestDetail AS csrd WITH (NOLOCK) ON csr.RequestId = csrd.RequestId

	DROP TABLE #tblstatus

	DROP TABLE #tblGroupsList

	DROP TABLE #tblEmployeeId

	DROP TABLE #tblTotalDaysRequestInMonth

	DROP TABLE #tblRequestInDaily

	DROP TABLE #tblGeneralLeaveDetail

	DROP TABLE #tblRequestId
END

GO