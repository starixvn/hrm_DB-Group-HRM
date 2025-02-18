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

-- #region SHIFT TABLE

INSERT INTO bodb_HRM.dbo.Shift (
    Code, Name, BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, 
    OrderNo, BeginBreakTime, EndBreakTime, CrossDay, Color, TotalHours, IsInAfterDay, IsOutAfterDay, 
    IsDisabled, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, OWPModifiedDate, OWPSyncDate, 
    CompanyId, OldShiftId
)
SELECT 
    s.Code, 
    s.Name, 
    s.BeginCheckInTime, 
    s.EndCheckInTime, 
    s.BeginCheckOutTime, 
    s.EndCheckOutTime, 
    s.BreakTimeMins, 
    s.OrderNo, 
    s.BeginBreakTime, 
    s.EndBreakTime, 
    s.CrossDay, 
    s.Color, 
    s.TotalHours, 
    s.IsInAfterDay, 
    s.IsOutAfterDay, 
    s.IsDisabled, 
    em_created.EmpId, 
    s.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    em_modified.EmpId, 
    s.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    s.OWPModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    s.OWPSyncDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    @NewCompanyId, 
    s.ShiftID 
FROM SMSHRM.dbo.Shift s
LEFT JOIN @EmployeeMapping em_created ON s.CreatedBy = em_created.OldEmpId
LEFT JOIN @EmployeeMapping em_modified ON s.ModifiedBy = em_modified.OldEmpId;

    
-- #endregion

-- #region LEAVE TYPE TABLE

INSERT INTO bodb_HRM.dbo.LeaveType (
    LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction, 
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, 
    OrderNo, Description, CompanyId
)
SELECT LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction, 
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, 
    OrderNo, Description, @NewCompanyId 
FROM SMSHRM.dbo.LeaveType;

-- #endregion

-- #region HOLIDAY TABLE
INSERT INTO bodb_HRM.dbo.Holiday (HolidayName, FromDate, ToDate, TypeId, CompanyId, OldHolidayId)
SELECT HolidayName, FromDate, ToDate, TypeId, @NewCompanyId, Id 
FROM SMSHRM.dbo.Holiday;
-- #endregion

-- #region MEMO TABLE

INSERT INTO bodb_HRM.dbo.Memo (
    RefNo, Contents, Subject, SentTo, SentFrom, ForInfo, TotalPages, 
    SentDate, Category, Type, Enabled, CompanyId, OldId
)
SELECT RefNo, Contents, Subject, SentTo, SentFrom, ForInfo, TotalPages, 
    SentDate, Category, Type, Enabled, @NewCompanyId, Id 
FROM SMSHRM.dbo.Memo;
-- #endregion

-- #region SYSTEM CONFIGS TABLE
INSERT INTO bodb_HRM.dbo.SystemConfigs ([Key], [Value], CompanyId)
SELECT [Key], [Value], @NewCompanyId 
FROM SMSHRM.dbo.SystemConfigs;
-- #endregion
