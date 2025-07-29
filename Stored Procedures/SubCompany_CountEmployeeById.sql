/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SubCompany_CountEmployeeById]
(
    @CompanyId INT
)
AS
/*
    Created: 20250724@Lilac.Nguyen
    Task: count employee by company id
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT SubCompanyId, COUNT(*) AS EmployeeCount
	FROM CompanyEmployee
	WHERE CompanyId = @CompanyId 
	  AND ISNULL(IsDeleted, 0) <> 1
	  AND SubCompanyId IS NOT NULL
	GROUP BY SubCompanyId

END