/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Memo_Update] @Id INT
	,@RefNo NVARCHAR(50)
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
	UPDATE MEMO WITH (ROWLOCK, UPDLOCK)
	SET RefNo = @RefNo
		,Contents = @Contents
		,Subject = @Subject
		,SentTo = @SentTo
		,SentFrom = @SentFrom
		,ForInfo = @ForInfo
		,TotalPages = @TotalPages
		,SentDate = @SentDate
		,Category = @Category
		,[Type] = @Type
	WHERE Id = @Id AND CompanyId = @CompanyId

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Update Memo failed.';
	END;
	ELSE
	BEGIN
		SELECT @ErrCode = 0
			,@ErrMsg = '';
	END;
END


