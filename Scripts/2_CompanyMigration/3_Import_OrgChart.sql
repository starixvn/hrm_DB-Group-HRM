DECLARE @NewCompanyId INT = 3;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'UTC'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 

-- #region TẠO MAPPING EMPLOYEE
DECLARE @EmployeeMapping TABLE (
    EmpId INT,
    OldEmpId INT,
    CompanyId INT
);

-- Lưu danh sách Employee có trong công ty hiện tại
INSERT INTO @EmployeeMapping (EmpId, OldEmpId, CompanyId)
SELECT DISTINCT e.EmpId, e.OldEmpId, ce.CompanyId  
FROM dbo.Employee AS e WITH (NOLOCK)
INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId 
WHERE ce.CompanyId = @NewCompanyId;
-- #endregion

-- #region UNIT TABLE
INSERT INTO bodb_HRM.dbo.Unit (Code, Name, IsActive, ModifiedBy, ModifiedDate, IsDeleted, CompanyId, OldUnitId)
SELECT 
    u.Code, 
    u.Name, 
    u.IsActive, 
    em.EmpId,
    u.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    u.IsDeleted, 
    @NewCompanyId,
    u.UnitId
FROM SMSHRM.dbo.Unit u
LEFT JOIN @EmployeeMapping em ON u.ModifiedBy = em.OldEmpId;


-- #endregion

-- #region DEPARTMENT TABLE
INSERT INTO bodb_HRM.dbo.Department (
    Code, Name, UnitId, IsActive, ModifiedBy, ModifiedDate, IsDeleted, CompanyId, OldDepartmentId
)
SELECT 
    d.Code, 
    d.Name, 
    u.UnitId, 
    d.IsActive, 
    em.EmpId,
    d.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    d.IsDeleted,  
    @NewCompanyId, 
    d.DepartmentId
FROM SMSHRM.dbo.Department d
LEFT JOIN bodb_HRM.dbo.Unit u ON d.UnitId = u.OldUnitId AND u.CompanyId = @NewCompanyId
LEFT JOIN @EmployeeMapping em ON d.ModifiedBy = em.OldEmpId;


-- #region SECTION TABLE

INSERT INTO bodb_HRM.dbo.Section (
    Code, Name, DepartmentId, IsActive, ModifiedBy, ModifiedDate, IsDeleted, CompanyId, OldSectionId
)
SELECT 
    s.Code, 
    s.Name, 
    d.DepartmentId, 
    s.IsActive, 
    em.EmpId, 
    s.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    s.IsDeleted, 
    @NewCompanyId, 
    s.SectionId
FROM SMSHRM.dbo.Section s
LEFT JOIN bodb_HRM.dbo.Department d ON s.DepartmentId = d.OldDepartmentId AND d.CompanyId = @NewCompanyId
LEFT JOIN @EmployeeMapping em ON s.ModifiedBy = em.OldEmpId;

-- #endregion

-- #region GROUP TABLE

INSERT INTO bodb_HRM.dbo.[Group] (
    Code, Name, SectionId, Rank, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, IsDeleted, MailGroup,
    LocalBasicAnnualLeaveBalance, LocalWorkingDays, LocalWorkingHours, LocalOffDaysbyWeek,
    ExpatBasicAnnualLeaveBalance, ExpatWorkingDays, ExpatWorkingHours, ExpatOffDaysbyWeek,
    LocalWorkingHoursbyWeek, ExpatWorkingHoursbyWeek, CompanyId, OldGroupId
)
SELECT 
    g.Code, 
    g.Name, 
    s.SectionId, 
    g.Rank, 
    g.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    em_created.EmpId, 
    g.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    em_modified.EmpId, 
    g.IsDeleted, 
    g.MailGroup,
    g.LocalBasicAnnualLeaveBalance, 
    g.LocalWorkingDays, 
    g.LocalWorkingHours, 
    g.LocalOffDaysbyWeek,
    g.ExpatBasicAnnualLeaveBalance, 
    g.ExpatWorkingDays, 
    g.ExpatWorkingHours, 
    g.ExpatOffDaysbyWeek,
    g.LocalWorkingHoursbyWeek, 
    g.ExpatWorkingHoursbyWeek, 
    @NewCompanyId, 
    g.GroupId
FROM SMSHRM.dbo.[Group] g
LEFT JOIN bodb_HRM.dbo.Section s ON g.SectionId = s.OldSectionId AND s.CompanyId = @NewCompanyId
LEFT JOIN @EmployeeMapping em_created ON g.CreatedBy = em_created.OldEmpId
LEFT JOIN @EmployeeMapping em_modified ON g.ModifiedBy = em_modified.OldEmpId;


-- #endregion

-- TODO: Not done (waiting for the new structure)