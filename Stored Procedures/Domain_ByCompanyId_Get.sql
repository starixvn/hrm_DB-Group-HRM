/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Domain_ByCompanyId_Get] 
	@CompanyId INT
AS
/*
Created: Jay.Do@20250605
Task: Get Domain by company id
DB: HRM_SMS
Original: 

Revisions: 
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		TOP 1
		Domain
	FROM dbo.CompanySite WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
END
