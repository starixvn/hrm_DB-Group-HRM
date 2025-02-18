-- DISCIPLINE TYPE TABLE
INSERT INTO bodb_HRM.dbo.DisciplineType (DisciplineTypeId, Name, Score, IsActive)
SELECT DisciplineTypeId, Name, Score, IsActive 
FROM SMSHRM.dbo.DisciplineType;
