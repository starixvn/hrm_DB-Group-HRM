/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ExtensionNO_Update_GroupExternal] @ExtId INT
	,@FullName NVARCHAR(200)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2014-01-04
Task: Update external group
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.ExtensionNumbers WITH (NOLOCK)
			WHERE FullName = @FullName
				AND IsGroup = 1
				AND IsInternal = 0
				AND ExtId <> @ExtId
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Group name has already existed.'

		RETURN
	END

	UPDATE dbo.ExtensionNumbers WITH (ROWLOCK, UPDLOCK)
	SET FullName = @FullName
		,NickName = @FullName
	WHERE ExtId = @ExtId
		AND IsGroup = 1
		AND IsInternal = 0
END



