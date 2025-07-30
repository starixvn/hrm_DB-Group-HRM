use bodb_HRM
go

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_Reject]
(
    @CompanyId SMALLINT
    ,@RequestId BIGINT
	,@ActorId INT
	,@RoleId TINYINT
	,@Comment NVARCHAR(500) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20190522@Quinn.Vo
    Task: reject check in/out request
    DB: bodb_HRM

    Revisions:
        20250505@Tim: add param @CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @OnDate DATE
		,@EmpId INT
		,@ProcessedDate DATETIME = GETDATE()
		,@RequestTypeId SMALLINT
		-- request type
		,@CheckInRequestTypeId TINYINT = 1
		,@CheckOutRequestTypeId TINYINT = 2
		-- system role
		,@VerifierRoleId TINYINT = 2
		,@ApproverRoleId TINYINT = 3
		,@HRRoleId TINYINT = 6
		-- request status
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7

	SELECT @EmpId = cio.EmpId
		,@OnDate = cio.OnDate
		,@RequestTypeId = r.RequestType
	FROM dbo.CheckInOutRequest AS cio WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON cio.RequestId = r.RequestId
		AND r.RequestId = @RequestId

	EXEC dbo.CheckInOutRequest_UpdateDiscipline @RequestId = @RequestId
		,@ActorId = @ActorId
		,@RequestStatusId = @NotVerifiedStatusId
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	IF @RoleId = @VerifierRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @NotVerifiedStatusId
			,VerifiedStatus = @NotVerifiedStatusId
			--,VerifierId = @ActorId
			,VerifiedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId
	END
	ELSE IF @RoleId = @ApproverRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @RejectedStatusId
			,ApprovedStatus = @NotVerifiedStatusId
			--,ApproverId = @ActorId
			,ApprovedDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId
	END
	ELSE IF @RoleId = @HRRoleId
	BEGIN
		UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
		SET CurrentStatus = @VoidStatusId
			,HRStatus = @NotVerifiedStatusId
			,HRId = @ActorId
			,HRDate = @ProcessedDate
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE RequestId = @RequestId

		UPDATE dbo.EmployeeCalendar WITH (ROWLOCK, UPDLOCK)
		SET RequestedCheckinTime = CASE 
				WHEN @RequestTypeId = @CheckInRequestTypeId THEN NULL
				ELSE RequestedCheckinTime
				END
			,RequestedCheckoutTime = CASE 
				WHEN @RequestTypeId = @CheckOutRequestTypeId THEN NULL
				ELSE RequestedCheckoutTime
				END
			,ModifiedBy = @ActorId
			,ModifiedDate = @ProcessedDate
		WHERE WorkDate = @OnDate
			AND EmpId = @EmpId

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId = @EmpId
			,@FromTime = @OnDate
			,@ToTime = @OnDate
			,@OnlyUpdate = 1
            ,@CompanyId = @CompanyId
	END

	EXEC dbo.CheckInOutRequest_WriteLog @RequestId = @RequestId
		,@Comment = @Comment
END
go

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_InsertMultipleTransactions]
(
    @CompanyId SMALLINT
    ,@EmployeeIds VARCHAR(MAX)
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATE
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013.10.29
    Task: record multiple annual leave transaction and calculate annual leave balance for employee
    DB: bodb_HRM

    Revisions:
        20250429@Tim: add param @CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @maximumBalanceForLocal SMALLINT
		,@maximumBalanceForExpat SMALLINT

	SELECT @maximumBalanceForLocal = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'AnnualLeaveBalanceForLocal'

	SELECT @maximumBalanceForExpat = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'AnnualLeaveBalanceForExpat'

	SET @maximumBalanceForLocal = ISNULL(@maximumBalanceForLocal, 0)
	SET @maximumBalanceForExpat = ISNULL(@maximumBalanceForExpat, 0)

	CREATE TABLE #tblEmployeeIds (EmployeeId INT)

	INSERT INTO #tblEmployeeIds (EmployeeId)
	SELECT value
	FROM STRING_SPLIT(@EmployeeIds, ',')

	IF @maximumBalanceForLocal > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS empsum WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON empsum.EmpId = empid.EmployeeId
			WHERE empsum.IsLocal = 1
				AND @CreditDays > @maximumBalanceForLocal
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Local: ' + CAST(@maximumBalanceForLocal AS VARCHAR(2))

		RETURN
	END
	
	IF @maximumBalanceForExpat > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary AS empsum WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON empsum.EmpId = empid.EmployeeId
			WHERE empsum.IsLocal = 0
				AND @CreditDays > @maximumBalanceForExpat
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Expat: no rules (only ' + + CAST(@maximumBalanceForExpat AS VARCHAR(2)) + ' ALs a day).'

		RETURN
	END
	
	IF EXISTS (
			SELECT 1
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
			WHERE ISNULL(emp.ConfirmedDate, GETDATE() - 365) > @FromDate
				AND @CreditDays > 0
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Probation: no annual days.'

		RETURN
	END

	INSERT INTO dbo.LeaveTrans (
		EmpId
		,[Description]
		,FromDate
		,DeductDays
		,CreditDays
		,CreatedDate
		,CreatedBy
		)
	SELECT emp.EmpId
		,@Description
		,@FromDate
		,@DeductDays
		,@CreditDays
		,GETDATE()
		,@ActorId
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN #tblEmployeeIds AS empid ON emp.EmpId = empid.EmployeeId
	WHERE ISNULL(emp.isDeleted, 0) = 0

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK)
	SET AnnualLeaveBalance = ISNULL(AnnualLeaveBalance, 0) + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EXISTS (
			SELECT 1
			FROM #tblEmployeeIds
			WHERE EmpId = EmployeeId
			)
	
	DROP TABLE #tblEmployeeIds
END
go

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_InsertTransaction]
(
    @EmpId INT
	,@RequestId INT = NULL
	,@Description NVARCHAR(4000) = ''
	,@FromDate DATETIME
	,@ToDate DATETIME = NULL
	,@DeductDays NUMERIC(18, 1)
	,@CreditDays NUMERIC(18, 1)
	,@CreatedDate DATETIME
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-10-29
    Task: record leave transaction and calculate annual leave balance for employee
    DB: bodb_HRM

    Revisions:
        20250429@Tim: get RefResource by CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @CompanyId SMALLINT
        ,@maximumBalanceForLocal SMALLINT
		,@maximumBalanceForExpat SMALLINT

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

	SELECT @maximumBalanceForLocal = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'AnnualLeaveBalanceForLocal'

	SELECT @maximumBalanceForExpat = Value
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'AnnualLeaveBalanceForExpat'

	SET @maximumBalanceForLocal = ISNULL(@maximumBalanceForLocal, 0)
	SET @maximumBalanceForExpat = ISNULL(@maximumBalanceForExpat, 0)

	IF @maximumBalanceForLocal > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsLocal = 1
				AND @CreditDays > @maximumBalanceForLocal
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Local: ' + CAST(@maximumBalanceForLocal AS VARCHAR(2))

		RETURN
	END

	IF @maximumBalanceForExpat > 0
		AND EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsLocal = 0
				AND @CreditDays > @maximumBalanceForExpat
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Employees - Expat: no rules (only ' + + CAST(@maximumBalanceForExpat AS VARCHAR(2)) + ' ALs a day).'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.Employee WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND ISNULL(ConfirmedDate, GETDATE() - 365) > @FromDate
				AND @CreditDays > 0
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Probation: no annual days.'

		RETURN
	END

	INSERT INTO dbo.LeaveTrans (
		EmpId
		,RequestId
		,[Description]
		,FromDate
		,ToDate
		,DeductDays
		,CreditDays
        ,Deleted
		,CreatedDate
		,CreatedBy
		)
	VALUES (
		@EmpId
		,@RequestId
		,@Description
		,@FromDate
		,@ToDate
		,@DeductDays
		,@CreditDays
        ,0
		,@CreatedDate
		,@CreatedBy
		)

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK)
	SET AnnualLeaveBalance = ISNULL(AnnualLeaveBalance, 0) + ISNULL(@CreditDays, 0) - ISNULL(@DeductDays, 0)
	WHERE EmpId = @EmpId
