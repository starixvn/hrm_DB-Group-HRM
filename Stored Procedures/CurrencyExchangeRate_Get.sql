/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CurrencyExchangeRate_Get]
AS
/*
    Created: 20251114@Lilac
    Task : Get currency exchange rate
    DB: bodb_HRM

    Revisions:
        20251114@Lilac: init
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);

    SELECT 
        c.Id AS CurrencyId,
        c.CurrencyCode AS BaseCurrency,
        cer.ExchangeRate AS ToUsd,
        cer.EffectiveDate,
        cer.ModifiedDate,
        CASE 
            WHEN EXISTS (
                SELECT 1
                FROM SystemConfigs sc
                CROSS APPLY STRING_SPLIT(sc.[Value], ',') AS tmpc
                WHERE sc.[Key] = 'Currency'
                    AND CAST(tmpc.value AS INT) = c.Id
            ) THEN 1
            ELSE 0
        END AS IsUsed
    FROM Currency c
    INNER JOIN CurrencyExchangeRate cer ON c.Id = cer.CurrencyId 
    ORDER BY cer.EffectiveDate DESC;
END
GO
