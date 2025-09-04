/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Department_GetById]
	@Id INT
AS
/*
Created: 20200521@Lilac.Nguyen
Task: get department by id
DB: HRM
Original: 

Revisions:  
	20250421@Mira: edit Deparment - new structure [Redmine: #221568]
	20250903@Jay: update role [Redmine: #237201]

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT dep.DepartmentId AS Id
	,dep.Code
	,dep.Name
	,dep.IsActive
	,dep.AccountableArea
	,dep.GroupDeptId
	,dep.PICEmpId
	,dep.SupporterEmpId
	,u.UnitId
	,u.Name
	FROM dbo.Department AS dep WITH (NOLOCK)
		LEFT JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
	WHERE dep.DepartmentId = @Id

END