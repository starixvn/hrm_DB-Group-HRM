-- #region DISCIPLINE TYPE TABLE
INSERT INTO bodb_HRM.dbo.DisciplineType (DisciplineTypeId, Name, Score, IsActive)
SELECT DisciplineTypeId, Name, Score, IsActive 
FROM SMSHRM.dbo.DisciplineType;
-- #endregion

-- #region MAP COMPANY TỪ UI0C 
-- TODO: MIRA RUN THIS SCRIPT ON PRO 19/2/2025
-- SET IDENTITY_INSERT bodb_HRM.dbo.Company ON; 

-- INSERT INTO bodb_HRM.dbo.Company (CompanyId, Name, CountryCode, IsActive)
-- SELECT 
--     CompanyId, 
--     Name, 
--     CASE 
--         WHEN Country = 'Vietnam' THEN 'VN'
--         WHEN Country = 'Philippines' THEN 'PH'
--         ELSE NULL 
--     END AS CountryCode,
--     IsActive
-- FROM bodb_IUC.dbo.Company;
-- SET IDENTITY_INSERT bodb_HRM.dbo.Company OFF;

-- -- Reset lại IDENTITY để đảm bảo ID tự tăng đúng
-- DECLARE @MaxId INT;
-- SELECT @MaxId = MAX(Id) FROM bodb_HRM.dbo.Company;
-- DBCC CHECKIDENT ('bodb_HRM.dbo.Company', RESEED, @MaxId);

-- #endregion

-- #region COUNTRY TABLE 
-- TODO: MIRA RUN THIS SCRIPT ON PRO 19/2/2025
-- INSERT INTO bodb_HRM.dbo.Country (
--     CountryCode, CountryName, CountryOrder, Nationality
-- )
-- SELECT 
--     c.CountryCode, 
--     c.CountryName, 
--     c.CountryOrder, 
--     c.Nationality
-- FROM SMSHRM.dbo.Country c;
-- #endregion

-- #region LOG ACTION TABLE
INSERT INTO bodb_HRM.dbo.LogAction (
    LogActionId, Name, SpName
)
SELECT 
    la.LogActionId, 
    la.Name, 
    la.SpName
FROM SMSHRM.dbo.LogAction la;
-- #endregion

-- #region LOOKUP TABLE
SET IDENTITY_INSERT bodb_HRM.dbo.Lookup ON;

INSERT INTO bodb_HRM.dbo.Lookup (Id, Code, Name)
SELECT Id, Code, Name FROM SMSHRM.dbo.Lookup;

SET IDENTITY_INSERT bodb_HRM.dbo.Lookup OFF;

DECLARE @MaxId INT;
SELECT @MaxId = MAX(Id) FROM bodb_HRM.dbo.Lookup;
DBCC CHECKIDENT ('bodb_HRM.dbo.Lookup', RESEED, @MaxId);
-- #endregion
