/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


CREATE PROCEDURE [dbo].[SyncEPA_JobTitle_Get]
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

	SELECT Id
		,LookupId
		,Code
		,NAME
		,Value
	FROM dbo.LookupData WITH (NOLOCK)
	WHERE LookupId = 1
END







