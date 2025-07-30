/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Get]
(
    @CompanyId INT
    ,@TeamId INT = NULL
	,@keyWord varchar(20) = null
	,@isDeleted BIT = NULL
)
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get group
    DB: bodb_HRM

    Revisions:
        20250310@Mira: filter by CompanyId [Redmine: #217976]
        20250403@Tim: remove section [Redmine: #222886]
        20250515@Jay: add years of service for extra leave [Redmine: #227166]
        20250530@Jay: show company name for employees from different company [Redmine: #225528]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (
		GroupId INT PRIMARY KEY
		,NoOfMembers INT
		,TotalLocal INT
		,TotalExpat INT
		)

	INSERT INTO #tmpGroup (
		GroupId
		,NoOfMembers
		,TotalLocal
		,TotalExpat
		)
	SELECT g.GroupId
		,SUM(CASE 
				WHEN esum.IsLocal IS NOT NULL THEN 1
				ELSE 0
				END) AS NoOfMembers
		,SUM(CASE 
				WHEN esum.IsLocal = 1 THEN 1
				ELSE 0
				END) TotalLocal
		,SUM(CASE 
				WHEN esum.IsLocal = 0 THEN 1
				ELSE 0
				END) TotalExpat
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.GroupId = g.GroupId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) on c.EmpId = emp.EmpId AND c.CompanyId = @CompanyId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		AND g.CompanyId = @CompanyId
	GROUP BY g.GroupId

	SELECT g.groupId AS TeamId
		,g.[Name]
		,g.Code
		,g.[Rank]
		,g.MailGroup
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave
		,tbl.NoOfMembers
		,tbl.TotalLocal
		,tbl.TotalExpat
		,g.PICEmpId
		,cpic.[Name] AS PICCompanyName
		,cpic.[CompanyId] AS PICCompanyId
		,ld.NickName as PICNickName
		,dept.DepartmentId
        ,dept.Code
        ,dept.[Name]
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.Employee AS ld WITH (NOLOCK) ON ld.EmpId = g.PICEmpId
		LEFT JOIN dbo.CompanyEmployee cepic WITH (NOLOCK) ON cepic.EmpId = g.PICEmpId
		LEFT JOIN dbo.Company cpic WITH (NOLOCK) ON cpic.CompanyId = cepic.CompanyId
		LEFT JOIN #tmpGroup AS tbl ON g.GroupId = tbl.GroupId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		AND (
			 @keyWord IS NULL
			 OR LOWER(g.[Name]) like LOWER('%' + @keyWord + '%') 
			 OR LOWER(g.Code) like LOWER('%' + @keyWord + '%') 
			)
		AND g.CompanyId = @CompanyId
	ORDER BY g.[Code]

	SELECT mng.GroupId AS TeamId
		,mng.RoleId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
	FROM dbo.GroupManager AS mng WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON mng.GroupId = g.GroupId
		AND (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON mng.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) on c.EmpId = emp.EmpId
    WHERE g.CompanyId = @CompanyId
        AND c.CompanyId = @CompanyId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1

    DROP TABLE #tmpGroup
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Insert]
(
    @Code VARCHAR(20)
    ,@Name VARCHAR(150)
    ,@CreatedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg VARCHAR(200) = '' OUTPUT
    ,@CompanyId SMALLINT
    ,@GroupTeamId INT
    ,@PICEmpId INT = NULL
    ,@DepartmentId INT
    ,@AccountableArea VARCHAR(200) = NULL
)
AS
/*
    Created: 20190515@Oliver.Dang
    Task: insert group 
    DB: bodb_HRM

    Revisions:
        - 20250422@Jay: Apply create group team logic [Redmine: #221567]
        - 20250526@Jay: Allow having the same code [Redmine: #228323]
        - 20250530@Jay: allow PICEmpId be null [Redmine: #225528]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupTeamId = @GroupTeamId
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Team Id "' + CAST(@GroupTeamId AS NVARCHAR) + '" exists.'

		RETURN
	END

	INSERT INTO dbo.[Group] (
		Code
		,[Name]
		,CreatedDate
		,CreatedBy
		,CompanyId
		,GroupTeamId
		,PICEmpId
		,DepartmentId
		,AccountableArea
		)
	VALUES (
		@Code
		,@Name
		,GETDATE()
		,@CreatedBy
		,@CompanyId
		,@GroupTeamId
		,@PICEmpId
		,@DepartmentId
		,@AccountableArea
		)

	DECLARE @id INT = cast(SCOPE_IDENTITY() AS INT)

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,CompanyId as '@CompanyId'
				,GroupTeamId as '@GroupTeamId'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @id
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 2
		,@ObjectId = @id
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Update]
(
    @TeamId INT
    ,@Code VARCHAR(20)
    ,@Name NVARCHAR(150)
    ,@ModifiedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
    ,@PICEmpId INT = NULL
    ,@DepartmentId INT
    ,@AccountableArea VARCHAR(200) = NULL
    ,@GroupTeamId INT
    ,@MailGroup VARCHAR(50) = ''
    ,@LocalBasicAnnualLeaveBalance TINYINT = NULL
    ,@LocalWorkingDays TINYINT = NULL
    ,@LocalWorkingHours TINYINT = NULL
    ,@LocalOffDaysbyWeek TINYINT = NULL
    ,@LocalWorkingHoursByWeek TINYINT = NULL
    ,@LocalYearsOfServiceForExtraLeave INT = NULL
    ,@ExpatBasicAnnualLeaveBalance TINYINT = NULL
    ,@ExpatWorkingDays TINYINT = NULL
    ,@ExpatWorkingHours TINYINT = NULL
    ,@ExpatOffDaysbyWeek TINYINT = NULL
    ,@ExpatWorkingHoursByWeek TINYINT = NULL
    ,@ExpatYearsOfServiceForExtraLeave INT = NULL
)
AS
/*
    Created: Tom.Vo@2013-10-23
    Task: Update group 
    DB: bodb_HRM

    Revisions:
        - 20250515@Jay: add years of service for extra leave [Redmine: #227166]
        - 20250526@Jay: Allow having the same code [Redmine: #228323]
        - 20250530@Jay: allow PICEmpId be null [Redmine: #225528]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId <> @TeamId 
				AND GroupTeamId = @GroupTeamId
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Team Id "' + CAST(@GroupTeamId AS NVARCHAR) + '" have been used by other group.'

		RETURN
	END

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId AS '@PICEmpId'
				,DepartmentId AS '@DepartmentId'
				,AccountableArea AS '@AccountTableArea'
				,GroupTeamId AS '@GroupTeamId'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,LocalYearsOfServiceForExtraLeave AS '@LocalYearsOfServiceForExtraLeave'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,ExpatYearsOfServiceForExtraLeave AS '@ExpatYearsOfServiceForExtraLeave'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	UPDATE dbo.[Group] WITH (ROWLOCK, UPDLOCK)
	SET Code = @Code
		,[Name] = @Name
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
		,PICEmpId = @PICEmpId
		,DepartmentId = @DepartmentId
		,AccountableArea = @AccountableArea
		,GroupTeamId = @GroupTeamId
		,LocalBasicAnnualLeaveBalance = @LocalBasicAnnualLeaveBalance
		,LocalWorkingDays = @LocalWorkingDays
		,LocalWorkingHours = @LocalWorkingHours
		,LocalOffDaysbyWeek = @LocalOffDaysbyWeek
		,LocalWorkingHoursByWeek = @LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave = @LocalYearsOfServiceForExtraLeave
		,ExpatBasicAnnualLeaveBalance = @ExpatBasicAnnualLeaveBalance
		,ExpatWorkingDays = @ExpatWorkingDays
		,ExpatWorkingHours = @ExpatWorkingHours
		,ExpatOffDaysbyWeek = @ExpatOffDaysbyWeek
		,ExpatWorkingHoursByWeek = @ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave = @ExpatYearsOfServiceForExtraLeave
		,[MailGroup] = @MailGroup
	WHERE GroupId = @TeamId

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
				,GroupTeamId as '@GroupTeamId'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,LocalYearsOfServiceForExtraLeave AS '@LocalYearsOfServiceForExtraLeave'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,ExpatYearsOfServiceForExtraLeave AS '@ExpatYearsOfServiceForExtraLeave'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 2
		,@ObjectId = @TeamId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[GroupId_ByGroupTeamId_Get] @GroupTeamId VARCHAR(50)
AS
/*
    Created: 20250528@Jay.Do
    Task: get group id by group team id
    DB: bodb_HRM

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	SELECT TOP 1 GroupId
	FROM [Group]
	WHERE GroupTeamId = @GroupTeamId
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[GroupSupervisor_ByPIC_Insert] @TeamId INT
	,@SupervisorXml NVARCHAR(MAX) = ''
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
    Created: 20190612@Tim.Trinh
    Task: update group supervisor.
    DB: bodb_HRM

    Revisions:
        - 20250530@Jay: add approvers/verifiers for PICEmpId [Redmine: #225528]
    Param's Explanation:
        @SupervisorXml=N'<ROOT><Row OwnerId="1" RequestType="1" DisplayOrder="1" /></ROOT>
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE(),
		@DocHandler INT,
		@RoleVerifier INT = 2,
		@RoleApprover INT = 3

	CREATE TABLE #tblSupervisor (
		OwnerId INT
		,RequestType TINYINT
		,DisplayOrder SMALLINT
		)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@SupervisorXml

	INSERT INTO #tblSupervisor (
		OwnerId
		,RequestType
		,DisplayOrder
		)
	SELECT OwnerId
		,RequestType
		,DisplayOrder
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (OwnerId INT, RequestType TINYINT, DisplayOrder SMALLINT) AS Data

	EXEC sp_xml_removedocument @DocHandler

	UPDATE su
	SET su.IsDeleted = 0
		,su.DisplayOrder = sp.DisplayOrder
		,su.ModifiedDate = @ModifiedDate
		,su.ModifiedBy = @ActorId
	FROM dbo.GroupSupervisor AS su WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblSupervisor AS sp ON sp.OwnerId = su.OwnerId
		AND sp.RequestType = su.RequestType
	WHERE su.GroupId = @TeamId
		AND su.ActionType IN (2, 3)
		AND su.IsDeleted = 1

	MERGE dbo.GroupSupervisor AS [target]
	USING #tblSupervisor AS [source] ON (
				[target].GroupId = @TeamId
				AND [target].ActionType = @RoleVerifier
				AND [target].OwnerId = [source].OwnerId
				AND [target].RequestType = [source].RequestType
				)
	WHEN MATCHED
		AND ISNULL([target].DisplayOrder, 0) <> [source].DisplayOrder THEN
			UPDATE
			SET [target].DisplayOrder = [source].DisplayOrder
				,[target].ModifiedBy = @ActorId
				,[target].ModifiedDate = @ModifiedDate
	WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				GroupId
				,ActionType
				,RequestType
				,OwnerId
				,ModifiedBy
				,ModifiedDate
				,IsDeleted
				,DisplayOrder
				)
			VALUES (
				@TeamId
				,@RoleVerifier
				,[source].RequestType
				,[source].OwnerId
				,@ActorId
				,@ModifiedDate
				,0
				,[source].DisplayOrder
				);

	MERGE dbo.GroupSupervisor AS [target]
	USING #tblSupervisor AS [source] ON (
				[target].GroupId = @TeamId
				AND [target].ActionType = @RoleApprover
				AND [target].OwnerId = [source].OwnerId
				AND [target].RequestType = [source].RequestType
				)
	WHEN MATCHED
		AND ISNULL([target].DisplayOrder, 0) <> [source].DisplayOrder THEN
			UPDATE
			SET [target].DisplayOrder = [source].DisplayOrder
				,[target].ModifiedBy = @ActorId
				,[target].ModifiedDate = @ModifiedDate
	WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				GroupId
				,ActionType
				,RequestType
				,OwnerId
				,ModifiedBy
				,ModifiedDate
				,IsDeleted
				,DisplayOrder
				)
			VALUES (
				@TeamId
				,@RoleApprover
				,[source].RequestType
				,[source].OwnerId
				,@ActorId
				,@ModifiedDate
				,0
				,[source].DisplayOrder
				);

	DECLARE @LogSPData VARCHAR(MAX) = '<GroupSupervisor_Update ActionType="2, 3" ' + 'TeamId="' + coalesce(cast(@TeamId AS VARCHAR(10)), space(1)) + '" ' + 'SupervisorXml="' + @SupervisorXml + '" />'

	EXEC dbo.Log_WriteLog @LogActionID = 1000
		,@LogDate = @ModifiedDate
		,@Description = 'Update group supervisor'
		,@TrackingValue = @LogSPData
		,@UserID = @ActorId
END
GO

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
				THEN emp.NickName + ' (' + c.[Name] + ')' 
			ELSE emp.NickName
		END AS NickName
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
		LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = emp.EmpId
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE gr.CompanyId = @CompanyId
        AND su.ActionType IN (2, 3, 4, 5, 8)
		AND ISNULL(su.IsDeleted, 0) = 0

	DROP TABLE #tmpTeam
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GroupSupervisor_GetById] @TeamId INT,
	@IsGroupSpace BIT = 0,
	@CompanyId INT = NULL
AS
/*
    Created: 20140723@Quinn.Vo
    Task: Get list supervisors by group.
    DB: bodb_HRM

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
						LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.Empid = e.Empid
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

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GroupSupervisor_GetByRole]
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
        20250530@Jay: add company name for who come from different company [Redmine: #225528]
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
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.[Company] AS c WITH (NOLOCK) ON c.CompanyId = g.CompanyId
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

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GroupSupervisor_Update] @TeamId INT
	,@RoleId TINYINT
	,@SupervisorXml NVARCHAR(MAX) = ''
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
    Created: 20190612@Tim.Trinh
    Task: update group supervisor.
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
        @SupervisorXml=N'<ROOT><Row OwnerId="1" RequestType="1" DisplayOrder="1" /></ROOT>
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE()
		,@DocHandler INT

	CREATE TABLE #tblSupervisor (
		OwnerId INT
		,RequestType TINYINT
		,DisplayOrder SMALLINT
		)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@SupervisorXml

	INSERT INTO #tblSupervisor (
		OwnerId
		,RequestType
		,DisplayOrder
		)
	SELECT OwnerId
		,RequestType
		,DisplayOrder
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (OwnerId INT, RequestType TINYINT, DisplayOrder SMALLINT) AS Data

	EXEC sp_xml_removedocument @DocHandler

	UPDATE su
	SET su.IsDeleted = 1
		,su.ModifiedDate = @ModifiedDate
		,su.ModifiedBy = @ActorId
	FROM dbo.GroupSupervisor AS su WITH (ROWLOCK, UPDLOCK)
	WHERE su.GroupId = @TeamId
		AND su.ActionType = @RoleId
		AND ISNULL(su.IsDeleted, 0) = 0
		AND NOT EXISTS (
			SELECT 1
			FROM #tblSupervisor AS sp
			WHERE sp.OwnerId = su.OwnerId
				AND sp.RequestType = su.RequestType
			)

	UPDATE su
	SET su.IsDeleted = 0
		,su.DisplayOrder = sp.DisplayOrder
		,su.ModifiedDate = @ModifiedDate
		,su.ModifiedBy = @ActorId
	FROM dbo.GroupSupervisor AS su WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblSupervisor AS sp ON sp.OwnerId = su.OwnerId
		AND sp.RequestType = su.RequestType
	WHERE su.GroupId = @TeamId
		AND su.ActionType = @RoleId
		AND su.IsDeleted = 1

	MERGE dbo.GroupSupervisor AS [target]
	USING #tblSupervisor AS [source] ON (
				[target].GroupId = @TeamId
				AND [target].ActionType = @RoleId
				AND [target].OwnerId = [source].OwnerId
				AND [target].RequestType = [source].RequestType
				)
	WHEN MATCHED
		AND ISNULL([target].DisplayOrder, 0) <> [source].DisplayOrder THEN
			UPDATE
			SET [target].DisplayOrder = [source].DisplayOrder
				,[target].ModifiedBy = @ActorId
				,[target].ModifiedDate = @ModifiedDate
	WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				GroupId
				,ActionType
				,RequestType
				,OwnerId
				,ModifiedBy
				,ModifiedDate
				,IsDeleted
				,DisplayOrder
				)
			VALUES (
				@TeamId
				,@RoleId
				,[source].RequestType
				,[source].OwnerId
				,@ActorId
				,@ModifiedDate
				,0
				,[source].DisplayOrder
				);

	DECLARE @LogSPData VARCHAR(MAX) = '<GroupSupervisor_Update ActionType="' + coalesce(cast(@RoleId AS VARCHAR(10)), space(1)) + '" ' + 'TeamId="' + coalesce(cast(@TeamId AS VARCHAR(10)), space(1)) + '" ' + 'SupervisorXml="' + @SupervisorXml + '" />'

	EXEC dbo.Log_WriteLog @LogActionID = 1000
		,@LogDate = @ModifiedDate
		,@Description = 'Update group supervisor'
		,@TrackingValue = @LogSPData
		,@UserID = @ActorId
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[Group_UnitScope_Get]
	@keyWord varchar(20) = null,
	@TeamId INT = NULL
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get group
    DB: bodb_HRM

    Revisions:
        20250310@Mira: filter by CompanyId [Redmine: #217976]
        20250403@Tim: remove section [Redmine: #222886]
        20250515@Jay: add years of service for extra leave [Redmine: #227166]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (
		GroupId INT PRIMARY KEY
		,NoOfMembers INT
		)

	INSERT INTO #tmpGroup (
		GroupId
		,NoOfMembers
		)
	SELECT g.GroupId
		,SUM(CASE 
				WHEN esum.IsLocal IS NOT NULL THEN 1
				ELSE 0
				END) AS NoOfMembers
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.GroupId = g.GroupId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND g.isDeleted != 1
	GROUP BY g.GroupId

	SELECT g.GroupId AS Id
		,GroupTeamId AS GroupTeamId
		,g.[Name] AS TeamName
		,g.Code AS TeamCode
		,g.[Rank]
		,tbl.NoOfMembers
		,g.PICEmpId
		,e.NickName as TeamPIC
		,cpic.[CompanyId] AS TeamPICCompanyId
		,cpic.[Name] AS TeamPICCompany
		,d.DepartmentId
        ,d.Code AS DepartmentCode
        ,d.[Name] AS DepartmentName
		,d.PICEmpId AS DepartmentPICId
		,ed.NickName AS DepartmentPIC
		,u.Code AS UnitCode
		,g.AccountableArea
		,g.CompanyId
		,c.[Name] AS CompanyName
		,g.MailGroup
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS d WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = g.PICEmpId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = d.UnitId
		LEFT JOIN dbo.Employee AS ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN dbo.CompanyEmployee AS cepic WITH (NOLOCK) ON cepic.EmpId = g.PICEmpId
		LEFT JOIN dbo.Company AS cpic WITH (NOLOCK) ON cepic.CompanyId = cpic.CompanyId
		LEFT JOIN #tmpGroup AS tbl ON g.GroupId = tbl.GroupId
		LEFT JOIN dbo.Company AS c ON g.CompanyId = c.CompanyId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND g.isDeleted != 1
		AND (
			 @keyWord IS NULL
			 OR LOWER(g.[Name]) like LOWER('%' + @keyWord + '%') 
			 OR LOWER(g.Code) like LOWER('%' + @keyWord + '%') 
			)
	ORDER BY d.Code

    DROP TABLE #tmpGroup
END
GO

/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetVerifierAndApprover] @EmpId INT
	,@RequestType TINYINT
	,@CompanyId INT = NULL
AS
/*
    Created: 20160609@Quinn.Vo
    Task: Get list verifier and approver for employee when create/edit request.
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Verifiers TABLE (OwnerId INT)
	DECLARE @Approvers TABLE (OwnerId INT)

	INSERT INTO @Verifiers (OwnerId)
	SELECT DISTINCT OwnerId
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
	WHERE su.EmpId = @EmpId
		AND (
			@RequestType IS NULL
			OR su.RequestType = @RequestType
			)
		AND su.ActionType = 2
		AND su.IsDeleted = 0

	IF NOT EXISTS (
			SELECT 1
			FROM @Verifiers
			)
	BEGIN
		INSERT INTO @Verifiers (OwnerId)
		SELECT DISTINCT su.OwnerId
		FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
			INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.GroupId = e.GroupId
		WHERE e.EmpId = @EmpId
			AND (
				@RequestType IS NULL
				OR su.RequestType = @RequestType
				)
			AND su.ActionType = 2
			AND su.IsDeleted = 0
	END

	INSERT INTO @Approvers (OwnerId)
	SELECT DISTINCT OwnerId
	FROM dbo.EmployeeSupervisor AS su WITH (NOLOCK)
	WHERE su.EmpId = @EmpId
		AND (
			@RequestType IS NULL
			OR su.RequestType = @RequestType
			)
		AND su.ActionType = 3
		AND su.IsDeleted = 0

	IF NOT EXISTS (
			SELECT 1
			FROM @Approvers
			)
	BEGIN
		INSERT INTO @Approvers (OwnerId)
		SELECT DISTINCT su.OwnerId
		FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
			INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.GroupId = e.GroupId
		WHERE e.EmpId = @EmpId
			AND (
				@RequestType IS NULL
				OR su.RequestType = @RequestType
				)
			AND su.ActionType = 3
			AND su.IsDeleted = 0
	END

	SELECT OwnerId
		,ee.FullName
		-- ,CASE 
		-- 	WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
		-- 		THEN ee.NickName + ' (' + c.[Name]  +')'
		-- 		ELSE ee.NickName
		-- END NickName
		,ee.NickName
		,ee.Email
	FROM @Verifiers AS su
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON su.OwnerId = ee.EmpId
		 INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId
		-- INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE @CompanyId = ce.CompanyId

	SELECT OwnerId
		,ee.FullName
		-- ,CASE 
		-- 	WHEN @CompanyId IS NOT NULL AND c.CompanyId != @CompanyId 
		-- 		THEN ee.NickName + ' (' + c.[Name]  +')'
		-- 		ELSE ee.NickName
		-- END NickName
		,ee.NickName
		,ee.Email
	FROM @Approvers AS su
		INNER JOIN dbo.Employee AS ee WITH (NOLOCK) ON su.OwnerId = ee.EmpId
		 INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ee.EmpId
		-- INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE @CompanyId = ce.CompanyId
END