USE [bodb_IUC]
GO

-- add new function for all HRM
DECLARE @SiteIds TABLE (SiteId INT);
INSERT INTO @SiteIds (SiteId)
VALUES 
(1), (7), (15), (18), (19), (20), (21), (22), (23), (24), 
(25), (27), (28), (29), (30), (31), (32), (33), (35), (36), 
(37), (38), (39), (40), (41);

-- Save FunctionId is inserted for 'DataPermission'
DECLARE @InsertedPermissions TABLE (
    FunctionId INT,
    SiteId INT
);

-- Insert 'DataPermission' and save FunctionId by SiteId
INSERT INTO [Function] (
    SiteId,
    FunctionKey,
    FunctionName,
    Description,
    ParentId,
    Policy,
    IsActive,
    DisplayOrder,
    CreatedBy,
    CreatedDate,
    ModifiedBy,
    ModifiedDate
)
OUTPUT INSERTED.FunctionId, INSERTED.SiteId
INTO @InsertedPermissions(FunctionId, SiteId)
SELECT 
    s.SiteId,
    'DataPermission',
    'Data Permission',
    NULL,
    NULL,
    1,
    1,
    0,
    1,
    GETDATE(),
    NULL,
    NULL
FROM @SiteIds s;

-- Insert 'AllEmployees' and 'EmployeesAssigned' with ParentId
INSERT INTO [Function] (
    SiteId,
    FunctionKey,
    FunctionName,
    Description,
    ParentId,
    Policy,
    IsActive,
    DisplayOrder,
    CreatedBy,
    CreatedDate,
    ModifiedBy,
    ModifiedDate
)
OUTPUT INSERTED.FunctionId, INSERTED.SiteId
INTO @InsertedPermissions(FunctionId, SiteId)
SELECT 
    p.SiteId,
    f.FunctionKey,
    f.FunctionName,
    NULL, -- Description
    p.FunctionId, -- ParentId get from 'DataPermission'
    1,  -- Policy
    1,  -- IsActive
    0,  -- DisplayOrder
    1,  -- CreatedBy
    GETDATE(),
    NULL, -- ModifiedBy
    NULL  -- ModifiedDate
FROM @InsertedPermissions p
CROSS APPLY (
    SELECT 'AllEmployees' AS FunctionKey, 'All Employees' AS FunctionName
    UNION ALL
    SELECT 'EmployeesAssigned', 'Employees Assigned'
) f;

-- Insert RoleFunction with 3 role -- HR, SA, HR Assistant
INSERT INTO RoleFunction (
    SiteId,
    RoleId,
    FunctionId,
    IsRead,
    IsHost,
    CreatedBy,
    CreatedDate,
    ModifiedBy,
    ModifiedDate
)
SELECT 
    f.SiteId,
    r.RoleId,
    f.FunctionId,
    1 AS IsRead,
    0 AS IsHost,
    1 AS CreatedBy,
    GETDATE() AS CreatedDate,
    NULL AS ModifiedBy,
    NULL AS ModifiedDate
FROM @InsertedPermissions f
CROSS JOIN (VALUES (6), (7), (12)) AS r(RoleId); -- HR, SA, HR Assistant

           
GO

