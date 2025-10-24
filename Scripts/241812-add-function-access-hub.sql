USE bodb_IUC
GO

DECLARE @tmpSite TABLE (RowIndex INT IDENTITY(1, 1), SiteId SMALLINT)

INSERT INTO @tmpSite (SiteId)
VALUES (1), (7), (15), (18), (19), (20), (21), (22), (23), (24), (25), (27), (28), (29), (30), (31), (32), (33), (36), (37), (38), (39), (40), (41)

DECLARE @rowIndex INT = 1,
    @TotalRows INT

SELECT @TotalRows = COUNT(1)
FROM @tmpSite

WHILE @RowIndex <= @TotalRows
BEGIN
    DECLARE @SiteId SMALLINT = NULL,
        @EmployeeManagementParentId INT = NULL,
        @PayrollInfoFunctionId INT = NULL,
        @HRSpaceParentId INT = NULL,
        @PayrollSettingsFunctionId INT = NULL,
        @ParentMenuId INT = NULL

    SELECT @SiteId = SiteId
    FROM @tmpSite WHERE RowIndex = @rowIndex

    -- Get Employee Management FunctionId as parent
    SELECT @EmployeeManagementParentId = FunctionId
    FROM dbo.[Function]
    WHERE SiteId = @SiteId AND FunctionKey = 'EmployeeManagement'

    -- Insert Payroll Info function under Employee Management
    INSERT INTO dbo.[Function] (SiteId, FunctionKey, FunctionName, ParentId, Policy, IsActive)
    VALUES (@SiteId, 'PayrollInfo', 'Payroll Info', @EmployeeManagementParentId, NULL, 1)

    -- Get Payroll Info FunctionId
    SELECT @PayrollInfoFunctionId = FunctionId
    FROM dbo.[Function]
    WHERE SiteId = @SiteId AND FunctionKey = 'PayrollInfo'

    -- Insert Payroll Info Only function under Payroll Info
    INSERT INTO dbo.[Function] (SiteId, FunctionKey, FunctionName, ParentId, Policy, IsActive)
    VALUES (@SiteId, 'PayrollInfoOnly', 'Payroll Info Only', @PayrollInfoFunctionId, NULL, 1)

    -- Insert Payroll Info With Amount function under Payroll Info
    INSERT INTO dbo.[Function] (SiteId, FunctionKey, FunctionName, ParentId, Policy, IsActive)
    VALUES (@SiteId, 'PayrollInfoWithAmount', 'Payroll Info With Amount', @PayrollInfoFunctionId, NULL, 1)

    -- Get HR Space FunctionId as parent
    SELECT @HRSpaceParentId = FunctionId
    FROM dbo.[Function]
    WHERE SiteId = @SiteId AND FunctionKey = 'HRSpace'

    -- Insert Payroll Setting function under HR Space
    INSERT INTO dbo.[Function] (SiteId, FunctionKey, FunctionName, ParentId, Policy, IsActive)
    VALUES (@SiteId, 'PayrollSetting', 'Payroll Setting', @HRSpaceParentId, NULL, 1)

    -- Get Payroll Setting FunctionId for menu item
    SELECT @PayrollSettingsFunctionId = FunctionId
    FROM dbo.[Function]
    WHERE SiteId = @SiteId AND FunctionKey = 'PayrollSetting'

    SELECT @ParentMenuId = MenuItemId
    FROM dbo.MenuItem
    WHERE MenuItemName = 'HR Space' AND SiteId = @SiteId

    INSERT INTO dbo.MenuItem (FunctionId, SiteId, ParentId, MenuItemName, URL, IsActive, DisplayOrder)
    VALUES (@PayrollSettingsFunctionId, @SiteId, @ParentMenuId, 'Payroll Settings', '/payrollsettings/index', 1, 12)

    Update [dbo].[Function] set FunctionName ='Salary Structure' WHERE FunctionName = 'Salary Structure Configuration'

    SET @RowIndex = @RowIndex + 1
END
