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
		20250903@Jay: update role [Redmine: #237201]
		20251126@Mira: Get teamIds, total members [Redmine: #245211]

    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

	CREATE TABLE #tmpDeptSummary
	(
		DepartmentId INT,
		TeamIds VARCHAR(MAX),
		TotalMembers INT
	);

	;WITH G AS 
	(
		SELECT 
			g.GroupId,
			g.DepartmentId,
			SUM(1) AS TotalMembers
		FROM dbo.[Group] g WITH(NOLOCK)
		INNER JOIN dbo.CompanyEmployee emp WITH(NOLOCK) ON emp.GroupId = g.GroupId AND emp.IsDeleted = 0 AND emp.Enabled = 1
		WHERE g.IsDeleted = 0
		GROUP BY g.GroupId, g.DepartmentId
	)
	INSERT INTO #tmpDeptSummary (DepartmentId, TeamIds, TotalMembers)
	SELECT 
		DepartmentId,
		STRING_AGG(CONVERT(VARCHAR(10), GroupId), ',') AS TeamIds,
		SUM(TotalMembers) AS TotalMembers
	FROM G
	GROUP BY DepartmentId;
	
	-- Select
    SELECT dep.DepartmentId AS Id
        ,dep.GroupDeptId
        ,dep.Code
        ,dep.[Name]
        ,dep.IsActive
        ,dep.AccountableArea
        ,dep.SupporterEmpId
        ,e.CtrId AS PICCtrId
        ,ce.EmpId AS PICEmpId
        ,ce.NickName AS PICEmployeeName
		,t.TeamIds
		,t.TotalMembers
        ,u.UnitId
        ,u.Code
        ,u.[Name]
        ,u.PICEmpId
        ,u.SupporterEmpId		
	FROM dbo.Department AS dep WITH (NOLOCK)
		LEFT JOIN dbo.Unit AS u WITH (NOLOCK) ON dep.UnitId = u.UnitId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON dep.PICEmpId = ce.EmpId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		LEFT JOIN #tmpDeptSummary t ON t.DepartmentId = dep.DepartmentId
	WHERE (@IsActive IS NULL OR dep.IsActive = @IsActive)
		AND dep.IsDeleted = 0
		AND (@UnitId IS NULL OR u.UnitId = @UnitId)

	-- Drop table
	DROP TABLE #tmpDeptSummary
END