/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Memo_Insert] @RefNo NVARCHAR(50)
	,@Contents NVARCHAR(max)
	,@Subject NVARCHAR(4000)
	,@SentTo NVARCHAR(1000)
	,@SentFrom NVARCHAR(1000)
	,@ForInfo NVARCHAR(1000) = ''
	,@TotalPages INT
	,@SentDate DATETIME
	,@Category INT
	,@Type INT
	,@CompanyId INT
	,@id INT OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-10-23
Task: Update Memo
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO MEMO (
		RefNo
		,Contents
		,Subject
		,SentTo
		,SentFrom
		,ForInfo
		,TotalPages
		,SentDate
		,Category
		,[Type]
		,Enabled
		,CompanyId
		)
	VALUES (
		@RefNo
		,@Contents
		,@Subject
		,@SentTo
		,@SentFrom
		,@ForInfo
		,@TotalPages
		,@SentDate
		,@Category
		,@Type
		,1
		,@CompanyId
		)


	IF @@ERROR <> 0
	BEGIN
		SET @id = 0

		SELECT @ErrCode = 1
			,@ErrMsg = N'Create Memo failed.';
	END
	ELSE
	BEGIN
		SET @id = cast(SCOPE_IDENTITY() AS INT)

		SELECT @ErrCode = 0
			,@ErrMsg = '';
	END

	SELECT @id
END


