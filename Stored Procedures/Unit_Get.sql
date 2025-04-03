/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_Get] @IsActive BIT = NULL
AS
/*
Created: 20200521@Patsy.Doan
Task: Get unit.
DB: HRM

Revisions:
    20250403@Tim: remove param CompanyId [Redmine: #222886]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	SELECT u.UnitId
		,u.Code
		,u.[Name]
		,u.IsActive
		,u.ModifiedDate
	FROM dbo.Unit AS u WITH (NOLOCK)
	WHERE (
			@IsActive IS NULL
			OR u.IsActive = @IsActive
			)
			AND u.IsDeleted = 0
	ORDER BY u.Code
END