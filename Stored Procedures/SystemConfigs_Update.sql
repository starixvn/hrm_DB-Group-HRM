/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SystemConfigs_Update]
    @CompanyId INT,
    @SettingsJson NVARCHAR(MAX)
AS

/*
Created: 20250717@Lilac.Nguyen
Task: Update Setting Companys
DB: bodb_HRM
Original:

Revisions:

*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @Configs TABLE (
        [Key] VARCHAR(100),
        [Value] VARCHAR(MAX)
    );

    INSERT INTO @Configs ([Key], [Value])
    SELECT [Key], [Value]
    FROM OPENJSON(@SettingsJson);

    UPDATE sc
    SET sc.[Value] = cfg.[Value]
    FROM dbo.SystemConfigs sc
    JOIN @Configs cfg ON sc.[Key] = cfg.[Key]
    WHERE sc.CompanyId = @CompanyId;

    INSERT INTO dbo.SystemConfigs (CompanyId, [Key], [Value])
    SELECT @CompanyId, cfg.[Key], cfg.[Value]
    FROM @Configs cfg
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SystemConfigs sc
        WHERE sc.CompanyId = @CompanyId AND sc.[Key] = cfg.[Key]
    );
END;
