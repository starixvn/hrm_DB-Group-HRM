/*
    Created: Henry@20250611
    Task: add allowance for nexcel
    DB: bodb_HRM

    Revisions:
        20250611@Henry: add allowance for nexcel [Redmine: #243640]
*/


DECLARE @CompanyId INT = 1;

-- Update Management Allowance items
;WITH AmountMap AS (
    SELECT v.ItemName, v.EncryptedAmount
    FROM (VALUES
        ('M1-B', 'EG8I5PFhzHg='),          -- 6,250,000
        ('M1-A', 'EG8I5PFhzHg='),          -- 6,250,000
        ('M2-B', 'EG8I5PFhzHg='),          -- 6,250,000
        ('M2-A', '3BOF5KAuUYw='),          -- 7,500,000
        ('M3-B', 'hH4IAoxile3Prpd5k6B66w=='),  -- 18,750,000
        ('M3-A', 'xYu3n7kiyNg6CHLO2Jz45w=='),  -- 22,500,000
        ('M4'  , 'h77Cq0dTLkIe7/ugEawuZQ==')   -- 30,000,000
    ) AS v(ItemName, EncryptedAmount)
)
UPDATE ais
SET ais.[Amount] = am.EncryptedAmount
FROM [dbo].[AllowanceItemSetting] AS ais
INNER JOIN [dbo].[PayrollItemSetting] AS pis
    ON ais.[PayrollItemSettingId] = pis.[PayrollItemSettingId]
INNER JOIN AmountMap AS am
    ON ais.[ItemName] = am.[ItemName]
WHERE pis.[CompanyId] = @CompanyId
  AND pis.[Type] = 'Management Allowance';

-- Insert EmployeePayrollAllowance
-- 1) Lấy danh sách nhân viên và cấp bậc quản lý hiện tại (M1-A, M2-B...)
WITH EmpWithGrade AS (
    SELECT 
        ce.EmpId,
        ce.CompanyId,
        mg.Code AS GradeCode
    FROM [dbo].[CompanyEmployee] AS ce
    LEFT JOIN [HRM].[dbo].[EmployeeManagementGrade] AS emg WITH (NOLOCK)
        ON ce.EmpId = emg.EmpId
        AND emg.IsCurrentUsed = 1
        AND ISNULL(emg.IsDeleted, 0) = 0
    LEFT JOIN [HRM].[dbo].[ManagementGrade] AS mg WITH (NOLOCK)
        ON emg.ManagementGradeId = mg.ManagementGradeId
    WHERE ce.CompanyId = @CompanyId
),

-- 2) Lấy các allowance setting thuộc "Management Allowance" của company đó
Allowance AS (
    SELECT 
        ais.AllowanceItemSettingId,
        ais.ItemName,
        pis.CompanyId
    FROM [dbo].[AllowanceItemSetting] AS ais
    INNER JOIN [dbo].[PayrollItemSetting] AS pis
        ON ais.PayrollItemSettingId = pis.PayrollItemSettingId
    WHERE pis.CompanyId = @CompanyId
      AND pis.[Type] = 'Management Allowance'
)

-- 3) Insert vào EmployeePayrollAllowance
INSERT INTO [dbo].[EmployeePayrollAllowance] (EmpId, AllowanceItemSettingId)
SELECT 
    e.EmpId,
    a.AllowanceItemSettingId
FROM EmpWithGrade AS e
INNER JOIN Allowance AS a
    ON a.CompanyId = e.CompanyId
   AND a.ItemName = e.GradeCode      -- map M1-A, M1-B
WHERE e.GradeCode IS NOT NULL
  -- tránh insert trùng
  AND NOT EXISTS (
        SELECT 1
        FROM [dbo].[EmployeePayrollAllowance] ep
        WHERE ep.EmpId = e.EmpId
          AND ep.AllowanceItemSettingId = a.AllowanceItemSettingId
  );