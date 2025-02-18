DECLARE @NewCompanyId INT = 3;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'UTC'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 

-- #region UNIT TABLE
INSERT INTO bodb_HRM.dbo.Unit (Code, Name, IsActive, ModifiedBy, ModifiedDate, IsDeleted, CompanyId, OldUnitId)
SELECT Code, Name, IsActive, ModifiedBy, ModifiedDate, IsDeleted, @NewCompanyId, UnitId 
FROM SMSHRM.dbo.Unit;
-- #endregion

-- #region DEPARTMENT TABLE
INSERT INTO bodb_HRM.dbo.Department (Code, Name, UnitId, IsActive, ModifiedBy, ModifiedDate, IsDeleted, CompanyId, OldDepartmentId)
SELECT Code, Name, UnitId, IsActive, ModifiedBy, ModifiedDate, IsDeleted, @NewCompanyId, DepartmentId 
FROM SMSHRM.dbo.Department;
-- #endregion

-- #region SECTION TABLE

INSERT INTO bodb_HRM.dbo.Section (Code, Name, DepartmentId, IsActive, ModifiedBy, ModifiedDate, IsDeleted, CompanyId, OldSectionId)
SELECT Code, Name, DepartmentId, IsActive, ModifiedBy, ModifiedDate, IsDeleted, @NewCompanyId, SectionId 
FROM SMSHRM.dbo.Section;

-- #endregion

-- #region GROUP TABLE

INSERT INTO bodb_HRM.dbo.[Group] (
    Code, Name, SectionId, Rank, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, IsDeleted, MailGroup,
    LocalBasicAnnualLeaveBalance, LocalWorkingDays, LocalWorkingHours, LocalOffDaysbyWeek,
    ExpatBasicAnnualLeaveBalance, ExpatWorkingDays, ExpatWorkingHours, ExpatOffDaysbyWeek,
    LocalWorkingHoursbyWeek, ExpatWorkingHoursbyWeek, CompanyId, OldGroupId
)
SELECT Code, Name, SectionId, Rank, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, IsDeleted, MailGroup,
    LocalBasicAnnualLeaveBalance, LocalWorkingDays, LocalWorkingHours, LocalOffDaysbyWeek,
    ExpatBasicAnnualLeaveBalance, ExpatWorkingDays, ExpatWorkingHours, ExpatOffDaysbyWeek,
    LocalWorkingHoursbyWeek, ExpatWorkingHoursbyWeek, @NewCompanyId, GroupId 
FROM SMSHRM.dbo.[Group];
-- #endregion

-- TODO: Not done (waiting for the new structure)
-- TODO: Update timezone