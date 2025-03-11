/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[MailRecorder_GetConfig]
	@AppID int,
	@ErrCode int = 0 Output,
	@ErrMsg nvarchar(200) = '' Output
AS
/*
Created: 09/29/2011@Bobby
Task : select mail configuration
DB: HRM

Revisions:
*/
BEGIN
    SET NOCOUNT ON;

	SELECT mc.AppId
		,mc.AppName
		,mc.[Description]
		,mc.MailFrom
		,mc.IsEncrypt
		,ms.SettingId
		,ms.SettingName
		,ms.IsAuth
		,ms.Username
		,ms.[Password]
		,ms.[Server]
		,ms.[Port]
	FROM dbo.Mail_Config as mc WITH(NOLOCK)
		LEFT JOIN dbo.Mail_Setting as ms WITH(NOLOCK) ON mc.SettingId = ms.SettingId
	WHERE mc.AppId = @AppId 
END