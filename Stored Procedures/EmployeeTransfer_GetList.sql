/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[EmployeeTransfer_GetList]
(
    @CurrentEmpId INT,
    @IsViewAll BIT = 0
)
AS
/*
    Created: 20251027@Henry.Dinh
    Task: Get employee transfer list for display
    DB: bodb_HRM
    Revisions:
        20251027@Henry.Dinh: Initial - Get employee transfer list [Redmine: #242668]
    Param's Explanation:
        @CurrentEmpId: Current employee ID for permission checking
        @IsViewAll: If true, view all transfers; if false, view only accessible units
*/
BEGIN
    SET NOCOUNT ON;

    -- Get accessible units for the current employee
    DECLARE @AccessibleUnits TABLE (
        UnitId INT,
        GroupUnitId INT,
        Code NVARCHAR(50),
        PICEmpId INT
    );
    
    IF @IsViewAll = 0
    BEGIN
        INSERT INTO @AccessibleUnits (UnitId, GroupUnitId, Code, PICEmpId)
        EXEC dbo.Unit_GetAccessibleUnitsByEmpId @EmpId = @CurrentEmpId;
    END

    SELECT 
        -- Employee Information
        e.CtrId,
        e.FullName,
        
        -- From Company Information
        fromComp.[Name] AS FromCompanyName,
        fromCE.NickName AS FromNickName,
        fromUnit.[Code] AS FromBUName,
        fromDept.[Name] AS FromDeptName,
        fromTeam.[Name] AS FromTeamName,
        
        -- To Company Information
        toComp.[Name] AS ToCompanyName,
        toCE.NickName AS ToNickName,
        toUnit.[Code] AS ToBUName,
        toDept.[Name] AS ToDeptName,
        toTeam.[Name] AS ToTeamName,
        
        -- Transfer Information
        et.Remark,
        et.TransferOutDate AS TransferredDatetime,
        modifierCE.NickName AS TransferredByNickName,
        modifierComp.[Name] AS TransferredByCompany
        
    FROM dbo.EmployeeTransfer AS et WITH (NOLOCK)
        
        -- From Employee Information
        INNER JOIN dbo.CompanyEmployee AS fromCE WITH (NOLOCK) 
            ON et.FromEmpId = fromCE.EmpId
        INNER JOIN dbo.Employee AS e WITH (NOLOCK) 
            ON fromCE.UserId = e.UserId
        INNER JOIN dbo.Company AS fromComp WITH (NOLOCK) 
            ON fromCE.CompanyId = fromComp.CompanyId
        LEFT JOIN dbo.[Group] AS fromTeam WITH (NOLOCK) 
            ON fromCE.GroupId = fromTeam.GroupId
        LEFT JOIN dbo.Department AS fromDept WITH (NOLOCK) 
            ON fromTeam.DepartmentId = fromDept.DepartmentId
        LEFT JOIN dbo.Unit AS fromUnit WITH (NOLOCK) 
            ON fromDept.UnitId = fromUnit.UnitId
            
        -- To Employee Information
        INNER JOIN dbo.CompanyEmployee AS toCE WITH (NOLOCK) 
            ON et.ToEmpId = toCE.EmpId
        INNER JOIN dbo.Company AS toComp WITH (NOLOCK) 
            ON toCE.CompanyId = toComp.CompanyId
        LEFT JOIN dbo.[Group] AS toTeam WITH (NOLOCK) 
            ON toCE.GroupId = toTeam.GroupId
        LEFT JOIN dbo.Department AS toDept WITH (NOLOCK) 
            ON toTeam.DepartmentId = toDept.DepartmentId
        LEFT JOIN dbo.Unit AS toUnit WITH (NOLOCK) 
            ON toDept.UnitId = toUnit.UnitId
            
        -- Modified By Information
        LEFT JOIN dbo.CompanyEmployee AS modifierCE WITH (NOLOCK) 
            ON et.ModifiedBy = modifierCE.EmpId
        LEFT JOIN dbo.Company AS modifierComp WITH (NOLOCK) 
            ON modifierCE.CompanyId = modifierComp.CompanyId
            
    WHERE 
        @IsViewAll = 1
        OR (
            fromUnit.UnitId IN (SELECT UnitId FROM @AccessibleUnits)
            OR toUnit.UnitId IN (SELECT UnitId FROM @AccessibleUnits)
        )
        
    ORDER BY et.TransferInDate DESC, et.TransferId DESC;
END

