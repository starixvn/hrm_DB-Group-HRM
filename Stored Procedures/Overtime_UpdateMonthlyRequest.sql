/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Overtime_UpdateMonthlyRequest]
(
    @EmployeeId INT
    ,@Month DATE
    ,@VerifierId INT
    ,@ApproverId INT
    ,@DailyDetailsXml NVARCHAR(MAX)
    ,@ActorId INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-11-04
    Task: update monthly overtime request
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
    Param's Explanation:
        @DailyDetailsXml:
            <Root><Row WorkDate="2019-01-01" ShiftId="1" TimeIn="07:46" TimeOut=17:00"
	           ActualWorkingHours="9" NormalHours="1" OffHours="1" PublicHours="1" SpecialHours="1" Remark="remark" /></Root>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @AutoApproveRequest BIT
		,@CanOT BIT
		,@ModifiedDate DATETIME = GETDATE()
        ,@CompanyId SMALLINT

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS emp WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
    WHERE emp.EmpId = @EmployeeId

	SELECT @AutoApproveRequest = ce.AutoApproveRequest
		,@CanOT = es.CanOT
	FROM dbo.EmployeeSummary AS es WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON es.EmpId = ce.EmpId
	WHERE es.EmpId = @EmployeeId
        AND ce.CompanyId = @CompanyId

    SET @AutoApproveRequest = ISNULL(@AutoApproveRequest, 0)

	IF ISNULL(@CanOT, 0) = 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'You don''t have permission.'

		RETURN
	END

	CREATE TABLE #tblDailyOvertime (
		WorkDate DATE
		,ShiftId INT
		,TimeIn NVARCHAR(10)
		,[TimeOut] NVARCHAR(10)
		,ActualWorkingHours DECIMAL(18, 2)
		,NormalHours DECIMAL(3, 1)
		,OffHours DECIMAL(3, 1)
		,PublicHours DECIMAL(3, 1)
		,SpecialHours DECIMAL(3, 1)
		,Remark NVARCHAR(2000)
		)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@DailyDetailsXml

		INSERT INTO #tblDailyOvertime (
			WorkDate
			,ShiftId
			,TimeIn
			,[TimeOut]
			,ActualWorkingHours
			,NormalHours
			,OffHours
			,PublicHours
			,SpecialHours
			,Remark
			)
		SELECT WorkDate
			,ShiftId
			,TimeIn
			,[TimeOut]
			,ActualWorkingHours
			,NormalHours
			,OffHours
			,PublicHours
			,SpecialHours
			,Remark
		FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (WorkDate DATE, ShiftId INT, TimeIn VARCHAR(10), [TimeOut] VARCHAR(10), ActualWorkingHours DECIMAL(18, 2), NormalHours DECIMAL(3, 1), OffHours DECIMAL(3, 1), PublicHours DECIMAL(3, 1), SpecialHours DECIMAL(3, 1), Remark NVARCHAR(2000)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 101
			,@ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	DECLARE @RequestId BIGINT
		,@CurrentStatus TINYINT 

	SELECT TOP 1 @RequestId = RequestId
		,@CurrentStatus = CurrentStatus
	FROM dbo.OTMonthlyRequest WITH (NOLOCK)
	WHERE [Month] = @Month
		AND EmpId = @EmployeeId

	IF @CurrentStatus NOT IN (1, 3, 5, 7)
	BEGIN
		SET @ErrCode = 104
		SET @ErrMsg = 'The status of this request is not pending.'

		RETURN
	END

	DELETE
	FROM #tblDailyOvertime
	WHERE NormalHours = 0
		AND OffHours = 0
		AND PublicHours = 0
		AND SpecialHours = 0

	IF NOT EXISTS (
			SELECT 1
			FROM #tblDailyOvertime
			)
	BEGIN
		DELETE daily
		FROM dbo.OTDailyRequest AS daily WITH (ROWLOCK)
		WHERE daily.EmpId = @EmployeeId
			AND daily.RequestId = @RequestId

		DELETE monthly
		FROM dbo.OTMonthlyRequest AS monthly WITH (ROWLOCK)
		WHERE monthly.EmpId = @EmployeeId
			AND monthly.RequestId = @RequestId

		RETURN
	END

	IF @RequestId IS NULL
	BEGIN
		INSERT INTO dbo.OTMonthlyRequest (
			[Month]
			,EmpId
			,NormalHours
			,OffHours
			,PublicHours
			,SpecialHours
			,CurrentStatus
			,VerifierId
			,ApproverId
			,VerifiedStatus
			,ApprovedStatus
			,HRStatus
			,CreatedBy
			,CreatedDate
			)
		SELECT @Month
			,@EmployeeId
			,SUM(NormalHours)
			,SUM(OffHours)
			,SUM(PublicHours)
			,SUM(SpecialHours)
			,1 AS CurrentStatus
			,@VerifierId
			,@ApproverId
			,(CASE 
				WHEN @AutoApproveRequest = 1
					AND @VerifierId IS NULL THEN 2
				ELSE 1 END
				) AS VerifiedStatus
			,(CASE 
				WHEN @AutoApproveRequest = 1
					AND @ApproverId IS NULL THEN 2
				ELSE 1 END
				) AS ApprovedStatus
			,1 AS HRStatus
			,@ActorId
			,@ModifiedDate
		FROM #tblDailyOvertime WITH (NOLOCK)

		SELECT @RequestId = CAST(SCOPE_IDENTITY() AS BIGINT)
	END
	ELSE
	BEGIN
		UPDATE ot
		SET ot.CurrentStatus = (CASE 
				WHEN @AutoApproveRequest = 1
					AND @VerifierId IS NOT NULL THEN 1
				WHEN @AutoApproveRequest = 1
					AND @ApproverId IS NOT NULL THEN 2
				WHEN @AutoApproveRequest = 1
					AND @ApproverId IS NULL THEN 4
				ELSE 1 END
				)
			,ot.VerifierId = @VerifierId
			,ot.VerifiedStatus = (CASE 
				WHEN @AutoApproveRequest = 1
					AND @VerifierId IS NULL THEN 2
				ELSE 1 END
				)
			,ot.ApproverId = @ApproverId
			,ot.ApprovedStatus = (CASE 
				WHEN @AutoApproveRequest = 1
					AND @ApproverId IS NULL THEN 2
				ELSE 1 END
				)
			,ot.NormalHours = rd.NormalHours
			,ot.OffHours = rd.OffHours
			,ot.PublicHours = rd.PublicHours
			,ot.SpecialHours = rd.SpecialHours
			,ot.ModifiedBy = @ActorId
			,ot.ModifiedDate = @ModifiedDate
		FROM dbo.OTMonthlyRequest AS ot WITH (ROWLOCK, UPDLOCK)
			,(
				SELECT SUM(ISNULL(rd.NormalHours, 0)) NormalHours
					,SUM(ISNULL(rd.OffHours, 0)) OffHours
					,SUM(ISNULL(rd.PublicHours, 0)) PublicHours
					,SUM(ISNULL(rd.SpecialHours, 0)) SpecialHours
				FROM #tblDailyOvertime AS rd WITH (NOLOCK)
				) AS rd
		WHERE RequestId = @RequestId

		DELETE dbo.OTDailyRequest WITH (ROWLOCK, UPDLOCK)
		WHERE EmpId = @EmployeeId
			AND RequestId = @RequestId
	END

	INSERT INTO dbo.OTDailyRequest (
		OvertimeDate
		,EmpId
		,RequestId
		,Schedule
		,TimeIn
		,[TimeOut]
		,TotalHours
		,NormalHours
		,OffHours
		,PublicHours
		,SpecialHours
		,Remark
		,[Status]
		,CreatedBy
		,CreatedDate
		,IsUpdated
		)
	SELECT WorkDate
		,@EmployeeId
		,@RequestId
		,ShiftId
		,CONVERT(NVARCHAR(100), WorkDate, 111) + ' ' + [TimeIn] + ':00' AS [TimeIn]
		,CONVERT(NVARCHAR(100), WorkDate, 111) + ' ' + [TimeOut] + ':00' AS [TimeOut]
		,ActualWorkingHours
		,NormalHours
		,OffHours
		,PublicHours
		,SpecialHours
		,Remark
		,1
		,@ActorId
		,@ModifiedDate
		,0
	FROM #tblDailyOvertime WITH (NOLOCK)
	WHERE [TimeIn] IS NOT NULL
		AND [TimeOut] IS NOT NULL

	DECLARE @FromDate DATE
		,@ToDate DATE

	SELECT @FromDate = MIN(WorkDate)
		,@ToDate = MAX(WorkDate)
	FROM #tblDailyOvertime WITH (NOLOCK)

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
        ,@fromDate = @FromDate
		,@toDate = @ToDate
		,@empIds = @EmployeeId
		,@isUpdateRequestData = 1

	EXEC dbo.Log_WriteLog @LogActionId = 10
		,@LogDate = @ModifiedDate
		,@Description = 'Update monthly overtime'
		,@TrackingValue = @DailyDetailsXml
		,@UserId = @ActorId
		,@EmpId = @EmployeeId

	DROP TABLE #tblDailyOvertime
END