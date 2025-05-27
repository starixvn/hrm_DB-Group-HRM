/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[CompanySecondmentEmployee_Delete]
  @EmpId INT,
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

    DELETE FROM dbo.CompanySecondmentEmployee
    WHERE EmpId = @EmpId;

    SET @ErrCode = 0;
    SET @ErrMsg = 'Success';
END
GO
