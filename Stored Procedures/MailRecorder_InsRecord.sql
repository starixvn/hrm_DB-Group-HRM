/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[MailRecorder_InsRecord]
	@AppId INT,
	@FuncId	INT,
	@MailTo	NVARCHAR(250),	
	@Title NVARCHAR(250) = '',
	@Subject NVARCHAR(250),
	@Body NTEXT,
	@MailCc	NVARCHAR(1000) = '',
	@MailBcc NVARCHAR(250) = '',
	@MailDate DATETIME,
	@Attachments NVARCHAR(250),
	@IsEncrypt BIT	= 0,
	@MailId	INT	= 0	OUTPUT,
	@ErrCode INT	= 0	OUTPUT,
	@ErrMsg	NVARCHAR(200) = '' OUTPUT	
AS
/*
Created: 09/29/2011@Bobby
Task : Insert new mail record
DB: HRM
Original:

Revisions:
*/
BEGIN
    SET NOCOUNT ON;

    IF @AppId > 0
    BEGIN
	    DECLARE @tempIsEncrypt BIT
	    SET @tempIsEncrypt = 0
	
	    SELECT @tempIsEncrypt = IsEncrypt 
	    FROM dbo.Mail_Config WITH (NOLOCK)
	    WHERE AppId = @AppId
	
	    SELECT @IsEncrypt = CASE WHEN @tempIsEncrypt = 1 THEN 1 ELSE @IsEncrypt END					

	    INSERT INTO dbo.Mail_Record(
		    AppId
		    ,FuncId
		    ,MailTo
		    ,Title
		    ,Subject
		    ,Body
		    ,MailCc
		    ,MailBcc
		    ,MailDate
		    ,Attachments
		    ,IsEncrypt)
	    VALUES (
		    @AppId
		    ,@FuncId
		    ,@MailTo
		    ,N'' + @Title + ''
		    ,N'' + @Subject + ''
		    ,@Body
		    ,N'' + @MailCc + ''
		    ,N'' + @MailBcc + ''
		    ,@MailDate
		    ,N'' + @Attachments + ''
		    ,@IsEncrypt)

	    IF @@Error <> 0
	    BEGIN			
		    SELECT @ErrMsg = 'Error! Error when inserting mail record ;', @ErrCode = 101			
		    RETURN
	    END
	
	    SELECT @MailId = @@IDENTITY
    END
END