/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[CompanySecondmentEmployee_Delete]
  @EmpId INT,
  @ModifiedBy INT,
  @ErrCode INT = 0 OUTPUT,
  @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Delete secondment employee
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

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


    DELETE FROM dbo.CompanySecondmentEmployee
    WHERE EmpId = @EmpId;

    EXEC dbo.ActivityLog_Insert
		@UserId = @ModifiedBy
		,@ObjectTypeId = 3
		,@ObjectId = @EmpId
		,@OldData = @logOldData
		,@Data = NULL
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

END
GO
