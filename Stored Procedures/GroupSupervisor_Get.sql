/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
        20250409@Tim: remove section [Redmine: #222886]
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
		,emp.NickName
		,emp.FullName
		,su.ActionType
		,su.GroupId AS TeamId
		,gr.Code
        ,gr.[Name]
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS gr WITH (NOLOCK) ON su.GroupId = gr.GroupId
		AND ISNULL(gr.IsDeleted, 0) = 0
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON su.OwnerId = emp.EmpId
		AND ISNULL(emp.isDeleted, 0) = 0
		AND emp.[Enabled] = 1
	WHERE gr.CompanyId = @CompanyId
        AND su.ActionType IN (2, 3, 4, 5, 8)
		AND ISNULL(su.IsDeleted, 0) = 0

	DROP TABLE #tmpTeam
END