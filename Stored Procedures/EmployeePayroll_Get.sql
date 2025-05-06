/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[EmployeePayroll_Get]
    @Month DATE = NULL,
    @CompanyId INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: 20250505@Hank.Nguyen
	Task: Import employee payroll.
	DB: SMS-HRM
	Original: 

	Revisions:  
		Hank.Nguyen@20250505: Import employee payroll.
	Param's Explanation:
*/
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
        ep.[PersonalCost],
        ep.[ExtraPayment],
        ep.[ModifiedDate] AS LastModifiedDate,
        ep.[PeriodType]
    FROM [dbo].[EmployeePayroll] ep WITH (NOLOCK)
    INNER JOIN [dbo].[Employee] emp WITH (NOLOCK) ON ep.EmpId = emp.EmpId
    INNER JOIN [dbo].[CompanyEmployee] empCom WITH (NOLOCK) ON emp.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    LEFT JOIN [dbo].[Group] team WITH (NOLOCK) ON emp.GroupId = team.GroupId
    LEFT JOIN [dbo].[Department] dept WITH (NOLOCK) ON team.DepartmentId = dept.DepartmentId
    WHERE @Month IS NULL OR ep.[Month] = @Month
    ORDER BY ep.[Month], ep.[PeriodType], dept.[Name], team.[Name], emp.[FullName];

END
