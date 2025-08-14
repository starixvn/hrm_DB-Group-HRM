/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE[dbo].[CompanySecondmentEmployee_GetByEmpId]
  @EmpId INT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Secondment employee list
	DB: HRM_SMS
	Original:

	Revisions:
		20250814@Lilac: restructure for transfer [Redmine: #235678]
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    SELECT cse.EmpId,
           cse.CompanyId as SecondCompanyId,
           c.Name AS SecondCompanyName,
           ce.CompanyId AS CurrentCompanyId,
           c2.Name AS CurrentCompanyName,
           ce.Code AS EmpCode,
           ce.NickName,
           e.FullName
    FROM dbo.CompanySecondmentEmployee AS cse WITH (NOLOCK)
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON cse.EmpId = ce.EmpId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
    INNER JOIN dbo.Company AS c WITH (NOLOCK) ON cse.CompanyId = c.CompanyId
    INNER JOIN dbo.Company AS c2 WITH (NOLOCK) ON ce.CompanyId = c2.CompanyId
    WHERE cse.EmpId = @EmpId;
END

GO