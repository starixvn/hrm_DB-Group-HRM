/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GroupSupervisor_Get]
(
    @CompanyId SMALLINT
    ,@TeamIds VARCHAR(MAX) = ''
)
AS
/*
    Created: 20140723@Quinn.Vo
    Task: Get list supervisors by group ids.
    DB: bodb_HRM

    Revisions:
        - 20250409@Tim: remove section [Redmine: #222886]
        - 20250530@Jay: add company name for who come from different company [Redmine: #225528]
        20250813@Jay: change db structure [Redmine: #235678]
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

	SELECT gr.GroupId AS TeamId
		,gr.Code
		,gr.[Name]
        ,dep.Code AS DepartmentCode
		,dep.[Name] AS DepartmentName
	FROM dbo.[Group] AS gr WITH (NOLOCK)
		INNER JOIN #tmpTeam AS tblgr WITH (NOLOCK) ON gr.GroupId = tblgr.GroupId
		INNER JOIN dbo.Department AS dep WITH (NOLOCK) ON dep.DepartmentId = gr.DepartmentId
	WHERE gr.CompanyId = @CompanyId
        AND ISNULL(gr.IsDeleted, 0) = 0
	ORDER BY gr.Code

	SELECT DISTINCT su.OwnerId
		,CASE
			WHEN ce.CompanyId != @CompanyId 
				THEN ce.NickName + ' (' + c.[Name] + ')' 
			ELSE ce.NickName
		END AS NickName
		,emp.FullName
		,su.ActionType
		,su.GroupId AS TeamId
		,gr.Code
        ,gr.[Name]
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON su.GroupId = gr.GroupId
			AND ISNULL(gr.IsDeleted, 0) = 0
		INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON su.OwnerId = ce.EmpId
			AND ISNULL(ce.isDeleted, 0) = 0
			AND ce.[Enabled] = 1
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE gr.CompanyId = @CompanyId
        AND su.ActionType IN (2, 3, 4, 5, 8)
		AND ISNULL(su.IsDeleted, 0) = 0

	DROP TABLE #tmpTeam
END
