/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


ALTER PROCEDURE [dbo].[ExtensionNO_Insert_GroupExternal] @FullName NVARCHAR(200)
	,@CompanyId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2014-01-04
Task: Insert external group
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
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Group name has already existed.'

		RETURN
	END

	DECLARE @TeamId INT

	INSERT INTO dbo.ExtensionNumbers (
		FullName
		,NickName
		,ExtensionNo
		,IsInternal
		,IsGroup
		,EmpId
		,GroupId
		,OrderNo
		,CompanyId
		)
	SELECT @FullName
		,@FullName
		,'' AS ExtensionNo
		,0 AS IsInternal
		,1 AS IsGroup
		,NULL AS EmpId
		,NULL AS GroupId
		,MAX(OrderNo)
		,@CompanyId
	FROM dbo.ExtensionNumbers WITH (NOLOCK)
	WHERE GroupId <> @TeamId
		AND IsInternal = 1

	SET @TeamId = SCOPE_IDENTITY()

	UPDATE dbo.ExtensionNumbers WITH (ROWLOCK, UPDLOCK)
	SET GroupId = @TeamId
	WHERE ExtId = @TeamId
END




