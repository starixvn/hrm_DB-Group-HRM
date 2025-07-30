/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GroupSupervisor_GetById] @TeamId INT,
	@IsGroupSpace BIT = 0,
	@CompanyId INT = NULL
AS
/*
Created: 20140723@Quinn.Vo
Task: Get list supervisors by group.
DB: HRM
Original:

Revisions:
	- 20250530@Jay: add company name for who come from different company & add manage role for group space [Redmine: #225528]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Supervisors TABLE (
		GroupId INT
		,ActionType TINYINT
		,Supervisors NVARCHAR(MAX)
		)
	DECLARE @SupervisorActions TABLE (
		GroupId INT
		,ActionType TINYINT
		)

	INSERT INTO @SupervisorActions (
		GroupId
		,ActionType
		)
	VALUES (
		@TeamId
		,2
		) -- verify

	INSERT INTO @SupervisorActions (
		GroupId
		,ActionType
		)
	VALUES (
		@TeamId
		,3
		) -- approve
			
	IF (@IsGroupSpace = 0)
		INSERT INTO @SupervisorActions (
			GroupId
			,ActionType
			)
		VALUES (
			@TeamId
			,4
			) -- shift

	IF (@IsGroupSpace = 0)
		INSERT INTO @SupervisorActions (
			GroupId
			,ActionType
			)
		VALUES (
			@TeamId
			,5
			) -- on behalf request
			
	IF (@IsGroupSpace = 0)
		INSERT INTO @SupervisorActions (
			GroupId
			,ActionType
			)
		VALUES (
			@TeamId
			,8
			) -- edit discipline

	INSERT INTO @Supervisors (
		GroupId
		,ActionType
		,Supervisors
		)
	SELECT es.GroupId
		,es.ActionType
		,STUFF((
				SELECT CAST(', ' AS VARCHAR(MAX)) + 
					CASE 
						WHEN @CompanyId IS NOT NULL AND @CompanyId = a.CompanyId THEN a.NickName
						ELSE a.NickName + ' (' + ISNULL(a.CompanyName, '') + ')'
					END
				FROM (
					SELECT DISTINCT su.GroupId,
						ActionType,
						e.NickName,
						c.[Name] AS CompanyName,
						c.CompanyId
					FROM [dbo].GroupSupervisor AS su WITH (NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.OwnerId = e.EmpId
						LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.Empid = e.Empid AND ISNULL(ce.IsSpecialUser, 0) = 0 AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
						LEFT JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
					WHERE su.GroupId = @TeamId
						AND su.ActionType IN (2, 3, 4, 5, 8)
						AND ISNULL(su.IsDeleted, 0) = 0
					) AS a
				WHERE a.GroupId = es.GroupId
					AND a.ActionType = es.ActionType
				FOR XML PATH('')
				), 1, 1, '') AS Supervisor
	FROM @SupervisorActions AS es
	ORDER BY es.GroupId
		,es.ActionType

	SELECT g.GroupId AS TeamId
		,g.Code
		,g.[Name]
		,sp.ActionType
		,sp.Supervisors
	FROM @Supervisors AS sp
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON sp.GroupId = g.GroupId
	ORDER BY sp.GroupId
		,sp.ActionType
END
