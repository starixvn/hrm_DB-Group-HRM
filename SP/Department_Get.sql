/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Department_Get]
	@IsActive BIT = NULL,
	@CompanyId SMALLINT
AS
/*
Created: 20200521@Lilac.Nguyen
Task: get department by active
DB: HRM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT dep.DepartmentId AS Id
		,dep.Code
		,dep.Name
		,dep.IsActive
		,u.UnitId
		,u.Name
	FROM dbo.Department AS dep WITH (NOLOCK)
		LEFT JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
	WHERE (dep.IsActive = @IsActive OR @IsActive IS NULL)
		AND dep.CompanyId = @CompanyId
		AND dep.IsDeleted = 0

END
