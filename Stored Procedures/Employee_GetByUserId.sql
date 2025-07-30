/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetByUserId] @UserId INT
AS
/*
Created: 20250306@Tim.Trinh
Task: get employee by id
DB: HRM
Original:

Revisions:
    20250306@Tim: initial - [Redmine: #217976]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT emp.EmpId
		,Code
		,FullName
		,NickName
		,[Password]
		,[Enabled]
		,empsum.IsTopManager
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
	WHERE emp.EmpId = @UserId
END