/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


CREATE PROCEDURE [dbo].[SyncEPA_JobTitle_Get]
	@CompanyId INT
AS
/*
Created: 20150827@Quinn.Vo
Task: Get all Job Title.
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT CASE WHEN OldId IS NOT NULL THEN OldId ELSE Id END AS Id
		,LookupId
		,Code
		,NAME
		,Value
	FROM dbo.LookupData WITH (NOLOCK)
	WHERE LookupId = 1 AND CompanyId = @CompanyId
	ORDER BY Id
END







