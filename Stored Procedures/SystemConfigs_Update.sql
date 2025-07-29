/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SystemConfigs_Update]
    @CompanyId INT,
    @SettingsJson NVARCHAR(MAX),
    @ModifiedBy INT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg VARCHAR(200) = '' OUTPUT
AS

/*
Created: 20250717@Lilac.Nguyen
Task: Update Setting Companys
DB: bodb_HRM
Original:

Revisions:
	20250725@Lilac.Nguyen: write log

*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @Configs TABLE (
        [Key] VARCHAR(100),
        [Value] VARCHAR(MAX)
    );

    DECLARE @xml XML;
    DECLARE @logOldData NVARCHAR(MAX) = NULL;
    DECLARE @logData NVARCHAR(MAX) = NULL;
	DECLARE @InsertedKeys TABLE (
        [Key] VARCHAR(100)
    );

    INSERT INTO @Configs ([Key], [Value])
    SELECT [Key], [Value]
    FROM OPENJSON(@SettingsJson);

    SET @xml = (
        SELECT sc.[Key] AS '@Key',
               sc.[Value] AS '@Value'
        FROM dbo.SystemConfigs sc WITH (NOLOCK)
        JOIN @Configs cfg ON cfg.[Key] = sc.[Key]
        WHERE sc.CompanyId = @CompanyId
          AND ISNULL(sc.[Value], '') <> ISNULL(cfg.[Value], '')
        FOR XML PATH('Row'), TYPE
    );
    SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

    UPDATE sc
    SET sc.[Value] = cfg.[Value]
    FROM dbo.SystemConfigs sc
    JOIN @Configs cfg ON cfg.[Key] = sc.[Key]
    WHERE sc.CompanyId = @CompanyId
      AND ISNULL(sc.[Value], '') <> ISNULL(cfg.[Value], '');

    SET @xml = (
        SELECT sc.[Key] AS '@Key',
               sc.[Value] AS '@Value'
        FROM dbo.SystemConfigs sc WITH (NOLOCK)
        JOIN @Configs cfg ON cfg.[Key] = sc.[Key]
        WHERE sc.CompanyId = @CompanyId
          AND ISNULL(sc.[Value], '') = ISNULL(cfg.[Value], '')
        FOR XML PATH('Row'), TYPE
    );
    SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

    IF (@logOldData IS NOT NULL AND @logData IS NOT NULL)
    BEGIN
        EXEC dbo.ActivityLog_Insert 
            @UserId = @ModifiedBy,
            @ObjectTypeId = 5,
            @ObjectId = @CompanyId,
            @OldData = @logOldData,
            @Data = @logData,
            @ErrCode = @ErrCode OUTPUT,
            @ErrMsg = @ErrMsg OUTPUT;
    END

    INSERT INTO dbo.SystemConfigs (CompanyId, [Key], [Value])
    OUTPUT inserted.[Key] INTO @InsertedKeys([Key])
    SELECT @CompanyId, cfg.[Key], cfg.[Value]
    FROM @Configs cfg
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SystemConfigs sc
        WHERE sc.CompanyId = @CompanyId AND sc.[Key] = cfg.[Key]
    );

    SET @xml = (
        SELECT sc.[Key] AS '@Key',
               sc.[Value] AS '@Value'
        FROM dbo.SystemConfigs sc WITH (NOLOCK)
        JOIN @InsertedKeys ik ON sc.[Key] = ik.[Key]
        WHERE sc.CompanyId = @CompanyId
        FOR XML PATH('Row'), TYPE
    );
    SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

    IF (@logData IS NOT NULL)
    BEGIN
        EXEC dbo.ActivityLog_Insert 
            @UserId = @ModifiedBy,
            @ObjectTypeId = 5,
            @ObjectId = @CompanyId,
            @OldData = NULL,
            @Data = @logData,
            @ErrCode = @ErrCode OUTPUT,
            @ErrMsg = @ErrMsg OUTPUT;
    END
END