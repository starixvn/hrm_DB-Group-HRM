DECLARE @NewCompanyId INT = 3;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 

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

-- #region DISCIPLINE TABLE
INSERT INTO bodb_HRM.dbo.Discipline (
    EmpId, WorkDate, DisciplineScore, IsOutOfControlReason, EmployeeComment, ApproverComment, 
    IsMissingCheckInOut, IsLateIn, IsEarlyOut, IsWorkingUnderTime, IsChangeShift, IsAbsent, 
    IsUnpaidLeave, IsUnpaidLeaveAbsent, IsUnplannedLeave, IsWeekendLeave, IsDeleted, 
    ModifiedBy, ModifiedDate, IsSevenDaysLeave
)
SELECT 
    em.EmpId, 
    d.WorkDate, 
    d.DisciplineScore, 
    d.IsOutOfControlReason, 
    d.EmployeeComment, 
    d.ApproverComment, 
    d.IsMissingCheckInOut, 
    d.IsLateIn, 
    d.IsEarlyOut, 
    d.IsWorkingUnderTime, 
    d.IsChangeShift, 
    d.IsAbsent, 
    d.IsUnpaidLeave, 
    d.IsUnpaidLeaveAbsent, 
    d.IsUnplannedLeave, 
    d.IsWeekendLeave, 
    d.IsDeleted, 
    em_modified.EmpId, 
    d.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    d.IsSevenDaysLeave
FROM SMSHRM.dbo.Discipline d
LEFT JOIN @EmployeeMapping em ON d.EmpId = em.OldEmpId
LEFT JOIN @EmployeeMapping em_modified ON d.ModifiedBy = em_modified.OldEmpId
WHERE d.IsDeleted != 1 and em.EmpId IS NOT NULL;
-- #endregion

-- #region DISCIPLINE GROUP RULE TABLE
INSERT INTO bodb_HRM.dbo.DisciplineGroupRule (
    GroupId, DisciplineTypeId, IsLocal, Value
)
SELECT 
    g.GroupId, 
    dgr.DisciplineTypeId, 
    dgr.IsLocal, 
    dgr.Value
FROM SMSHRM.dbo.DisciplineGroupRule dgr
LEFT JOIN bodb_HRM.dbo.[Group] g ON dgr.GroupId = g.OldGroupId AND g.CompanyId = @NewCompanyId;

-- #endregion

-- #region DISCIPLINE IGNORE TABLE
INSERT INTO bodb_HRM.dbo.DisciplineIgnore (
    EmpId, WorkDate, IsIgnoredMissingCheckInOut, IsIgnoredLateIn, IsIgnoredEarlyOut, 
    IsIgnoredWorkingUnderTime, IsIgnoredChangeShift, IsIgnoredAbsent, 
    IsIgnoredUnpaidLeave, IsIgnoredUnpaidLeaveAbsent, IsIgnoredUnplannedLeave, 
    IsIgnoredWeekendLeave, IsIgnoredSevenDaysLeave
)
SELECT 
    em.EmpId, 
    di.WorkDate, 
    di.IsIgnoredMissingCheckInOut, 
    di.IsIgnoredLateIn, 
    di.IsIgnoredEarlyOut, 
    di.IsIgnoredWorkingUnderTime, 
    di.IsIgnoredChangeShift, 
    di.IsIgnoredAbsent, 
    di.IsIgnoredUnpaidLeave, 
    di.IsIgnoredUnpaidLeaveAbsent, 
    di.IsIgnoredUnplannedLeave, 
    di.IsIgnoredWeekendLeave, 
    di.IsIgnoredSevenDaysLeave
FROM SMSHRM.dbo.DisciplineIgnore di
LEFT JOIN @EmployeeMapping em ON di.EmpId = em.OldEmpId
WHERE em.EmpId IS NOT NULL;

-- #endregion

