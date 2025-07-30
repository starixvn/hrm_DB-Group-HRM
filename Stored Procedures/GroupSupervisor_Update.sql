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
DB: HRM_SMS
Original:

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




