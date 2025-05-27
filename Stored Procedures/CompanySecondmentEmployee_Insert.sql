/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[CompanySecondmentEmployee_Insert]
  @EmpId INT,
  @CompanyId INT,
  @CreatedBy INT,
  @ErrCode INT = 0 OUTPUT,
  @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Insert secondment employee
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentCompanyId INT;

    SELECT @CurrentCompanyId = CompanyId 
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId;

    IF @CurrentCompanyId = @CompanyId
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'Cannot set secondment company to their current company';
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
        WHERE EmpId = @EmpId
    )
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'Employee is already seconded to another company';
        RETURN;
    END

    INSERT INTO dbo.CompanySecondmentEmployee (EmpId, CompanyId, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
    VALUES (@EmpId, @CompanyId, @CreatedBy, GETDATE(), @CreatedBy, GETDATE());

    SET @ErrCode = 0;
    SET @ErrMsg = 'Success';
END
GO
