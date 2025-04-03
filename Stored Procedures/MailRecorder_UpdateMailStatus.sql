/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[MailRecorder_UpdateMailStatus]	
	@MailId bigint,
	@Status bit,
	@MailUpdatedDate datetime,
	@ErrCode int = 0 Output,
	@ErrMsg nvarchar(200) = '' Output
AS
/*
Created: 09/20/2012 @Ricky
Task : Update Mail Status
DB: HRM
Original:

Revisions:
*/
BEGIN
    UPDATE dbo.Mail_Record with (ROWLOCK, UPDLOCK)
    SET SentSuccess = 0
    WHERE MailId=@MailId and SentSuccess is NULL

    UPDATE dbo.Mail_Record with (ROWLOCK, UPDLOCK)
    SET SentFail = 0
    WHERE MailId=@MailId and SentFail is NULL

    IF @Status > 0
    BEGIN
	    UPDATE dbo.Mail_Record with (ROWLOCK, UPDLOCK)
	    SET SentSuccess = isnull(SentSuccess,0) + 1, MailUpdatedDate = @MailUpdatedDate
	    WHERE MailId=@MailId
	    IF @@Error <> 0
	    BEGIN			
		    SELECT @ErrMsg = 'Error! Error when updating count mail.', @ErrCode = 101			
		    RETURN
	    END
    END
    ELSE
    BEGIN
	    UPDATE dbo.Mail_Record with (ROWLOCK, UPDLOCK)
	    SET SentFail = isnull(SentFail,0) + 1,  MailUpdatedDate = @MailUpdatedDate
	    WHERE MailId=@MailId
	    IF @@Error <> 0
	    BEGIN			
		    SELECT @ErrMsg = 'Error! Error when updating count mail.', @ErrCode = 101			
		    RETURN
	    END
    END
END