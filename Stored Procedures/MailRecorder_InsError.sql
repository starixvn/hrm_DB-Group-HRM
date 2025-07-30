/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[MailRecorder_InsError]	
	@MailId bigint,
	@AppId int = 0,
	@Message varchar(1000) = '',
	@StackTrace varchar(2000) = '',
	@ErrorTime datetime = NULL,
	@ErrorId int = 0 output,
	@ErrCode int = 0 Output,
	@ErrMsg nvarchar(200) = '' Output
AS
/*
Created: 07/10/2013 @Ricky
Task : Insert new mail error
DB: HRM
Original:

Revisions:
*/
BEGIN
    SET NOCOUNT ON;

	DECLARE @SettingName nvarchar(250)
	SELECT TOP 1 @SettingName = s.SettingName
	FROM dbo.Mail_Setting AS s
        INNER JOIN dbo.Mail_Config AS c ON c.AppId = @AppId and c.SettingId = s.SettingId

	INSERT INTO dbo.Mail_Error([MailId], [AppId], [Message], [StackTrace], [SettingName], [ErrorTime])
	VALUES (@MailId, @AppId, @Message , @StackTrace, @SettingName, @ErrorTime)

	IF @@Error <> 0
	BEGIN			
		SELECT @ErrMsg = 'Error! Error when inserting mail error;', @ErrCode = 101			
		RETURN
	END

	SELECT @ErrorId = @@IDENTITY
END