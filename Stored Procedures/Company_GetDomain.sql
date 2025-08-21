/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Company_GetDomain] @CompanyId SMALLINT = NULL
AS
/*
    Created: 20250729@Lilac.Nguyen
    Task: Get domain
    DB: bodb_HRM

    Revisions:
	    20250729@Lilac.Nguyen: init
*/
BEGIN
    SET NOCOUNT ON;

	SELECT CompanyId,
		Domain
	FROM dbo.CompanySite AS cs WITH (NOLOCK)
	WHERE (@CompanyId IS NULL OR CompanyId = @CompanyId)
    ORDER BY CompanyId
END