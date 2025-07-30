/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Dashboard_Get] @EmployeeId INT,
	@Date DATE,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-06-18
Task: show dashboard info for employee
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @month SMALLINT
		,@fromDate DATE
		,@toDate DATE
		,@TotalPendingOvertime INT
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
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6

	SET @fromDate = CAST(YEAR(@Date) AS VARCHAR(4)) + '/' + CAST(MONTH(@Date) AS VARCHAR(2)) + '/01'
	SET @toDate = DATEADD(DAY, - 1, DATEADD(MONTH, 1, @fromDate))

	DECLARE @tblRequestType TABLE (
		Id TINYINT
		,[Name] NVARCHAR(100)
		)
	DECLARE @tblData TABLE (
		RequestTypeId TINYINT
		,TotalRequest SMALLINT
		,TotalPending SMALLINT
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

	SELECT @TotalPendingOvertime = COUNT(1)
	FROM dbo.OTMonthlyRequest WITH (NOLOCK)
	WHERE EmpId = @EmployeeId
		AND CurrentStatus IN (@PendingStatusId, @VerifiedStatusId)
		AND (
			ISNULL(NormalHours, 0) <> 0
			OR ISNULL(OffHours, 0) <> 0
			OR ISNULL(PublicHours, 0) <> 0
			OR ISNULL(SpecialHours, 0) <> 0
			)

	INSERT INTO @tblData (
		RequestTypeId
		,TotalRequest
		,TotalPending
		)
	SELECT (CASE 
			WHEN RequestType IN (@CheckInTypeId, @CheckOutTypeId) THEN @CheckInTypeId
			WHEN RequestType IN (@LateInTypeId, @EarlyOutTypeId) THEN @LateInTypeId
			WHEN RequestType = @ChangeShiftTypeId THEN @ChangeShiftTypeId
			WHEN RequestType = @LeaveTypeId THEN @LeaveTypeId
			WHEN RequestType = @KeepInViewTypeId THEN @KeepInViewTypeId END
			) AS RequestTypeId
		,SUM(CASE 
				WHEN CurrentStatus IN (@PendingStatusId, @VerifiedStatusId, @ApprovedStatusId, @ProcessedStatusId) THEN 1
				ELSE 0
				END) AS TotalRequest
		,SUM(CASE 
				WHEN CurrentStatus IN (@PendingStatusId, @VerifiedStatusId) THEN 1
				ELSE 0
				END) AS TotalPending
	FROM dbo.WorkingTimeRequest AS wtr WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = wtr.EmpId  
	WHERE CreatedDate BETWEEN @fromDate
			AND @todate
			AND wtr.EmpId = @EmployeeId
			AND ce.CompanyId = @CompanyId
	GROUP BY CASE 
			WHEN RequestType IN (@CheckInTypeId, @CheckOutTypeId) THEN @CheckInTypeId
			WHEN RequestType IN (@LateInTypeId, @EarlyOutTypeId) THEN @LateInTypeId
			WHEN RequestType = @ChangeShiftTypeId THEN @ChangeShiftTypeId
			WHEN RequestType = @LeaveTypeId THEN @LeaveTypeId
			WHEN RequestType = @KeepInViewTypeId THEN @KeepInViewTypeId
			END
	
	UNION
	SELECT @OvertimeTypeId AS RequestTypeId
		,0 AS TotalRequest
		,@TotalPendingOvertime AS TotalPending

	SELECT rqtype.Id AS RequestTypeId
		,rqtype.[Name] AS RequestType
		,data.TotalRequest
		,data.TotalPending
	FROM @tblRequestType AS rqtype
		LEFT JOIN @tblData AS data ON rqtype.Id = data.RequestTypeId
	ORDER BY rqtype.Id
END