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

-- #region EMPLOYEE ATTENDANCE TABLE
INSERT INTO bodb_HRM.dbo.EmployeeAttendance (
    AttendanceDate, EmpId, ShiftId, InFixed, OutFixed, 
    ExpectedInTime, ExpectedOutTime, LateIn, EarlyOut, 
    LeaveTypeId, Absence, Notes, TotalWorkHours, 
    IsRightShift, IsLocked, LeaveDay, InsertDate, LeaveTypeId2
)
SELECT 
    ea.AttendanceDate, 
    em.EmpId, 
    s_new.ShiftId, 
    ea.InFixed AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ea.OutFixed AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ea.ExpectedInTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ea.ExpectedOutTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ea.LateIn, 
    ea.EarlyOut, 
    ea.LeaveTypeId, 
    ea.Absence, 
    ea.Notes, 
    ea.TotalWorkHours, 
    ea.IsRightShift, 
    ea.IsLocked, 
    ea.LeaveDay, 
    ea.InsertDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    ea.LeaveTypeId2
FROM SMSHRM.dbo.EmployeeAttendance ea
LEFT JOIN @EmployeeMapping em ON ea.EmpId = em.OldEmpId
LEFT JOIN bodb_HRM.dbo.Shift s_new ON ea.ShiftId = s_new.OldShiftId AND s_new.CompanyId = @NewCompanyId
WHERE em.EmpId IS NOT NULL; 
-- #endregion

-- #region EMPLOYEE CALENDAR TABLE
INSERT INTO bodb_HRM.dbo.EmployeeCalendar (
    WorkDate, EmpId, ShiftId, IsHoliday, IsOffDay, IsLeaveDay, LeaveTypeId, 
    LateIn, EarlyOut, RequestedCheckinTime, RequestedCheckoutTime, ChangeShiftId, 
    LeaveDay, ModifiedDate, ModifiedBy, IsKeepInView, LeaveTypeId2, 
    IsPublic, IsFixedOffDay, OWPModifiedDate, OWPSyncDate
)
SELECT 
    ec.WorkDate, 
    em.EmpId, 
    s.ShiftId, 
    ec.IsHoliday, 
    ec.IsOffDay, 
    ec.IsLeaveDay, 
    ec.LeaveTypeId, 
    ec.LateIn, 
    ec.EarlyOut, 
    ec.RequestedCheckinTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ec.RequestedCheckoutTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    s_cs.ShiftId,
    ec.LeaveDay, 
    ec.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    em_modified.EmpId, 
    ec.IsKeepInView, 
    ec.LeaveTypeId2, 
    ec.IsPublic, 
    ec.IsFixedOffDay, 
    ec.OWPModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ec.OWPSyncDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM SMSHRM.dbo.EmployeeCalendar ec
LEFT JOIN @EmployeeMapping em ON ec.EmpId = em.OldEmpId
LEFT JOIN bodb_HRM.dbo.Shift s ON ec.ShiftId = s.OldShiftId AND s.CompanyId = @NewCompanyId
LEFT JOIN bodb_HRM.dbo.Shift s_cs ON ec.ChangeShiftId = s_cs.OldShiftId AND s_cs.CompanyId = @NewCompanyId
LEFT JOIN @EmployeeMapping em_modified ON ec.ModifiedBy = em_modified.OldEmpId
WHERE em.EmpId IS NOT NULL; 
-- #endregion

-- #region EMPLOYEE CONTRACT TABLE
INSERT INTO bodb_HRM.dbo.EmployeeContract (
    EmpID, BankAccount, TaxCode, SocialInsuranceNo, RegisteredHospital, 
    Contract1, FromDate1, ToDate1, Contract2, FromDate2, ToDate2, 
    Contract3, FromDate3, ToDate3, Contract4, FromDate4, ToDate4, 
    Contract5, FromDate5, ToDate5, History
)
SELECT 
    em.EmpId, 
    ec.BankAccount, 
    ec.TaxCode, 
    ec.SocialInsuranceNo, 
    ec.RegisteredHospital, 
    ec.Contract1, 
    ec.FromDate1, 
    ec.ToDate1, 
    ec.Contract2, 
    ec.FromDate2, 
    ec.ToDate2, 
    ec.Contract3, 
    ec.FromDate3, 
    ec.ToDate3, 
    ec.Contract4, 
    ec.FromDate4, 
    ec.ToDate4, 
    ec.Contract5, 
    ec.FromDate5, 
    ec.ToDate5, 
    ec.History
FROM SMSHRM.dbo.EmployeeContract ec
LEFT JOIN @EmployeeMapping em ON ec.EmpID = em.OldEmpId
WHERE em.EmpId IS NOT NULL; 
-- #endregion