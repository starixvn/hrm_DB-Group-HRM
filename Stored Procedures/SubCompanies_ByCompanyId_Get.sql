/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE SubCompanies_ByCompanyId_Get
	@CompanyId INT
AS
/*
Created: 20250616@Jay
Task: Get all subcompanies by company id
DB: HRM
Original:

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT SubCompanyId,
		CompanyId,
		[Name]
	FROM SubCompany
	WHERE CompanyId = @CompanyId
END
GO
