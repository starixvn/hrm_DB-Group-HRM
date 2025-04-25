/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_Get] @IsActive BIT = NULL
AS
/*
	Created: 20200521@Patsy.Doan
	Task: Get unit.
	DB: HRM

	Revisions:
		20250403@Tim: remove param CompanyId [Redmine: #222886]
		20250421@Tim: sort by GroupUnitId [Redmine: #221569]
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	SELECT u.UnitId
		,u.Code
		,u.[Name]
		,u.GroupUnitId
		,u.PICEmpId
		,e.NickName AS PICNickName
		,u.Category
		,u.[Type]
		,u.AccountableArea
		,u.IsActive
		,u.ModifiedDate
	FROM dbo.Unit AS u WITH (NOLOCK)
	LEFT JOIN dbo.Employee As e WITH (NOLOCK) ON e.EmpId = u.PICEmpId
	WHERE (
			@IsActive IS NULL
			OR u.IsActive = @IsActive
			)
			AND u.IsDeleted = 0
	ORDER BY u.GroupUnitId, u.Code
END