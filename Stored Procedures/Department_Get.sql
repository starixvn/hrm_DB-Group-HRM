/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Department_Get] @IsActive BIT = NULL,
	@UnitId INT = NULL
AS
/*
Created: 20200521@Lilac.Nguyen
Task: get department
DB: HRM

Revisions:
    20250403@Tim: remove param CompanyId [Redmine: #222886]
	20250421@Mira: add new Deparment - new structure [Redmine: #221568]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT dep.DepartmentId AS Id
		,dep.GroupDeptId
		,dep.Code
		,dep.[Name]
		,dep.IsActive
		,dep.AccountableArea
		,e.NickName 'PICEmployeeName'
		,u.UnitId
        ,u.Code
		,u.[Name]
	FROM dbo.Department AS dep WITH (NOLOCK)
		LEFT JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON dep.PICEmpId = e.EmpId
	WHERE (@IsActive IS NULL OR dep.IsActive = @IsActive)
		AND dep.IsDeleted = 0
		AND (@UnitId IS NULL OR u.UnitId = @UnitId)
END