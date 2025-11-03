/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Unit_GetAccessibleUnitsByEmpId] 
    @EmpId INT
AS
/*
    Created: 242668@Henry.Dinh
    Task: Get Units by Employee ID (Team membership, BU PIC, BU Supporter)
    DB: bodb_HRM
    Revisions:
        20251027@Henry.Dinh: Initial - Get units by employee ID [Redmine: #242668]
    Param's Explanation:
        @EmpId: Employee ID to get units for
*/
BEGIN
	SET NOCOUNT ON;

    -- Get units where employee belongs to team (Employee → Group → Department → Unit)
    SELECT DISTINCT
        u.[UnitId],
        u.[GroupUnitId],
        u.[Code],
        u.[PICEmpId]
    FROM [dbo].[Unit] u WITH (NOLOCK)
    INNER JOIN dbo.Department d WITH (NOLOCK) ON d.UnitId = u.UnitId
    INNER JOIN dbo.[Group] g WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
    INNER JOIN dbo.CompanyEmployee e WITH (NOLOCK) ON e.GroupId = g.GroupId
    WHERE e.EmpId = @EmpId
        AND u.[IsDeleted] = 0 
        AND u.[IsActive] = 1

    UNION

    -- Get units where employee is BU PIC
    SELECT DISTINCT
        u.[UnitId],
        u.[GroupUnitId],
        u.[Code],
        u.[PICEmpId]
    FROM [dbo].[Unit] u WITH (NOLOCK)
    WHERE u.[PICEmpId] = @EmpId
        AND u.[IsDeleted] = 0 
        AND u.[IsActive] = 1

    UNION

    -- Get units where employee is BU Supporter
    SELECT DISTINCT
        u.[UnitId],
        u.[GroupUnitId],
        u.[Code],
        u.[PICEmpId]
    FROM [dbo].[Unit] u WITH (NOLOCK)
    CROSS APPLY STRING_SPLIT(u.SupporterEmpId, ',') s
    WHERE s.value = CAST(@EmpId AS VARCHAR(10))
        AND u.SupporterEmpId IS NOT NULL 
        AND u.SupporterEmpId != ''
        AND u.[IsDeleted] = 0 
        AND u.[IsActive] = 1

    ORDER BY [GroupUnitId] ASC, [Code] ASC
END
GO