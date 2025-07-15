/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SystemConfigs_UpdateCompanySetting]
    @CompanyId INT,
    @HasBIO VARCHAR(10),
    @EnableLetstalk VARCHAR(10),
    @WhitelistIPs VARCHAR(MAX),
    @Currency VARCHAR(MAX)
AS

/*
Created: 20250715@Lilac.Nguyen
Task: Update Setting Companys
DB: HRM
Original:

Revisions:

*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @Configs TABLE (
        [Key] VARCHAR(30),
        [Value] VARCHAR(MAX)
    );

    INSERT INTO @Configs ([Key], [Value])
    VALUES 
        ('HasBIO', LTRIM(RTRIM(@HasBIO))),
        ('EnableLetstalk', LTRIM(RTRIM(@EnableLetstalk))),
        ('WhitelistIPs', LTRIM(RTRIM(@WhitelistIPs))),
        ('Currency', LTRIM(RTRIM(@Currency)));

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
END
