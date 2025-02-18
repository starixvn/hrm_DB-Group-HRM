-- #region DISCIPLINE TYPE TABLE
INSERT INTO bodb_HRM.dbo.DisciplineType (DisciplineTypeId, Name, Score, IsActive)
SELECT DisciplineTypeId, Name, Score, IsActive 
FROM SMSHRM.dbo.DisciplineType;
-- #endregion

-- #region MAP COMPANY TỪ UI0C
SET IDENTITY_INSERT bodb_HRM.dbo.Company ON; 

INSERT INTO bodb_HRM.dbo.Company (CompanyId, Name, CountryCode, IsActive)
SELECT 
    CompanyId, 
    Name, 
    CASE 
        WHEN Country = 'Vietnam' THEN 'VN'
        WHEN Country = 'Philippines' THEN 'PH'
        ELSE NULL 
    END AS CountryCode,
    IsActive
FROM bodb_IUC.dbo.Company;

SET IDENTITY_INSERT bodb_HRM.dbo.Company OFF;

-- #endregion

-- #region COUNTRY TABLE 
INSERT INTO bodb_HRM.dbo.Country (
    CountryCode, CountryName, CountryOrder, Nationality
)
SELECT 
    c.CountryCode, 
    c.CountryName, 
    c.CountryOrder, 
    c.Nationality
FROM SMSHRM.dbo.Country c;
-- #endregion
