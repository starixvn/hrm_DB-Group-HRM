/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[EmployeePayroll_Get]
    @Month DATE,
    @CompanyId INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg VARCHAR(200) = '' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        ep.[EmpId],
        emp.[Code],
        emp.[FullName],
        emp.[NickName],
        dept.[Name] AS DepartmentName,
        team.[Name] AS TeamName,
        ep.[Month],
        SUM(ep.[PersonalCost]) AS PersonalCost,
        SUM(ep.[ExtraPayment]) AS ExtraPayment,
        MAX(ep.[ModifiedDate]) AS LastModifiedDate
    FROM [dbo].[EmployeePayroll] ep WITH (NOLOCK)
    INNER JOIN [dbo].[Employee] emp WITH (NOLOCK) ON ep.EmpId = emp.EmpId
    INNER JOIN [dbo].[CompanyEmployee] empCom WITH (NOLOCK) ON emp.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    LEFT JOIN [dbo].[Group] team WITH (NOLOCK) ON emp.GroupId = team.GroupId
    LEFT JOIN [dbo].[Department] dept WITH (NOLOCK) ON team.DepartmentId = dept.GroupId
    WHERE ep.[Month] = @Month
    GROUP BY ep.[EmpId], emp.[Code], emp.[FullName], emp.[NickName], dept.[Name], team.[Name], ep.[Month]
    ORDER BY dept.[Name], team.[Name], emp.[FullName];

END
