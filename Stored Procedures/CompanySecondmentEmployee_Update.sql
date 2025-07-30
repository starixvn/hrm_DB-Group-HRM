/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE[dbo].[CompanySecondmentEmployee_Update]
  @EmpId INT,
  @OldEmpId INT = NULL,
  @CompanyId INT,
  @ModifiedBy INT,
  @ErrCode INT = 0 OUTPUT,
  @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Update secondment employee
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentCompanyId INT;
    DECLARE @ExistingEmpId INT;
    

    SELECT @CurrentCompanyId = CompanyId 
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId;

    IF @CurrentCompanyId = @CompanyId
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'Cannot set secondment company to their current company. Please select a different company.';
        RETURN;
    END

    -- Check for duplicate secondment records
    IF EXISTS (
        SELECT 1
        FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
        WHERE EmpId = @EmpId
        AND (@OldEmpId IS NULL OR EmpId <> @OldEmpId)
    )
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'Employee already exists in secondment records.';
        RETURN;
    END

    DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

    SET @xml = (
        SELECT EmpId AS '@EmpId'
            ,CompanyId as '@CompanyId'
        FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
        WHERE EmpId = @EmpId
        FOR XML PATH('Row')
            ,TYPE
    )
    SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

    -- If OldEmpId is provided and different from EmpId, update the old record
    IF @OldEmpId IS NOT NULL AND @OldEmpId <> @EmpId
    BEGIN
        UPDATE dbo.CompanySecondmentEmployee
        SET EmpId = @EmpId,
            CompanyId = @CompanyId,
            ModifiedBy = @ModifiedBy,
            ModifiedDate = GETDATE()
        WHERE EmpId = @OldEmpId;
    END
    ELSE
    BEGIN
        -- Update existing record
        UPDATE dbo.CompanySecondmentEmployee
        SET CompanyId = @CompanyId,
            ModifiedBy = @ModifiedBy,
            ModifiedDate = GETDATE()
        WHERE EmpId = @EmpId;
    END

    SET @xml = (
    SELECT EmpId AS '@EmpId'
        ,CompanyId as '@CompanyId'
    FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId
    FOR XML PATH('Row')
        ,TYPE
    )
    SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

    EXEC dbo.ActivityLog_Insert
		 @ObjectTypeId = 3
		,@ObjectId = @EmpId
        ,@UserId = @ModifiedBy
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END

GO
