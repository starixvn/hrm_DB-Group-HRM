/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_GetBySupervisor] @SupervisorId INT
AS
/*
Created: 20151027@Quinn.Vo
Task: Get all group by supervisor
DB: HRM
Original:

Revisions:
		20250813@Lilac: restructure for transfer [Redmine: #235678]
		20251111@Lilac: merge ActionType [Redmine: #243412]

Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tblGroupId TABLE (GroupId INT)

	IF EXISTS (
			SELECT 1
			FROM dbo.CompanyEmployee AS e WITH (NOLOCK)
				INNER JOIN dbo.EmployeeRole AS er WITH (NOLOCK) ON er.EmployeeId = e.EmpId
			WHERE e.EmpId = @SupervisorId
				AND er.RoleId IN (6, 7)
			)
	BEGIN
		INSERT INTO @tblGroupId (GroupId)
		SELECT GroupId
		FROM dbo.[Group] AS g WITH (NOLOCK)
		WHERE ISNULL(IsDeleted, 0) = 0
	END
	ELSE
	BEGIN
		INSERT INTO @tblGroupId (GroupId)
		SELECT DISTINCT GroupId
		FROM (
			SELECT GroupId
			FROM dbo.GroupSupervisor WITH (NOLOCK)
			WHERE OwnerId = @SupervisorId
				AND ISNULL(IsDeleted, 0) = 0
			
			UNION
			SELECT GroupId
			FROM dbo.CompanyEmployee WITH (NOLOCK)
			WHERE EmpId = @SupervisorId
			
			UNION
			SELECT g.GroupId
			FROM dbo.EmployeeSupervisor AS es WITH (NOLOCK)
				INNER JOIN dbo.CompanyEmployee AS e WITH (NOLOCK) ON es.EmpId = e.EmpId
				INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
			WHERE es.OwnerId = @SupervisorId
				AND es.ActionType IN (2, 3, 4, 5)
				AND e.[Enabled] = 1
				AND ISNULL(e.isDeleted, 0) = 0
				AND ISNULL(g.isDeleted, 0) = 0
			GROUP BY g.GroupId
			) AS a
	END

	SELECT g.GroupId AS Id
		,g.[Name]
		,g.Code
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN @tblGroupId AS gr ON g.GroupId = gr.GroupId
	WHERE ISNULL(g.isDeleted, 0) = 0
	ORDER BY g.[Rank]
		,g.Code
END