END
go

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Auto_AnnualLeaveBalance_Update]
(
    @CompanyId SMALLINT
    ,@Year INT
	,@EmpId INT = NULL
	,@IsDelete BIT = 0
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tim.Trinh@2019-12-30
    Task: Update annual leave balance
    DB: bodb_HRM

    Revisions:
        20250429@Tim: get RefResource by CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Description NVARCHAR(100) = 'Create annual balance leave in ' + CONVERT(NVARCHAR(10), @Year) + '.'
	DECLARE @CreatedDate DATETIME = GETDATE()
		,@FromDate DATE = CONVERT(NVARCHAR(10), @Year) + '/01/01'
		,@ToDate DATE

	SELECT @ToDate = DATEADD(DAY, - 1, DATEADD(YEAR, 1, @FromDate))

	CREATE TABLE #tblEmployeeBalance (
		EmpId INT
		,Amount DECIMAL(5, 2)
		)

	CREATE TABLE #tblLengthOfServiceBalance (
		EmpId INT
		,JoinedDate DATE
		,WorkingDays INT
		,LengthOfService INT
		,Amount DECIMAL(5, 2)
		)

	INSERT INTO #tblEmployeeBalance (
		EmpId
		,Amount
		)
	SELECT emp.EmpId
		,CASE 
			WHEN empsum.IsLocal = 1 THEN ISNULL(gr.LocalBasicAnnualLeaveBalance, 0)
			ELSE ISNULL(gr.ExpatBasicAnnualLeaveBalance, 0)
			END
	FROM dbo.EmployeeSummary AS empsum WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
			AND ISNULL(emp.isDeleted, 0) = 0
			AND emp.[Enabled] = 1
			AND emp.ResignedDate IS NULL
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId AND gr.CompanyId = @CompanyId
	WHERE (
			(
				emp.JoinedDate IS NOT NULL
				AND emp.JoinedDate <= @FromDate
				)
			OR empsum.IsLocal = 0
			)
		AND (
			@EmpId IS NULL
			OR emp.EmpId = @EmpId
			)

	IF EXISTS (
			SELECT 1
			FROM dbo.RefResource WITH (NOLOCK)
			WHERE CompanyId = @CompanyId
                AND RefName = 'EnableAdditionalAnnualLeaveBalance'
				AND IsActive = 1
			)
	BEGIN
		INSERT INTO #tblLengthOfServiceBalance (
			EmpId
			,JoinedDate
			,WorkingDays
			,LengthOfService
			)
		SELECT emp.EmpId
			,emp.JoinedDate
			,empsum.WorkingDays
			,FLOOR((
					DATEDIFF(MONTH, emp.JoinedDate, @FromDate) - 1 - CASE 
					WHEN empsum.MilitaryFromDate IS NOT NULL
						AND empsum.MilitaryToDate IS NOT NULL THEN DATEDIFF(MONTH, empsum.MilitaryFromDate, empsum.MilitaryToDate)
					ELSE 0 END
					) / 12.0)
		FROM dbo.EmployeeSummary AS empsum WITH (NOLOCK)
			INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				AND ISNULL(emp.isDeleted, 0) = 0
				AND emp.[Enabled] = 1
				AND emp.ResignedDate IS NULL
		INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON c.EmpId = emp.EmpId AND c.CompanyId = @CompanyId
		WHERE emp.JoinedDate IS NOT NULL
			AND emp.JoinedDate <= @FromDate
			AND (
				@EmpId IS NULL
				OR emp.EmpId = @EmpId
				)
			AND empsum.IsLocal = 1

		UPDATE lsb
		SET lsb.Amount = CASE 
				WHEN lsb.WorkingDays = 15 THEN (
						(lsb.LengthOfService / 5) + CASE 
						WHEN lsb.LengthOfService % 5 = 4
							AND MONTH(lsb.JoinedDate) < 7 THEN 1
						ELSE 0 END
						) / 2.0
				ELSE (lsb.LengthOfService / 5) + CASE 
						WHEN lsb.LengthOfService % 5 = 4
							AND MONTH(lsb.JoinedDate) < 7 THEN 1
						ELSE 0
						END
				END
		FROM #tblLengthOfServiceBalance AS lsb WITH (ROWLOCK, UPDLOCK)
	END

	MERGE #tblEmployeeBalance AS [target]
	USING #tblLengthOfServiceBalance AS [source] ON ([target].EmpId = [source].EmpId)
	WHEN MATCHED THEN
			UPDATE
			SET [target].Amount = [target].Amount + [source].Amount
	WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				EmpId
				,Amount
				)
			VALUES (
				[source].EmpId
				,[source].Amount
				);

	DELETE
	FROM #tblEmployeeBalance
	WHERE Amount = 0

	IF @IsDelete = 1
	BEGIN
		UPDATE empsum
		SET AnnualLeaveBalance = empsum.AnnualLeaveBalance - lt.CreditDays
		FROM dbo.EmployeeSummary AS empsum WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.LeaveTrans AS lt WITH (NOLOCK) ON empsum.EmpId = lt.EmpId
				AND lt.FromDate = @FromDate
				AND ISNULL(lt.Deleted, 0) = 0
				AND lt.RequestId IS NULL
		WHERE EXISTS (
				SELECT 1
				FROM #tblEmployeeBalance AS tbl WITH (NOLOCK)
				WHERE empsum.EmpId = tbl.EmpId
				)

		DELETE lt
		FROM dbo.LeaveTrans AS lt
		WHERE lt.FromDate = @FromDate
			AND lt.CreditDays > 0
			AND lt.RequestId IS NULL
			AND EXISTS (
				SELECT 1
				FROM #tblEmployeeBalance AS tbl WITH (NOLOCK)
				WHERE lt.EmpId = tbl.EmpId
				)
	END

	UPDATE empsum
	SET empsum.AnnualLeaveBalance = empsum.AnnualLeaveBalance + emp.Amount
	FROM dbo.EmployeeSummary AS empsum WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblEmployeeBalance AS emp WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
			WHERE emp.EmpId = ltrans.EmpId
				AND YEAR(ltrans.FromDate) = @Year
				AND ltrans.DeductDays = 0
				AND ltrans.CreditDays > 0
				AND ltrans.RequestId IS NULL
				AND ltrans.Deleted = 0
			)

	INSERT INTO dbo.LeaveTrans (
		EmpId
		,[Description]
		,FromDate
		,ToDate
		,DeductDays
		,CreditDays
		,CreatedDate
		,CreatedBy
		,Deleted
		)
	SELECT EmpId
		,@Description
		,@FromDate
		,@ToDate
		,0 AS DeductDays
		,Amount AS CreditDays
		,@CreatedDate
		,NULL AS CreatedBy
		,0 AS Deleted
	FROM #tblEmployeeBalance AS tbl WITH (NOLOCK)
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.LeaveTrans AS ltrans WITH (NOLOCK)
			WHERE tbl.EmpId = ltrans.EmpId
				AND YEAR(ltrans.FromDate) = @Year
				AND ltrans.DeductDays = 0
				AND ltrans.CreditDays > 0
				AND ltrans.RequestId IS NULL
				AND ltrans.Deleted = 0
			)

	DROP TABLE #tblEmployeeBalance

	DROP TABLE #tblLengthOfServiceBalance
