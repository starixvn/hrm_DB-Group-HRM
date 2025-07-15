/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[Company_Get]
AS

/*
Created: 20250714@Lilac.Nguyen
Task: Get Setting Companys
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
		cfg.EnableLetstalk,
		cfg.WhitelistIPs,
		cur.Currency
	FROM dbo.Company c

	LEFT JOIN (
		SELECT 
			CompanyId,
			[HasBIO],
			[WhitelistIPs],
			[EnableLetstalk],
			[Currency]
		FROM (
			SELECT 
				CompanyId, [Key], [Value]
			FROM dbo.SystemConfigs
			WHERE [Key] IN ('HasBIO', 'WhitelistIPs', 'EnableLetstalk', 'Currency')
		) AS raw
		PIVOT (
			MAX([Value])
			FOR [Key] IN ([HasBIO], [WhitelistIPs], [EnableLetstalk], [Currency])
		) AS pvt
	) cfg ON c.CompanyId = cfg.CompanyId

	LEFT JOIN (
		SELECT 
			sc.CompanyId,
			STUFF((
				SELECT ', ' + c.CurrencyCode
				FROM STRING_SPLIT(sc.[Value], ',') AS s
				JOIN dbo.Currency c ON c.Id = TRY_CAST(s.value AS INT)
				FOR XML PATH(''), TYPE
			).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS Currency
		FROM dbo.SystemConfigs sc
		WHERE sc.[Key] = 'Currency'
	) cur ON cur.CompanyId = c.CompanyId

	WHERE ISNULL(c.IsDeleted, 0) = 0
	ORDER BY c.CompanyId;

END;
