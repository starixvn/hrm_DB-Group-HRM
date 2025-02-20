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

-- #region MESSAGE TABLE
INSERT INTO bodb_HRM.dbo.[Message] (
    [Subject], Contents, Category, FromDate, ToDate, 
    IsDisabled, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, CompanyId, OldMessageId
)
SELECT 
    m.Subject,
    m.Contents,
    m.Category,
    m.FromDate,
    m.ToDate,
    m.IsDisabled,
    e_created.EmpId,
    m.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    e_modified.EmpId,
    m.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    @NewCompanyId,
    m.MessageId
FROM SMSHRM.dbo.Message AS m
LEFT JOIN bodb_HRM.dbo.Employee AS e_created ON m.CreatedBy = e_created.OldEmpId
LEFT JOIN bodb_HRM.dbo.Employee AS e_modified ON m.ModifiedBy = e_modified.OldEmpId;
-- #endregion

-- #region MESSAGE EMPLOYEE TABLE
INSERT INTO bodb_HRM.dbo.MessageEmployee (
    MessageId, EmployeeId, Email, IsDisabled, IsRead
)
SELECT 
    m.MessageId,  
    em.EmpId,  
    me.Email,
    me.IsDisabled,
    me.IsRead
FROM SMSHRM.dbo.MessageEmployee AS me
INNER JOIN bodb_HRM.dbo.[Message] AS m ON me.MessageId = m.OldMessageId AND m.CompanyId = @NewCompanyId
INNER JOIN bodb_HRM.dbo.Employee AS em ON me.EmployeeId = em.OldEmpId
WHERE em.EmpId IS NOT NULL;
-- #endregion

-- #region MESSAGE GROUP TABLE
INSERT INTO bodb_HRM.dbo.MessageGroup (
    MessageId, GroupId, Email
)
SELECT 
    m.MessageId,
    g.GroupId, 
    mg.Email
FROM SMSHRM.dbo.MessageGroup AS mg
INNER JOIN bodb_HRM.dbo.[Group] AS g ON mg.GroupId = g.OldGroupId AND g.CompanyId = @NewCompanyId
INNER JOIN bodb_HRM.dbo.[Message] AS m ON mg.MessageId = m.OldMessageId AND m.CompanyId = @NewCompanyId;
-- #endregion