END
go

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_CheckHospitalizationLeaveBalance]
(
    @EmpId INT
	,@LeaveDays DECIMAL(18, 2) = NULL
	,@Year INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tim.Trinh@2021-08-25
    Task: check hospitalization leave balance
    DB: bodb_HRM

    Revisions:
        20250429@Tim: get RefResource by CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT @LeaveDays = ISNULL(@LeaveDays, 0)

	DECLARE @CompanyId SMALLINT
        ,@EnableHospitalizationLeaveBalance BIT = 0

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

	SELECT @EnableHospitalizationLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableHospitalizationLeaveBalance'

	IF @EnableHospitalizationLeaveBalance = 1
		AND @LeaveDays > 0
		AND @LeaveDays > dbo.fnc_GetHospitalizationLeaveBalance(@EmpId, @Year, NULL)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'You have not enough hospitalization leave days to request.'
	END
END
go

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_CheckSickLeaveBalance]
(
    @EmpId INT
	,@LeaveDays DECIMAL(18, 2) = NULL
	,@Year INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tim.Trinh@2021-08-25
    Task: check sick leave balance
    DB: bodb_HRM

    Revisions:
        20250429@Tim: get RefResource by CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT @LeaveDays = ISNULL(@LeaveDays, 0)

	DECLARE @CompanyId SMALLINT
        ,@EnableSickLeaveBalance BIT = 0

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

	SELECT @EnableSickLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableSickLeaveBalance'

	IF @EnableSickLeaveBalance = 1
		AND @LeaveDays > 0
		AND @LeaveDays > dbo.fnc_GetSickLeaveBalance(@EmpId, @Year, NULL)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'You have not enough sick leave days to request.'
	END
END
go

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SystemSetting_Get]
(
    @CompanyId SMALLINT
)
AS
/*
    Created: Tim.Trinh@2021-08-24
    Task: get system setting
    DB: bodb_HRM
    Original:

    Revisions:
        20250429@Tim: add param @CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EnableHospitalizationLeaveBalance BIT = 0
		,@EnableSickLeaveBalance BIT = 0

	SELECT @EnableHospitalizationLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableHospitalizationLeaveBalance'

	SELECT @EnableSickLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableSickLeaveBalance'

	SELECT @EnableHospitalizationLeaveBalance AS EnableHospitalizationLeaveBalance
		,@EnableSickLeaveBalance AS EnableSickLeaveBalance
END
go

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[fnc_GetAnnualLeaveBalanceByDate] (
	@EmpId INT
	,@Date DATETIME
	,@RequestId BIGINT = NULL
)
RETURNS NUMERIC(18, 2)
/*
	Created:
	Task: get AL balance
	DB: bodb_HRM

	Revisions:
        20250429@Tim: get RefResource by CompanyId
	Param's Explanation:
*/
AS
BEGIN
	DECLARE @CompanyId SMALLINT
        ,@LeaveBalanceDay NUMERIC(18, 2)
		,@OutstandingLeaveDay NUMERIC(18, 2)
		,@MaxMonth INT
		,@CurrentAnnualLeaveCanBeUse NUMERIC(18, 2)
		,@MaxCanBeUseInYear NUMERIC(18, 2)
		,@IsUserHave6DaysAL BIT
		,@Today DATE = GETDATE()

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

	SELECT @IsUserHave6DaysAL = CASE 
			WHEN WorkingDays = 15 THEN 1
			ELSE 0
			END
	FROM dbo.EmployeeSummary WITH (NOLOCK)
	WHERE EmpId = @EmpID

	IF YEAR(@Today) = YEAR(@Date)
	BEGIN
		SET @Date = CASE 
				WHEN DATEDIFF(MM, @Date, @Today) > 0 THEN @Today
				ELSE @Date END
	END

	SELECT @LeaveBalanceDay = SUM(ISNULL(CreditDays, 0)) - SUM(ISNULL(DeductDays, 0))
	FROM dbo.LeaveTrans WITH (NOLOCK)
	WHERE EmpId = @EmpId
		AND YEAR(FromDate) = YEAR(@Date)
		AND ISNULL(Deleted, 0) <> 1

	SELECT @OutstandingLeaveDay = SUM(ISNULL(tmp.TOTALDAYS, 0))
	FROM dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
		INNER JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON tmp.EmpId = lr.EmpId
		AND tmp.RequestId = lr.RequestId
	WHERE tmp.EmpId = @EmpId
		AND tmp.[Status] = 0
		AND tmp.InYear = YEAR(@Date)
		AND (
			@RequestId IS NULL
			OR tmp.RequestID <> @RequestId
			)

	SELECT @MaxCanBeUseInYear = ISNULL(@LeaveBalanceDay, 0) - ISNULL(@OutstandingLeaveDay, 0)

	IF EXISTS (
			SELECT 1
			FROM dbo.RefResource WITH (NOLOCK)
			WHERE CompanyId = @CompanyId
                AND RefName = 'LimitUseAnnualLeaveBalance'
				AND Value = '0'
				AND IsActive = 1
			)
	BEGIN
		RETURN ISNULL(@MaxCanBeUseInYear, 0)
	END

	IF @IsUserHave6DaysAL = 1
	BEGIN
		SELECT @MaxCanBeUseInYear = @MaxCanBeUseInYear * 2
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmpId
				AND IsLocal = 1
			)
	BEGIN
		SELECT @MaxMonth = MAX(InMonth)
		FROM dbo.tmpLeaveBalance WITH (NOLOCK)
		WHERE EmpId = @EmpId
			AND [Status] IN (0, 1)
			AND InYear = YEAR(@Date)
			AND (
				@RequestId IS NULL
				OR RequestID <> @RequestId
				)

		SELECT @MaxMonth = CASE 
				WHEN @MaxMonth > MONTH(@Date) THEN @MaxMonth
				ELSE MONTH(@Date)
				END

		SELECT @CurrentAnnualLeaveCanBeUse = @MaxCanBeUseInYear - 7 + (CASE 
				WHEN @MaxMonth > 7 THEN 7
				ELSE @MaxMonth END
				)

		IF @CurrentAnnualLeaveCanBeUse <= 0
		BEGIN
			SET @LeaveBalanceDay = 0
		END
		ELSE
		BEGIN
			SELECT @LeaveBalanceDay = SUM(ISNULL(CreditDays, 0)) - SUM(ISNULL(DeductDays, 0))
			FROM dbo.LeaveTrans WITH (NOLOCK)
			WHERE EmpID = @EmpID
				AND YEAR(FromDate) = YEAR(@Date)
				AND MONTH(FromDate) <= MONTH(@Date)
				AND ISNULL(Deleted, 0) <> 1

			SELECT @OutstandingLeaveDay = SUM(ISNULL(tmp.TOTALDAYS, 0))
			FROM dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
				LEFT JOIN dbo.LeaveRequest AS lr WITH (NOLOCK) ON tmp.EmpId = lr.EmpId
				AND tmp.RequestID = lr.RequestId
			WHERE tmp.EmpId = @EmpId
				AND tmp.[Status] = 0
				AND tmp.InYear = YEAR(@Date)
				AND InMonth <= MONTH(@Date)
				AND (
					@RequestId IS NULL
					OR tmp.RequestID <> @RequestId
					)

			SELECT @LeaveBalanceDay = ISNULL(@LeaveBalanceDay, 0) - ISNULL(@OutstandingLeaveDay, 0)

			IF @IsUserHave6DaysAL = 1
			BEGIN
				SELECT @LeaveBalanceDay = @LeaveBalanceDay * 2
			END

			SELECT @CurrentAnnualLeaveCanBeUse = @LeaveBalanceDay - 7 + (CASE 
					WHEN MONTH(@Date) > 7 THEN 7
					ELSE MONTH(@Date) END
					)

			IF @CurrentAnnualLeaveCanBeUse <= 0
			BEGIN
				SET @LeaveBalanceDay = 0
			END
			ELSE IF @CurrentAnnualLeaveCanBeUse > @MaxCanBeUseInYear
			BEGIN
				SET @LeaveBalanceDay = @MaxCanBeUseInYear
			END
			ELSE
			BEGIN
				SET @LeaveBalanceDay = @CurrentAnnualLeaveCanBeUse
			END
		END
	END
	ELSE
	BEGIN
		SET @LeaveBalanceDay = @MaxCanBeUseInYear
	END

	IF @IsUserHave6DaysAL = 1
	BEGIN
		SELECT @LeaveBalanceDay = @LeaveBalanceDay / 2.0
	END

	RETURN ISNULL(@LeaveBalanceDay, 0)
