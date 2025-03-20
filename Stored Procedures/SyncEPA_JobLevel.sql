/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SyncEPA_JobLevel] @FromDate DATETIME = NULL
AS
/*
Created: 20210426@Lilac.Nguyen
Task: Get all job level from change date
DB: SMSHRM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT JobLevelId
		,[Name]
		,IsDeleted
		,ModifiedDate
	FROM JobLevel WITH (NOLOCK)
	WHERE @FromDate IS NULL
		OR ModifiedDate > @FromDate

END













