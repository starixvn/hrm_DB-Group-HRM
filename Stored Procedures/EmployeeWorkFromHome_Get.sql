/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeWorkFromHome_Get]
(
    @FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(MAX) = ''
	,@IsLocal BIT = NULL
)
AS
/*
    Created: 20210528@Quinn.Vo
    Task: Get Employee Work From Home by date.
    DB: bodb_HRM

    Revisions:
        - 20250409@Tim: remove section [Redmine: #222886]
		- 20250812@Mira: tranfer employee [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpTeam (GroupId INT)

	IF ISNULL(@TeamIds, '') <> ''
	BEGIN
		INSERT INTO #tmpTeam (GroupId)
		SELECT value
		FROM STRING_SPLIT(@TeamIds, ',')
	END

	SELECT ew.EmployeeWorkFromHomeId
		,ew.FromDate
		,ew.ToDate
		,e.EmpId
		,e.Code
		,e.NickName
		,u.FullName
		,g.[Name] AS TeamName
		,dep.[Name] AS DepartmentName
		,ew.ModifiedDate
		,ew.ModifiedBy
		,modifier.NickName AS Modifier
		,ew.Remark
	FROM dbo.EmployeeWorkFromHome AS ew WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS e WITH (NOLOCK) ON ew.EmpId = e.EmpId
		INNER JOIN dbo.Employee AS u WITH (NOLOCK) ON u.UserId = e.UserId
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON e.EmpId = empsum.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN #tmpTeam AS t WITH (NOLOCK) ON g.GroupId = t.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId
		LEFT JOIN dbo.CompanyEmployee AS modifier WITH (NOLOCK) ON ew.ModifiedBy = modifier.EmpId
	WHERE (
			(
				ew.FromDate BETWEEN @FromDate
					AND @ToDate
				)
			OR (
				ew.ToDate BETWEEN @FromDate
					AND @ToDate
				)
			OR (
				@FromDate BETWEEN ew.FromDate
					AND ew.ToDate
				)
			OR (
				@ToDate BETWEEN ew.FromDate
					AND ew.ToDate
				)
			)
		AND (
			@IsLocal IS NULL
			OR empsum.IsLocal = @IsLocal
			)
	ORDER BY ew.FromDate
		,g.[Name]

    DROP TABLE #tmpTeam
END
