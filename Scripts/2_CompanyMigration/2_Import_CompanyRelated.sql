DECLARE @NewCompanyId INT = 3;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'UTC'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 

-- #region SHIFT TABLE

INSERT INTO bodb_HRM.dbo.Shift (
    Code, Name, BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, 
    OrderNo, BeginBreakTime, EndBreakTime, CrossDay, Color, TotalHours, IsInAfterDay, IsOutAfterDay, 
    IsDisabled, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, OWPModifiedDate, OWPSyncDate, 
    CompanyId, OldShiftId
)
SELECT Code, Name, BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, 
    OrderNo, BeginBreakTime, EndBreakTime, CrossDay, Color, TotalHours, IsInAfterDay, IsOutAfterDay, 
    IsDisabled, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, OWPModifiedDate, OWPSyncDate, 
    @NewCompanyId, ShiftID 
FROM SMSHRM.dbo.Shift;

UPDATE S
SET S.CreatedBy = E.EmpId
FROM bodb_HRM.dbo.Shift S
JOIN bodb_HRM.dbo.Employee E ON S.CreatedBy = E.OldEmpId;

UPDATE S
SET S.ModifiedBy = E.EmpId
FROM bodb_HRM.dbo.Shift S
JOIN bodb_HRM.dbo.Employee E ON S.ModifiedBy = E.OldEmpId;

UPDATE bodb_HRM.dbo.Shift
SET 
    CreatedDate = CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ModifiedDate = ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    OWPModifiedDate = OWPModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    OWPSyncDate = OWPSyncDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone;
    
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
