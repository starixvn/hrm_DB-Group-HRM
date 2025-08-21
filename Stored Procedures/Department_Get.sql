/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Department_Get]
(
    @IsActive BIT = NULL,
    @UnitId INT = NULL
)
AS
/*
    Created: 20200521@Lilac.Nguyen
    Task: get department
    DB: bodb_HRM

    Revisions:
        20250403@Tim: remove param CompanyId [Redmine: #222886]
	    20250421@Mira: add new Deparment - new structure [Redmine: #221568]
        20250819@Tim: get PICEmpId [Redmine: #235678]
	20250812@Mira: tranfer employee [Redmine: #235678]

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
		,e.CtrId AS PICCtrId
        ,ce.EmpId AS PICEmpId
		,u.UnitId
        ,u.Code
		,u.[Name]
        ,u.PICEmpId
	FROM dbo.Department AS dep WITH (NOLOCK)
		LEFT JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON dep.PICEmpId = ce.EmpId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
	WHERE (@IsActive IS NULL OR dep.IsActive = @IsActive)
		AND dep.IsDeleted = 0
		AND (@UnitId IS NULL OR u.UnitId = @UnitId)
END