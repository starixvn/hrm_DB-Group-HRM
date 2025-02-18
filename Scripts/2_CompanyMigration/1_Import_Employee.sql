DECLARE @NewCompanyId INT = 3;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'UTC'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 

DECLARE @EmpIdMapping TABLE (NewEmpId INT, OldEmpId INT);

INSERT INTO bodb_HRM.dbo.Employee (
    EmpId, Code, DomainUsername, FullName, NickName, DOB, Email, JobTitleId, 
    Enabled, Phone, Gender, GroupId, Roles, ManagerId, JoinedDate, ConfirmedDate, 
    ResignedDate, Skype, Yahoo, Marriage, LastLogin, CreatedDate, CreatedBy, 
    ModifiedDate, ModifiedBy, isDeleted, PermanentAddress, CurrentAddress, 
    IdCardNumber, PassportNo, PassportExp, Password, ChineseName, PlaceOfbirth, 
    Ethnic, Native, Religion, DateOfIDCard, PlaceOfIDCard, HomePhone, Qualification, 
    Major, PasswordReset, EmployeeCard, PickupRemark, TeamDate, PromotionDate, 
    LetsTalk, JobLevelId, UserId, UC_ModifiedDate, UC_SyncDate, ResignedReason, 
    ExpertGradeId, OldEmpId  -- Keep Old Employee ID
)
OUTPUT INSERTED.EmpId, INSERTED.OldEmpId INTO @EmpIdMapping  -- Store new & old EmpId
SELECT 
    UserId, Code, DomainUsername, FullName, NickName, DOB, Email, JobTitleId, 
    Enabled, Phone, Gender, GroupId, Roles, ManagerId, JoinedDate, ConfirmedDate, 
    ResignedDate, Skype, Yahoo, Marriage, LastLogin, CreatedDate, CreatedBy, 
    ModifiedDate, ModifiedBy, isDeleted, PermanentAddress, CurrentAddress, 
    IdCardNumber, PassportNo, PassportExp, Password, ChineseName, PlaceOfbirth, 
    Ethnic, Native, Religion, DateOfIDCard, PlaceOfIDCard, HomePhone, Qualification, 
    Major, PasswordReset, EmployeeCard, PickupRemark, TeamDate, PromotionDate, 
    LetsTalk, JobLevelId, UserId, UC_ModifiedDate, UC_SyncDate, ResignedReason, 
    ExpertGradeId, EmpId AS OldEmpId  -- Keep track of old EmpId
FROM SMSHRM.dbo.Employee;

-- Insert into CompanyEmployee using NewEmpId and CompanyId
INSERT INTO bodb_HRM.dbo.CompanyEmployee (EmpId, CompanyId)
SELECT NewEmpId, @NewCompanyId FROM @EmpIdMapping;

UPDATE bodb_HRM.dbo.Employee
SET 
    CreatedDate = CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ModifiedDate = ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    
-- TODO: Update other datetime columns
-- TODO: Mapping other id columns (if exists)
-- TODO: Update timezone
