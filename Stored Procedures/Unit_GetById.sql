/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_GetById]
(
	@UnitId INT
)
AS
/*
	Created: 20200520@Patsy.doan
	Task: Unit_GetById
	DB: HRM
	Original: 
	Revisions:  
		- 20250410@Henry: remove company_id + update field [Redmine: #221569]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SELECT u.UnitId
		,u.Code
		,u.Name
		,u.GroupUnitId
		,u.PICEmpId
		,u.Category
		,u.Type
		,u.AccountableArea
		,u.IsActive
		,u.ModifiedDate
	FROM dbo.Unit as u
	WHERE u.UnitId =@UnitId
END