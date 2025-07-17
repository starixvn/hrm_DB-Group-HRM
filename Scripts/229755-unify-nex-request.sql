/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Employee_GetEmployeeForPIC] 
AS
/*
	Created: Henry.Dinh@2025-04-18
	Task: Get employee for PIC
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT e.[EmpId] as Id
      ,e.[Code]
      ,e.[NickName]
      ,e.[FullName]
	  ,c.[Name] AS CompanyName
	FROM [dbo].[Employee] e
	INNER JOIN [dbo].CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ISNULL(ce.IsSpecialUser, 0) = 0 AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
	INNER JOIN [dbo].Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE ISNULL(e.isDeleted, 0) = 0 and e.Enabled = 1
	ORDER BY e.[NickName], e.[Code]
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[GroupSupervisor_GetByRole]
(
    @TeamId INT
    ,@Role TINYINT
)
AS
/*
    Created: 20140723@Quinn.Vo
    Task: Get list supervisors by group and action type.
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT e.EmpId
		,e.NickName
		,e.FullName
		,g.GroupId AS TeamId
		,g.Code
		,g.Code AS TeamCode
		,g.[Name]
		,su.OwnerId
		,c.CompanyId AS CompanyId
		,c.[Name] AS CompanyName
		,CAST(MAX(CASE 
					WHEN su.RequestType IN (1, 2) THEN 1
					ELSE 0
					END) AS BIT) AS HasCheckInOut
		,CAST(MAX(CASE 
					WHEN su.RequestType IN (3, 4) THEN 1
					ELSE 0
					END) AS BIT) AS HasLateInEarlyOut
		,CAST(MAX(CASE 
					WHEN su.RequestType = 5 THEN 1
					ELSE 0
					END) AS BIT) AS HasChangeShift
		,CAST(MAX(CASE 
					WHEN su.RequestType = 6 THEN 1
					ELSE 0
					END) AS BIT) AS HasLeave
		,CAST(MAX(CASE 
					WHEN su.RequestType = 7 THEN 1
					ELSE 0
					END) AS BIT) AS HasKeepInView
		,CAST(MAX(CASE 
					WHEN su.RequestType = 8 THEN 1
					ELSE 0
					END) AS BIT) AS HasOvertime
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.OwnerId = e.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON @TeamId = g.GroupId
		INNER JOIN dbo.[CompanyEmployee] AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ISNULL(ce.IsSpecialUser, 0) = 0 AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
		INNER JOIN dbo.[Company] AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE su.GroupId = @TeamId
		AND su.ActionType = @Role
		AND ISNULL(su.IsDeleted, 0) = 0
	GROUP BY e.EmpId
		,e.NickName
		,e.FullName
		,g.GroupId
		,g.Code
		,g.[Name]
		,su.DisplayOrder
		,su.OwnerId
		,c.[Name]
		,c.CompanyId
	ORDER BY ISNULL(su.DisplayOrder, 0)
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SupervisorCompanies_GetByEmpId] @EmpId INT
AS
/*
Created: Jay.Do@20250704
Task: get supervisor companies
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT CompanyId 
	FROM GroupSupervisor gs  WITH (NOLOCK)
	INNER JOIN dbo.[Group] g WITH (NOLOCK) ON gs.GroupId = g.GroupId
	WHERE gs.OwnerId = @EmpId
	    AND gs.IsDeleted = 0
END
GO


