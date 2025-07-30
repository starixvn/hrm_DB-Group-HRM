/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE SubCompanies_ByCompanyId_Get
	@CompanyId INT = NULL
AS
/*
Created: 20250616@Jay
Task: Get all subcompanies by company id
DB: bodb_HRM
Original:

Revisions:
	20250723@Lilac:  Get all sub companies when companyId null
*/
BEGIN
	SET NOCOUNT ON;

	SELECT SubCompanyId,
		CompanyId,
		[Name]
	FROM SubCompany
	WHERE (@CompanyId IS NULL OR CompanyId = @CompanyId)
END
