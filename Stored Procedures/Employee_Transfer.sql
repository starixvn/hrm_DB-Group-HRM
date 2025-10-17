/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Transfer]
(
    @EmpId INT,
    @GroupId INT,
    @TargetCompanyId SMALLINT,
	@Remark NVARCHAR(1000),
	@CreatedBy INT,
	@TransferInDate DATE,
	@AnnualLeaveBalance NUMERIC(18, 2),
	@CompensationLeaveBalance NUMERIC(18, 2),
	@ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Mira
    Task: Employee Transfer
    DB: bodb_HRM

    Revisions:
		20251010@Mira: transfer employee [Redmine: #233310]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
    BEGIN TRANSACTION;

	DECLARE @CompanyId SMALLINT; -- Current company
	DECLARE @NewEmpId INT, @UserId INT;
	   
	-- Disable EmpId in current company
	DECLARE @xml XML = (SELECT 1 AS '@Enabled' FOR XML PATH('Row'),TYPE);
	DECLARE @logOldData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

	UPDATE CompanyEmployee WITH (ROWLOCK)
	SET Enabled = 0
	WHERE EmpId = @EmpId;

	SET @xml = (SELECT 0 AS '@Enabled' FOR XML PATH('Row'),TYPE);
	DECLARE @logData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');
	-- Log activity
	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 1
		,@ObjectId = @EmpId
		,@OldData = @logOldData
		,@Data = @logData

	SELECT @CompanyId = ce.CompanyId,
		@UserId = ce.UserId
    FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
	WHERE ce.EmpId = @EmpId;	

	-- Check exist UserId and TargetCompanyId
	SELECT @NewEmpId = EmpId
	FROM bodb_HRM.dbo.CompanyEmployee WITH (NOLOCK)
	WHERE UserId = @UserId AND CompanyId = @TargetCompanyId;

	IF @NewEmpId IS NOT NULL
	BEGIN
		UPDATE a
		SET 
			a.IsDeleted = 0,
			a.Enabled = 1,
			a.GroupId = @GroupId,
			a.Roles = b.Roles,
			a.CompanyDate = @TransferInDate
		FROM bodb_HRM.dbo.CompanyEmployee AS a WITH (ROWLOCK)
		INNER JOIN bodb_HRM.dbo.CompanyEmployee AS b 
			ON a.EmpId = b.EmpId AND b.CompanyId = @CompanyId
		WHERE a.EmpId = @NewEmpId;
	END
	ELSE
	BEGIN
		SELECT @NewEmpId = MAX(ce.EmpId) + 1	
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK);

		-- Add new employee
		INSERT INTO dbo.CompanyEmployee (
			EmpId
			,CompanyId
			,UserId
			,isDeleted
			,[Enabled]
			,GroupId
			,CreatedDate
			,CreatedBy
			)
		VALUES (
			@NewEmpId
			,@TargetCompanyId
			,@UserId
			,0
			,1
			,@GroupId
			,GETDATE()
			,@CreatedBy
			)

		INSERT INTO dbo.EmployeeSummary (EmpId, IsDefaultSchedule)
		VALUES (@NewEmpId, 0)

		INSERT INTO dbo.EmployeeContract (EmpId)
		VALUES (@NewEmpId)

		INSERT INTO dbo.EmployeeDefaultShift (EmpId)
		VALUES (@NewEmpId)

		EXEC dbo.AnnualLeave_InsertMultipleTransactions -- insert annual leave balance
			@CompanyId = @TargetCompanyId
			,@EmployeeIds = @NewEmpId
			,@FromDate = @TransferInDate
			,@DeductDays = 0
			,@CreditDays = @AnnualLeaveBalance
			,@ActorId = @CreatedBy
			,@ErrCode = @ErrCode
			,@ErrMsg = @ErrMsg

		--Insert Compensation Leave
		INSERT INTO dbo.KeepInViewByDayTrans (
			EmpId
			,RequestId
			,CreditDays
			,DeductDays
			,InYear
			,InsertedDate
			)
		VALUES (
			@NewEmpId
			,-1
			,@CompensationLeaveBalance
			,0
			,YEAR(@TransferInDate)
			,GETDATE()
			)
	END

	-- Insert into Employee Transfer with new EmpId
	INSERT INTO EmployeeTransfer (
		FromEmpId,
		ToEmpId,
		TransferOutDate,
		TransferInDate,
		Remark,
		ModifiedBy
	)
	VALUES(
		@EmpId,
		@NewEmpId,
		DATEADD(DAY, -1, @TransferInDate),
		@TransferInDate,
		@Remark,
		@CreatedBy
	);

	DECLARE @CurrentCompany NVARCHAR(50) = (SELECT [Name] FROM dbo.Company ce WITH(NOLOCK) WHERE ce.CompanyId = @CompanyId);
	DECLARE @TargetCompany NVARCHAR(50) = (SELECT [Name] FROM dbo.Company ce WITH(NOLOCK) WHERE ce.CompanyId = @TargetCompanyId);
	-- Insert History work
	INSERT INTO [dbo].[HistoryWork]
		([EmpId]
		,[Field]
		,[LogDate]
		,[OldValue]
		,[Value]
		,[ModifiedBy])
	VALUES
		(@EmpId, 'Company', DATEADD(DAY, -1, @TransferInDate), @CurrentCompany, @TargetCompany, @CreatedBy),
		(@NewEmpId, 'Company', @TransferInDate, @CurrentCompany, @TargetCompany, @CreatedBy);

	SELECT @NewEmpId AS NewEmpId;

	COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SELECT @ErrCode = 1
            ,@ErrMsg = N'Employee transfer failed: ' + ERROR_MESSAGE();
    END CATCH
END