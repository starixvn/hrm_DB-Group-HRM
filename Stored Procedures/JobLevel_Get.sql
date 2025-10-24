/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[JobLevel_Get]
AS
/*
Created: 20210420@Lilac.Nguyen
Task: get joblevel
DB: HRM
Original: 

Revisions:  
	20251021@Jay.Do: sort job level [#241812]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT JobLevelId AS Id
		,[Name]
	FROM dbo.JobLevel WITH (NOLOCK)
	WHERE IsDeleted = 0
	ORDER BY
		LEFT([Name], CHARINDEX('-', [Name] + '-') - 1) ASC,
		SUBSTRING([Name], CHARINDEX('-', [Name] + '-') + 1, LEN([Name])) DESC;
END