-- #region DISCIPLINE IGNORE DETAIL TABLE
INSERT INTO bodb_HRM.dbo.DisciplineIgnoreDetail (
    WorkDate, EmpId, DisciplineTypeId, IgnoreBy, IgnoreDate
)
SELECT 
    di.WorkDate, 
    em.EmpId, 
    di.DisciplineTypeId, 
    em_ignore.EmpId, 
    di.IgnoreDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM SMSHRM.dbo.DisciplineIgnoreDetail di
LEFT JOIN @EmployeeMapping em ON di.EmpId = em.OldEmpId
LEFT JOIN @EmployeeMapping em_ignore ON di.IgnoreBy = em_ignore.OldEmpId
WHERE em.EmpId IS NOT NULL AND em_ignore.EmpId IS NOT NULL;

-- #endregion

-- #region DISCIPLINE OUT OF CONTROL TABLE
INSERT INTO bodb_HRM.dbo.DisciplineOutOfControl (
    EmpId, WorkDate, IsOutOfControlMissingCheckInOut, IsOutOfControlLateIn, 
    IsOutOfControlEarlyOut, IsOutOfControlWorkingUnderTime, IsOutOfControlChangeShift, 
    IsOutOfControlAbsent, IsOutOfControlUnpaidLeave, IsOutOfControlUnpaidLeaveAbsent, 
    IsOutOfControlUnplannedLeave, IsOutOfControlWeekendLeave, IsOutOfControlSevenDaysLeave
)
SELECT 
    em.EmpId, 
    doc.WorkDate, 
    doc.IsOutOfControlMissingCheckInOut, 
    doc.IsOutOfControlLateIn, 
    doc.IsOutOfControlEarlyOut, 
    doc.IsOutOfControlWorkingUnderTime, 
    doc.IsOutOfControlChangeShift, 
    doc.IsOutOfControlAbsent, 
    doc.IsOutOfControlUnpaidLeave, 
    doc.IsOutOfControlUnpaidLeaveAbsent, 
    doc.IsOutOfControlUnplannedLeave, 
    doc.IsOutOfControlWeekendLeave, 
    doc.IsOutOfControlSevenDaysLeave
FROM SMSHRM.dbo.DisciplineOutOfControl doc
LEFT JOIN @EmployeeMapping em ON doc.EmpId = em.OldEmpId
WHERE em.EmpId IS NOT NULL;

-- #endregion

-- #region DISCIPLINE REQUEST TRANS TABLE

INSERT INTO bodb_HRM.dbo.DisciplineRequestTrans (
    EmpId, WorkDate, RequestId, DisciplineTypeId, IsIgnored, 
    IsOutOfControl, ModifiedDate, ModifiedBy
)
SELECT 
    em.EmpId, 
    drt.WorkDate, 
    drt.RequestId, 
    drt.DisciplineTypeId, 
    drt.IsIgnored, 
    drt.IsOutOfControl, 
    drt.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    em_modified.EmpId
FROM SMSHRM.dbo.DisciplineRequestTrans drt
LEFT JOIN @EmployeeMapping em ON drt.EmpId = em.OldEmpId
LEFT JOIN @EmployeeMapping em_modified ON drt.ModifiedBy = em_modified.OldEmpId
WHERE em.EmpId IS NOT NULL;

-- #endregion

INSERT INTO bodb_HRM.dbo.OtherDiscipline
           (EmpId
           ,WorkDate
           ,DisciplineTypeId
           ,Score
           ,Comment
           ,IsDeleted
           ,ModifiedBy
           ,ModifiedDate)
     SELECT
           em.EmpId
           ,od.WorkDate
           ,od.DisciplineTypeId
           ,od.Score
           ,od.Comment
           ,od.IsDeleted
           ,em_modified.EmpId
           ,od.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone 
	FROM SMSHRM.dbo.OtherDiscipline od
	LEFT JOIN @EmployeeMapping em ON od.EmpId = em.OldEmpId
	LEFT JOIN @EmployeeMapping em_modified ON od.ModifiedBy = em_modified.OldEmpId;

