/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Company_GetDomain] @CompanyId INT = NULL
AS

/*
Created: 20250729@Lilac.Nguyen
Task: Get domain
DB: bodb_HRM
Original:

Revisions:
	20250729@Lilac.Nguyen: Get domain

*/

BEGIN
    SET NOCOUNT ON;

	SELECT CompanyId,
		   STUFF((
			   SELECT DISTINCT ', ' + Domain
			   FROM CompanySite AS t2
			   WHERE t2.CompanyId = t1.CompanyId
					 AND Domain IS NOT NULL
			   FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS [Domains]
	FROM CompanySite AS t1
	WHERE (@CompanyId IS NULL OR CompanyId = @CompanyId)
	GROUP BY CompanyId;

END