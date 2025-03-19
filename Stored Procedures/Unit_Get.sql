/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_Get] 
	@IsActive BIT = NULL,
	@CompanyId SMALLINT
AS
/*
Created: 20200521@Patsy.Doan
Task: Get unit.
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	SELECT u.UnitId
		,u.Code
		,u.Name
		,u.IsActive
		,u.ModifiedDate
	FROM dbo.Unit as u WITH (NOLOCK)
	WHERE (
			@IsActive IS NULL
			OR u.IsActive = @IsActive
			)
			AND u.CompanyId = @CompanyId
			AND U.IsDeleted = 0
	ORDER BY u.Code
END



