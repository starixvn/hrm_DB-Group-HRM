/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_Get] @IsActive BIT = NULL
AS
/*
	Created: 20200521@Patsy.Doan
	Task: Get unit.
	DB: HRM

	Revisions:
		20250403@Tim: remove param CompanyId [Redmine: #222886]
		20250421@Tim: sort by GroupUnitId [Redmine: #221569]
		20250812@Mira: tranfer employee [Redmine: #235678]
		20250903@Jay: update role [Redmine: #237201]
		20251126@Mira: Get teamIds, total members [Redmine: #245211]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpUnitSummary
	(
		UnitId INT,
		TeamIds VARCHAR(MAX),
		TotalMembers INT
	);

	;WITH G AS 
	(
		SELECT 
			g.GroupId,
			dept.UnitId,
			SUM(1) AS TotalMembers
		FROM dbo.[Group] g WITH(NOLOCK)
		INNER JOIN dbo.CompanyEmployee emp WITH(NOLOCK) ON emp.GroupId = g.GroupId AND emp.IsDeleted = 0 AND emp.Enabled = 1
		INNER JOIN dbo.Department dept WITH(NOLOCK) ON dept.DepartmentId = g.DepartmentId 
		WHERE g.IsDeleted = 0
		GROUP BY g.GroupId, dept.UnitId
	)
	INSERT INTO #tmpUnitSummary (UnitId, TeamIds, TotalMembers)
	SELECT 
		UnitId,
		STRING_AGG(CONVERT(VARCHAR(10), GroupId), ',') AS TeamIds,
		SUM(TotalMembers) AS TotalMembers
	FROM G
	GROUP BY UnitId;
	
	-- Select
	SELECT u.UnitId
		,u.Code
		,u.[Name]
		,u.GroupUnitId
		,u.PICEmpId
		,ce.NickName AS PICNickName
		,u.Category
		,u.[Type]
		,u.AccountableArea
		,u.IsActive
		,u.ModifiedDate
		,u.SupporterEmpId
		,t.TeamIds
		,t.TotalMembers
	FROM dbo.Unit AS u WITH (NOLOCK)
	LEFT JOIN dbo.CompanyEmployee As ce WITH (NOLOCK) ON ce.EmpId = u.PICEmpId
	LEFT JOIN #tmpUnitSummary t ON t.UnitId = u.UnitId
	WHERE (
			@IsActive IS NULL
			OR u.IsActive = @IsActive
			)
			AND u.IsDeleted = 0
	ORDER BY u.GroupUnitId ASC, u.Code ASC
	
	-- Drop table
	DROP TABLE #tmpUnitSummary

END