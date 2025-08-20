/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Delete] @TeamId INT
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-10-23
Task: Delete Group 
DB: HRM_SMS
Original:

Revisions:
	20250820@Lilac: restructure for transfer [Redmine: #235678] 
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] AS gr WITH (NOLOCK)
				INNER JOIN dbo.CompanyEmployee AS emp WITH (NOLOCK) ON gr.GroupId = emp.GroupId
			WHERE gr.GroupId =  @TeamId
				AND emp.isDeleted = 0
				AND emp.[Enabled] = 1
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'The team is not empty so cannot delete it'

		RETURN
	END

	UPDATE dbo.[Group] WITH (ROWLOCK, UPDLOCK)
	SET IsDeleted = 1
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
	WHERE GroupId =  @TeamId
END