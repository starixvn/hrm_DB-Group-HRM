/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_Manpower]
(
    @CompanyId SMALLINT
    ,@Year INT
)
AS
/*
    Created: 20151030@Quinn.Vo
    Task: Get data for manpower report.
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Jan DATETIME
		,@Feb DATETIME
		,@Mar DATETIME
		,@Apr DATETIME
		,@May DATETIME
		,@Jun DATETIME
		,@Jul DATETIME
		,@Aug DATETIME
		,@Sep DATETIME
		,@Oct DATETIME
		,@Nov DATETIME
		,@Dec DATETIME

	SELECT @Jan = CAST(@Year AS VARCHAR(4)) + '/01/01'
		,@Feb = DATEADD(MM, 1, @Jan)
		,@Mar = DATEADD(MM, 2, @Jan)
		,@Apr = DATEADD(MM, 3, @Jan)
		,@May = DATEADD(MM, 4, @Jan)
		,@Jun = DATEADD(MM, 5, @Jan)
		,@Jul = DATEADD(MM, 6, @Jan)
		,@Aug = DATEADD(MM, 7, @Jan)
		,@Sep = DATEADD(MM, 8, @Jan)
		,@Oct = DATEADD(MM, 9, @Jan)
		,@Nov = DATEADD(MM, 10, @Jan)
		,@Dec = DATEADD(MM, 11, @Jan)

	SELECT g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dept.Code as DepartmentCode
		,dept.[Name] as DepartmentName
		,SUM(CASE 
				WHEN DATEDIFF(MM, @Jan, e.ResignedDate) >= 0
					AND DATEDIFF(MM, e.ResignedDate, @Dec) >= 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResigned
		,SUM(CASE 
				WHEN DATEDIFF(MM, @Jan, e.ResignedDate) >= 0
					AND DATEDIFF(MM, e.ResignedDate, @Dec) >= 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResigned
		,SUM(CASE 
				WHEN DATEDIFF(MM, @Jan, e.JoinedDate) >= 0
					AND DATEDIFF(MM, e.JoinedDate, @Dec) >= 0 THEN 1
				ELSE 0
				END) AS NewHire
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Dec) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUser
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jan) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedJan
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jan) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedJan
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jan) = 0 THEN 1
				ELSE 0
				END) AS NewHireJan
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jan) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserJan
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Feb) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedFeb
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Feb) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedFeb
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Feb) = 0 THEN 1
				ELSE 0
				END) AS NewHireFeb
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Feb) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserFeb
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Mar) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedMar
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Mar) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedMar
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Mar) = 0 THEN 1
				ELSE 0
				END) AS NewHireMar
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Mar) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserMar
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Apr) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedApr
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Apr) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedApr
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Apr) = 0 THEN 1
				ELSE 0
				END) AS NewHireApr
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Apr) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserApr
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @May) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedMay
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @May) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedMay
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @May) = 0 THEN 1
				ELSE 0
				END) AS NewHireMay
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @May) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserMay
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jun) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedJun
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jun) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedJun
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jun) = 0 THEN 1
				ELSE 0
				END) AS NewHireJun
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jun) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserJun
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jul) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedJul
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Jul) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedJul
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jul) = 0 THEN 1
				ELSE 0
				END) AS NewHireJul
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Jul) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserJul
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Aug) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedAug
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Aug) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedAug
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Aug) = 0 THEN 1
				ELSE 0
				END) AS NewHireAug
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Aug) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserAug
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Sep) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedSep
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Sep) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedSep
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Sep) = 0 THEN 1
				ELSE 0
				END) AS NewHireSep
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Sep) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserSep
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Oct) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedOct
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Oct) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedOct
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Oct) = 0 THEN 1
				ELSE 0
				END) AS NewHireOct
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Oct) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserOct
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Nov) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedNov
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Nov) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedNov
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Nov) = 0 THEN 1
				ELSE 0
				END) AS NewHireNov
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Nov) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserNov
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Dec) = 0
					AND e.ConfirmedDate IS NULL THEN 1
				ELSE 0
				END) AS ProbationResignedDec
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.ResignedDate, @Dec) = 0
					AND e.ConfirmedDate IS NOT NULL THEN 1
				ELSE 0
				END) AS ConfirmedResignedDec
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Dec) = 0 THEN 1
				ELSE 0
				END) AS NewHireDec
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @Dec) >= 0
					AND e.isDeleted = 0
					AND e.[Enabled] = 1 THEN 1
				ELSE 0
				END) AS ActiveUserDec
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
        INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
	WHERE ce.CompanyId = @CompanyId
        AND g.IsDeleted = 0
		AND (e.ResignedDate IS NULL 
			OR
			YEAR(e.ResignedDate) >= @Year) 
	GROUP BY g.GroupId
		,g.Code
		,g.[Name]
		,dept.Code
		,dept.[Name]
END