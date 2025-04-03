/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Department_Get] @IsActive BIT = NULL
AS
/*
Created: 20200521@Lilac.Nguyen
Task: get department
DB: HRM

Revisions:
    20250403@Tim: remove param CompanyId [Redmine: #222886]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT dep.DepartmentId AS Id
		,dep.Code
		,dep.[Name]
		,dep.IsActive
		,u.UnitId
        ,u.Code
		,u.[Name]
	FROM dbo.Department AS dep WITH (NOLOCK)
		LEFT JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
	WHERE (@IsActive IS NULL OR dep.IsActive = @IsActive)
		AND dep.IsDeleted = 0
END