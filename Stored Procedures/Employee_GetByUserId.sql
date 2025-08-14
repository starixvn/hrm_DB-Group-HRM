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
        20250813@Jay: change db structure [Redmine: #235678]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ce.EmpId
		,ce.Code
		,e.FullName
		,ce.NickName
		,e.[Password]
		,ce.[Enabled]
		,ce.IsSpecialUser AS IsTopManager
        ,ce.AutoApproveRequest
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
        INNER JOIN dbo.Employee AS e ON e.UserId = ce.UserId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
	WHERE ce.UserId = @UserId
			AND ce.CompanyId = @CompanyId
			AND ce.[Enabled] = 1
END