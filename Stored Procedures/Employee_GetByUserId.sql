/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetByUserId]
(
    @UserId INT
    ,@CompanyId SMALLINT = 0
)
AS
/*
    Created: 20250306@Tim.Trinh
    Task: get employee by id
    DB: bodb_HRM

    Revisions:
        20250306@Tim: initial - [Redmine: #217976]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT emp.EmpId
		,emp.Code
		,emp.FullName
		,emp.NickName
		,emp.[Password]
		,emp.[Enabled]
		,es.IsTopManager
        ,ce.AutoApproveRequest
	FROM dbo.Employee AS emp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON emp.EmpId = es.EmpId
        LEFT JOIN dbo.CompanyEmployee AS ce ON emp.EmpId = ce.EmpId
        AND ce.CompanyId = @CompanyId
	WHERE emp.EmpId = @UserId
END