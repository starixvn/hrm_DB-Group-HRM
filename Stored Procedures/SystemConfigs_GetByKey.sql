/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SystemConfigs_GetByKey] @CompanyId SMALLINT
    ,@Key VARCHAR(30)
AS
/*
Created: 20241128@Lilac.Nguyen
Task: get system configs
DB: HRM
Original:

Revisions:
    20250305@Tim: get data by company - [Redmine: #217976]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT [Value]
	FROM dbo.[SystemConfigs] AS c WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND [Key] = @Key
END