END

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LookupData_JobTitle_SELECT]
	@JobTitle NVARCHAR(100)	= '',
	@CompanyId INT
AS
/*
Created: Tom.Vo@2013-10-29
Task: Get Job Title
DB: HRM_SMS
Original: 

Revisions: 
	20250425@Mira: correct SP get job titile [Redmine: #224577]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @lookupId INT
	SELECT @lookupId = Id FROM dbo.[Lookup] WITH (NOLOCK) WHERE Code ='JT'

	IF @JobTitle IS NULL
		SET @JobTitle = ''
	
	IF @JobTitle <> ''
		SELECT l.Id,
				l.LookupId,
				l.Code,
				l.Name,
				SUM(CASE WHEN esum.IsLocal IS NOT NULL THEN 1 ELSE 0 END) AS Value,
				SUM(CASE WHEN esum.IsLocal = 1 THEN 1 ELSE 0 END) TotalLocal,
				SUM(CASE WHEN esum.IsLocal = 0 THEN 1 ELSE 0 END) TotalExpat,
				CAST(ISNULL(l.Value, 0) AS INT) AS CategoryId
		FROM dbo.LookupData AS l WITH(NOLOCK)
		LEFT JOIN dbo.Employee AS e WITH(NOLOCK) 
			ON l.Id=e.JobTitleId
				AND (e.isDeleted IS NULL OR e.isDeleted = 0)
				AND e.Enabled = 1
		LEFT JOIN dbo.EmployeeSummary esum WITH (NOLOCK) ON esum.EmpId = e.EmpId
		WHERE LookupId = @lookupId
			AND l.CompanyId = @CompanyId
			AND l.Name LIKE '%'+ @JobTitle +'%'			
		GROUP BY l.LookupId,l.id,l.Code,l.Name,l.Value
		ORDER BY l.[Name]
	ELSE
		SELECT l.Id,
				l.LookupId,
				l.Code,
				l.Name,
				SUM(CASE WHEN esum.IsLocal IS NOT NULL THEN 1 ELSE 0 END) AS Value,
				SUM(CASE WHEN esum.IsLocal = 1 THEN 1 ELSE 0 END) TotalLocal,
				SUM(CASE WHEN esum.IsLocal = 0 THEN 1 ELSE 0 END) TotalExpat,
				CAST(ISNULL(l.Value, 0) AS INT) AS CategoryId
		FROM dbo.LookupData AS l WITH(NOLOCK)
		LEFT JOIN dbo.Employee AS e WITH(NOLOCK) 
			ON l.Id=e.JobTitleId
				AND (e.isDeleted IS NULL OR e.isDeleted = 0)
				AND e.Enabled = 1	
		
		LEFT JOIN dbo.EmployeeSummary esum WITH (NOLOCK) ON esum.EmpId = e.EmpId
		WHERE LookupId = @lookupId AND l.CompanyId = @CompanyId
		GROUP BY l.LookupId,l.id,l.Code,l.Name,l.Value
		ORDER BY l.[Name]
END