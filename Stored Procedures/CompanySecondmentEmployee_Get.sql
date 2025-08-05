/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CompanySecondmentEmployee_Get]
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Secondment employee list
	DB: bodb_HRM

	Revisions:
        - 20250801@Lilac.Nguyen: get location [Redmine: #234645]
        - 20250805@Lilac.Nguyen: get location(CountryCodeISO3) [Redmine: #234645]

	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    SELECT cse.EmpId,
           cse.CompanyId as SecondCompanyId,
           c.Name AS SecondCompanyName,
           ce.CompanyId AS CurrentCompanyId,
           c2.Name AS CurrentCompanyName,
           e.Code AS EmpCode,
           e.NickName,
           e.FullName,
		   ct.CountryCodeISO3 AS [Location]
    FROM dbo.CompanySecondmentEmployee AS cse WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON cse.EmpId = e.EmpId
    INNER JOIN dbo.Company AS c WITH (NOLOCK) ON cse.CompanyId = c.CompanyId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON cse.EmpId = ce.EmpId
    INNER JOIN dbo.Company AS c2 WITH (NOLOCK) ON ce.CompanyId = c2.CompanyId
	LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON ct.CountryCode = c.CountryCode
    ORDER BY cse.ModifiedDate DESC;
END