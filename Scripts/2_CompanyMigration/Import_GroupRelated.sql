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

-- #region EMPLOYEE GROUP TABLE
INSERT INTO bodb_HRM.dbo.EmployeeGroup (GroupId, EmpId, isMainGroup)
SELECT 
    g.GroupId,       
    em.EmpId,        
    eg.isMainGroup    
FROM SMSHRM.dbo.EmployeeGroup AS eg
INNER JOIN bodb_HRM.dbo.[Group] AS g ON eg.GroupId = g.OldGroupId AND g.CompanyId = @NewCompanyId
INNER JOIN @EmployeeMapping AS em ON eg.EmpID = em.OldEmpId;
-- #endregion

-- #region GROUP MANAGER TABLE
INSERT INTO bodb_HRM.dbo.GroupManager (GroupId, EmpId, RoleId)
SELECT 
    g.GroupId,  
    em.EmpId,   
    gm.RoleId 
FROM SMSHRM.dbo.GroupManager AS gm
INNER JOIN bodb_HRM.dbo.[Group] AS g ON gm.GroupId = g.OldGroupId AND g.CompanyId = @NewCompanyId
INNER JOIN @EmployeeMapping AS em ON gm.EmpID = em.OldEmpId;
-- #endregion

-- #region GROUP SUPERVISOR TABLE
INSERT INTO bodb_HRM.dbo.GroupSupervisor (
    OwnerId, GroupId, ActionType, RequestType, ModifiedBy, ModifiedDate, IsDeleted, DisplayOrder
)
SELECT 
    em.EmpId,  
    g.GroupId, 
    gs.ActionType,
    gs.RequestType,
    em_mod.EmpId, -- Lấy ModifiedBy từ Employee Mapping
    gs.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    gs.IsDeleted,
    gs.DisplayOrder
FROM SMSHRM.dbo.GroupSupervisor AS gs
INNER JOIN bodb_HRM.dbo.[Group] AS g ON gs.GroupId = g.OldGroupId AND g.CompanyId = @NewCompanyId
INNER JOIN @EmployeeMapping AS em ON gs.OwnerId = em.OldEmpId
LEFT JOIN @EmployeeMapping AS em_mod ON gs.ModifiedBy = em_mod.OldEmpId; 
-- #endregion

-- #region EXTENSION NUMBER TABLE
INSERT INTO bodb_HRM.dbo.ExtensionNumbers (
    FullName, NickName, ExtensionNo, IsInternal, IsGroup, EmpId, GroupId, OrderNo
)
SELECT 
    en.FullName, 
    en.NickName, 
    en.ExtensionNo, 
    en.IsInternal, 
    en.IsGroup, 
    em.EmpId, 
    g.GroupId,  
    en.OrderNo
FROM SMSHRM.dbo.ExtensionNumbers AS en
LEFT JOIN @EmployeeMapping AS em ON en.EmpID = em.OldEmpId
LEFT JOIN bodb_HRM.dbo.[Group] AS g ON en.GroupID = g.OldGroupId AND g.CompanyId = @NewCompanyId;
-- #endregion

-- #region MAIL SETTINGS TABLE
INSERT INTO bodb_HRM.dbo.MailSettings (
    GroupId, Action, AllowSendUser, AllowSendVerifier, AllowSendApprover, AllowSendHR, AllowSendMailGroup
)
SELECT 
    g.GroupId, 
    ms.Action,
    ms.AllowSendUser,
    ms.AllowSendVerifier,
    ms.AllowSendApprover,
    ms.AllowSendHR,
    ms.AllowSendMailGroup
FROM SMSHRM.dbo.MailSettings AS ms
INNER JOIN bodb_HRM.dbo.[Group] AS g ON ms.GroupId = g.OldGroupId AND g.CompanyId = @NewCompanyId;
-- #endregion

