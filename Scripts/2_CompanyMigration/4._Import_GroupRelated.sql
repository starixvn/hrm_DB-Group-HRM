DECLARE @NewCompanyId INT = 3;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'UTC'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 

-- #region EMPLOYEE GROUP TABLE
INSERT INTO bodb_HRM.dbo.EmployeeGroup (GroupId, EmpId, isMainGroup)
SELECT 
    g.GroupId,        -- Lấy GroupId mới từ bảng Group
    e.EmpId,          -- Lấy EmpId mới từ bảng Employee
    eg.isMainGroup    -- Giữ nguyên giá trị isMainGroup từ dữ liệu cũ
FROM SMSHRM.dbo.EmployeeGroup AS eg
INNER JOIN bodb_HRM.dbo.[Group] AS g ON eg.GroupId = g.OldGroupId AND g.CompanyId = @NewCompanyId
INNER JOIN bodb_HRM.dbo.Employee AS e ON eg.EmpID = e.OldEmpId;
-- #endregion

-- #region EMPLOYEE GROUP TABLE

-- #endregion