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
        @ParentId INT = NULL,
        @FuntionId INT = NULL,
        @ParentMenuId INT = NULL

    SELECT @SiteId = SiteId
    FROM @tmpSite WHERE RowIndex = @rowIndex

    SELECT @ParentId = FunctionId
    FROM dbo.[Function]
    WHERE SiteId = @SiteId AND FunctionKey = 'HRSpace'

    INSERT INTO dbo.[Function] (SiteId, FunctionKey, FunctionName, ParentId, Policy, IsActive)
    VALUES (@SiteId, 'SalaryStructureAssignment', 'Salary Structure Assignment', @ParentId, NULL, 1)

    INSERT INTO dbo.[Function] (SiteId, FunctionKey, FunctionName, ParentId, Policy, IsActive)
    VALUES (@SiteId, 'SalaryStructureConfiguration', 'Salary Structure Configuration', @ParentId, NULL, 1)

    SELECT @FuntionId = FunctionId
    FROM dbo.[Function]
    WHERE SiteId = @SiteId AND FunctionKey = 'SalaryStructureConfiguration'

    SELECT @ParentMenuId = MenuItemId
    FROM dbo.MenuItem
    WHERE MenuItemName = 'HR Space'

    INSERT INTO dbo.MenuItem (FunctionId, SiteId, ParentId, MenuItemName, URL, IsActive, DisplayOrder)
    VALUES (@FuntionId, @SiteId, @ParentMenuId, 'Salary Structure', '/SalaryStructure/Index', 1, 11)

    SET @RowIndex = @RowIndex + 1
END