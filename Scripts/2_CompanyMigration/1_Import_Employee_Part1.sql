USE bodb_HRM
GO

DECLARE @NewCompanyId INT = 3;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 

DECLARE @EmployeeMapping TABLE (
    EmpId INT,
    OldEmpId INT,
    CompanyId INT
);

-- #region EMPLOYEE TABLE
INSERT INTO dbo.Employee (
    EmpId, Code, DomainUsername, FullName, NickName, DOB, Email, JobTitleId, 
    [Enabled], Phone, Gender, GroupId, Roles, ManagerId, JoinedDate, ConfirmedDate, 
    ResignedDate, Skype, Yahoo, Marriage, LastLogin, CreatedDate, CreatedBy, 
    ModifiedDate, ModifiedBy, isDeleted, PermanentAddress, CurrentAddress, 
    IdCardNumber, PassportNo, PassportExp, [Password], ChineseName, PlaceOfbirth, 
    Ethnic, [Native], Religion, DateOfIDCard, PlaceOfIDCard, HomePhone, Qualification, 
    Major, PasswordReset, EmployeeCard, PickupRemark, TeamDate, PromotionDate, 
    LetsTalk, JobLevelId, ManagementLevelId, UserId, UC_ModifiedDate, UC_SyncDate, ResignedReason, 
    ExpertGradeId, OldEmpId  -- Keep Old Employee ID
)
OUTPUT INSERTED.EmpId, INSERTED.OldEmpId, @NewCompanyId INTO @EmployeeMapping  -- Store new & old EmpId
SELECT 
    UserId, Code, DomainUsername, FullName, NickName, DOB, Email, JobTitleId,
    [Enabled], Phone, Gender, GroupId, Roles, ManagerId, JoinedDate, ConfirmedDate, 
    ResignedDate, Skype, Yahoo, Marriage, 
    LastLogin,
    CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    CreatedBy, 
    ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    ModifiedBy, 
    isDeleted, PermanentAddress, CurrentAddress, 
    IdCardNumber, PassportNo, PassportExp, [Password], ChineseName, PlaceOfbirth, 
    Ethnic, [Native], Religion, DateOfIDCard, PlaceOfIDCard, HomePhone, Qualification, 
    Major, PasswordReset, EmployeeCard, PickupRemark, TeamDate, PromotionDate, 
    LetsTalk, JobLevelId, ManagementLevelId, UserId, UC_ModifiedDate, UC_SyncDate, ResignedReason, 
    ExpertGradeId, EmpId AS OldEmpId  -- Keep track of old EmpId
FROM HRM.dbo.Employee WITH (NOLOCK)
WHERE UserId is not null

-- Insert into CompanyEmployee using NewEmpId and CompanyId
INSERT INTO dbo.CompanyEmployee (EmpId, CompanyId)
SELECT EmpId, @NewCompanyId FROM @EmployeeMapping;

UPDATE emp
SET 
    emp.CreatedBy = em_created.EmpId,
    emp.ModifiedBy = em_modified.EmpId,
    emp.ManagerId = em_manager.EmpId
FROM dbo.Employee emp
LEFT JOIN @EmployeeMapping em_created ON emp.CreatedBy = em_created.OldEmpId AND em_created.CompanyId = @NewCompanyId
LEFT JOIN @EmployeeMapping em_modified ON emp.ModifiedBy = em_modified.OldEmpId AND em_modified.CompanyId = @NewCompanyId
LEFT JOIN @EmployeeMapping em_manager ON emp.ManagerId = em_manager.OldEmpId AND em_manager.CompanyId = @NewCompanyId;
-- GroupId sẽ map lại sau ở phần OrgChart vì hiện tại chưa có GroupId mới
-- JobTitleId sẽ map lại sau ở phần CompanyRelate - LookupData vì hiện tại chưa có data mới    

-- TODO: Mapping JobLevel + GradeLevel
-- TODO: Lưu ý khi user add emp mới trên hệ thống có thể trùng vs EmpdI ở company khác sau này migrate. Cần xem xét cách xử lý migrate hết rồi mới chạy hệ thống
-- #endregion


