USE bodb_HRM
GO

DECLARE @NewCompanyId INT = 3;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time',
    @TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time'-- hong_kong: China Standard Time 

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
INSERT INTO dbo.EmployeeAttendance (
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
    INNER JOIN @EmployeeMapping em ON ea.EmpId = em.OldEmpId
    LEFT JOIN dbo.Shift s_new ON ea.ShiftId = s_new.OldShiftId AND s_new.CompanyId = @NewCompanyId
-- #endregion

-- #region EMPLOYEE CALENDAR TABLE
INSERT INTO dbo.EmployeeCalendar (
    WorkDate, EmpId, ShiftId, IsHoliday, IsOffDay, IsLeaveDay, LeaveTypeId, 
    LateIn, EarlyOut, RequestedCheckinTime, RequestedCheckoutTime, ChangeShiftId, 
    LeaveDay, ModifiedDate, ModifiedBy, IsKeepInView, LeaveTypeId2, 
    IsPublic, IsFixedOffDay, OWPModifiedDate, OWPSyncDate
)
SELECT ec.WorkDate, 
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
    INNER JOIN @EmployeeMapping em ON ec.EmpId = em.OldEmpId
    LEFT JOIN dbo.Shift s ON ec.ShiftId = s.OldShiftId AND s.CompanyId = @NewCompanyId
    LEFT JOIN dbo.Shift s_cs ON ec.ChangeShiftId = s_cs.OldShiftId AND s_cs.CompanyId = @NewCompanyId
    LEFT JOIN @EmployeeMapping em_modified ON ec.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE CONTRACT TABLE

INSERT INTO dbo.EmployeeContract (
    EmpID, BankAccount, TaxCode, SocialInsuranceNo, RegisteredHospital, 
    Contract1, FromDate1, ToDate1, Contract2, FromDate2, ToDate2, 
    Contract3, FromDate3, ToDate3, Contract4, FromDate4, ToDate4, 
    Contract5, FromDate5, ToDate5, History
)
SELECT em.EmpId, 
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
    INNER JOIN @EmployeeMapping em ON ec.EmpID = em.OldEmpId
-- #endregion

-- #region EMPLOYEE DEFAULT SHIFT TABLE
INSERT INTO dbo.EmployeeDefaultShift (
    EmpID, MonShift, TueShift, WedShift, ThuShift, FriShift, SatShift, SunShift
)
SELECT em.EmpId,
    s_mon.ShiftId, 
    s_tue.ShiftId, 
    s_wed.ShiftId, 
    s_thu.ShiftId, 
    s_fri.ShiftId, 
    s_sat.ShiftId, 
    s_sun.ShiftId
FROM SMSHRM.dbo.EmployeeDefaultShift eds
    INNER JOIN @EmployeeMapping em ON eds.EmpID = em.OldEmpId 
    LEFT JOIN dbo.Shift s_mon ON eds.MonShift = s_mon.OldShiftId AND s_mon.CompanyId = @NewCompanyId
    LEFT JOIN dbo.Shift s_tue ON eds.TueShift = s_tue.OldShiftId AND s_tue.CompanyId = @NewCompanyId
    LEFT JOIN dbo.Shift s_wed ON eds.WedShift = s_wed.OldShiftId AND s_wed.CompanyId = @NewCompanyId
    LEFT JOIN dbo.Shift s_thu ON eds.ThuShift = s_thu.OldShiftId AND s_thu.CompanyId = @NewCompanyId
    LEFT JOIN dbo.Shift s_fri ON eds.FriShift = s_fri.OldShiftId AND s_fri.CompanyId = @NewCompanyId
    LEFT JOIN dbo.Shift s_sat ON eds.SatShift = s_sat.OldShiftId AND s_sat.CompanyId = @NewCompanyId
    LEFT JOIN dbo.Shift s_sun ON eds.SunShift = s_sun.OldShiftId AND s_sun.CompanyId = @NewCompanyId
-- #endregion

-- #region EMPLOYEE PATERNITY TABLE
INSERT INTO dbo.EmployeePaternity (
    EmpId, ChildBornDate, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, 
    LeaveDay, Remark, BalanceDay, OldPaternityId
)
SELECT em.EmpId, 
    ep.ChildBornDate, 
    em_created.EmpId, 
    ep.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    em_modified.EmpId, 
    ep.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ep.LeaveDay, 
    ep.Remark, 
    ep.BalanceDay, 
    ep.PaternityId
FROM SMSHRM.dbo.EmployeePaternity ep
    INNER JOIN @EmployeeMapping em ON ep.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_created ON ep.CreatedBy = em_created.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON ep.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE POSTNATAL TABLE
INSERT INTO dbo.EmployeePostnatal (
    EmpId, FromDate, ToDate, WorkingHours, NormalWorkingHours, Remark, 
    CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, OldPostnatalId
)
SELECT em.EmpId, 
    ep.FromDate, 
    ep.ToDate, 
    ep.WorkingHours, 
    ep.NormalWorkingHours, 
    ep.Remark, 
    em_created.EmpId, 
    ep.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    em_modified.EmpId, 
    ep.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ep.PostnatalId
FROM SMSHRM.dbo.EmployeePostnatal ep
    INNER JOIN @EmployeeMapping em ON ep.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_created ON ep.CreatedBy = em_created.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON ep.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE RELATIONSHIP TABLE
INSERT INTO dbo.EmployeeRelationship (
    EmpId, FullName, Phone, Relationship, DateOfBirth, Gender, IsEmergency, 
    CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, OldId
)
SELECT em.EmpId, 
    er.FullName, 
    er.Phone, 
    er.Relationship, 
    er.DateOfBirth, 
    er.Gender, 
    er.IsEmergency, 
    er.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    em_created.EmpId, 
    er.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    em_modified.EmpId,
    er.Id 
FROM SMSHRM.dbo.EmployeeRelationship er
    INNER JOIN @EmployeeMapping em ON er.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_created ON er.CreatedBy = em_created.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON er.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE ROLE TABLE
INSERT INTO dbo.EmployeeRole (
    EmployeeId, RoleId, ModifiedBy, ModifiedDate
)
SELECT em.EmpId, 
    er.RoleId, 
    em_modified.EmpId, 
    er.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM SMSHRM.dbo.EmployeeRole er
    INNER JOIN @EmployeeMapping em ON er.EmployeeId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON er.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE SUMMARY TABLE
INSERT INTO dbo.EmployeeSummary (
    EmpId, AnnualLeaveBalance, KeepInViewBalance, CanOT, IsLocal, WorkingDays, 
    WorkingHours, IsDefaultSchedule, CompanyDate, CountryCode, IsTopManager, 
    OffDaysbyWeek, Unit, IsExpatUseHoliday, MilitaryFromDate, MilitaryToDate, 
    Remark, SpecialOT, HospitalizationLeaveBalance, SickLeaveBalance, WorkingHoursByWeek
)
SELECT em.EmpId,
    es.AnnualLeaveBalance, 
    es.KeepInViewBalance, 
    es.CanOT, 
    es.IsLocal, 
    es.WorkingDays, 
    es.WorkingHours, 
    es.IsDefaultSchedule, 
    es.CompanyDate, 
    es.CountryCode, 
    es.IsTopManager, 
    es.OffDaysbyWeek, 
    es.Unit, 
    es.IsExpatUseHoliday, 
    es.MilitaryFromDate, 
    es.MilitaryToDate, 
    es.Remark, 
    es.SpecialOT, 
    es.HospitalizationLeaveBalance, 
    es.SickLeaveBalance, 
    es.WorkingHoursByWeek
FROM SMSHRM.dbo.EmployeeSummary es
    INNER JOIN @EmployeeMapping em ON es.EmpId = em.OldEmpId
-- TODO: CHECK UNIT ?
-- #endregion

-- #region EMPLOYEE SUPERVISOR TABLE
INSERT INTO dbo.EmployeeSupervisor (
    OwnerId, EmpId, ActionType, RequestType, ModifiedBy, ModifiedDate, 
    OrderNo, OrderCode, IsDeleted
)
SELECT em_owner.EmpId,
    em.EmpId,
    es.ActionType, 
    es.RequestType, 
    em_modified.EmpId,
    es.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    es.OrderNo, 
    es.OrderCode, 
    es.IsDeleted
FROM SMSHRM.dbo.EmployeeSupervisor es
    INNER JOIN @EmployeeMapping em ON es.EmpId = em.OldEmpId
    INNER JOIN @EmployeeMapping em_owner ON es.OwnerId = em_owner.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON es.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE WORK FROM HOME TABLE
INSERT INTO dbo.EmployeeWorkFromHome (
    EmpId, FromDate, ToDate, Remark, ModifiedBy, ModifiedDate, OldEmployeeWorkFromHomeId
)
SELECT em.EmpId, 
    ewfh.FromDate, 
    ewfh.ToDate, 
    ewfh.Remark, 
    em_modified.EmpId, 
    ewfh.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ewfh.EmployeeWorkFromHomeId
FROM SMSHRM.dbo.EmployeeWorkFromHome ewfh
    INNER JOIN @EmployeeMapping em ON ewfh.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON ewfh.ModifiedBy = em_modified.OldEmpId
-- #endregion