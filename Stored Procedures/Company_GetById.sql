/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[Company_GetById]
    @CompanyId INT
AS

/*
Created: 20250714@Lilac.Nguyen
Task: Get Company by CompanyId
DB: HRM
Original:

Revisions:

*/

BEGIN
    SET NOCOUNT ON;

    SELECT 
        c.CompanyId,
        c.[Name],
        cfg.HasBIO,
        cfg.Currency,
        cfg.EnableLetstalk,
        cfg.WhitelistIPs
    FROM dbo.Company c
    LEFT JOIN (
        SELECT 
            CompanyId,
            [HasBIO],
            [WhitelistIPs],
            [EnableLetstalk],
            [Currency]
        FROM (
            SELECT CompanyId, [Key], [Value]
            FROM dbo.SystemConfigs
            WHERE [Key] IN ('HasBIO', 'WhitelistIPs', 'EnableLetstalk', 'Currency')
        ) AS raw
        PIVOT (
            MAX([Value])
            FOR [Key] IN ([HasBIO], [WhitelistIPs], [EnableLetstalk], [Currency])
        ) AS pvt
    ) cfg ON c.CompanyId = cfg.CompanyId
    WHERE ISNULL(c.IsDeleted, 0) = 0
      AND c.CompanyId = @CompanyId;
END;
