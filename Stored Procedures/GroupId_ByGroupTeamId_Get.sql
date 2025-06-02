/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[GroupId_ByGroupTeamId_Get] @GroupTeamId VARCHAR(50)
AS
/*
Created: 20250528@Jay.Do
Task: get group id by group team id
DB: HRM_SMS
Original:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	SELECT TOP 1 GroupId
	FROM [Group]
	WHERE GroupTeamId = @GroupTeamId
END