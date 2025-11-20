/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER TABLE [SalaryStructureDetail] 
ADD ExpatJobLevelAddOn VARCHAR(100) NULL
GO

ALTER TABLE AllowanceItemSetting
ADD CurrencyId INT NULL
GO

ALTER TABLE EmployeePayroll
ADD SpecialSubsidyCurrencyId INT NULL
GO

ALTER TABLE [dbo].[Currency]
ADD [Rounding] SMALLINT NULL;
GO

CREATE TABLE [dbo].[CurrencyExchangeRate](
    [EffectiveDate] [date] NOT NULL,
    [CurrencyId] [int] NOT NULL,
    [ExchangeRate] [decimal](20, 10) NULL,
    [ModifiedBy] [int] NULL,
    [ModifiedDate] [datetime] NULL,
    CONSTRAINT [PK_CurrencyExchangeRate] PRIMARY KEY CLUSTERED 
    (
        [EffectiveDate] ASC,
        [CurrencyId] ASC
    )
);
GO

;WITH CurrencyConfig AS
(
    SELECT
        CompanyId,
        FirstCurrencyId = CAST(
            LEFT(
                LTRIM(RTRIM([Value])),
                CASE 
                    WHEN CHARINDEX(',', LTRIM(RTRIM([Value]))) > 0 
                        THEN CHARINDEX(',', LTRIM(RTRIM([Value]))) - 1
                    ELSE LEN(LTRIM(RTRIM([Value])))
                END
            ) AS INT
        )
    FROM SystemConfigs
    WHERE [Key] = 'Currency'
      AND NULLIF(LTRIM(RTRIM([Value])), '') IS NOT NULL
)
-- 2. Update EmployeePayroll.SpecialSubsidyCurrencyId
UPDATE ep
SET ep.SpecialSubsidyCurrencyId = c.FirstCurrencyId
FROM EmployeePayroll AS ep
JOIN CompanyEmployee AS ce
    ON ce.EmpId = ep.EmpId
JOIN CurrencyConfig AS c
    ON c.CompanyId = ce.CompanyId
WHERE ep.SpecialSubsidy IS NOT NULL
GO

;WITH CurrencyConfig AS
(
    SELECT
        CompanyId,
        FirstCurrencyId = CAST(
            LEFT(
                LTRIM(RTRIM([Value])),
                CASE 
                    WHEN CHARINDEX(',', LTRIM(RTRIM([Value]))) > 0 
                        THEN CHARINDEX(',', LTRIM(RTRIM([Value]))) - 1
                    ELSE LEN(LTRIM(RTRIM([Value])))
                END
            ) AS INT
        )
    FROM SystemConfigs
    WHERE [Key] = 'Currency'
      AND NULLIF(LTRIM(RTRIM([Value])), '') IS NOT NULL
)
-- 2. Update AllowanceItemSetting.CurrencyId
UPDATE ais
SET ais.CurrencyId = c.FirstCurrencyId
FROM AllowanceItemSetting AS ais
JOIN PayrollItemSetting AS pis
    ON pis.PayrollItemSettingId = ais.PayrollItemSettingId
JOIN CurrencyConfig AS c
    ON c.CompanyId = pis.CompanyId

