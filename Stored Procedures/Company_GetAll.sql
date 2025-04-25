/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[Company_GetAll] 
AS
/*
	Created: Jay.Do@2025-04-21
	Task: Get all company
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT CompanyId,
		[Name]
	FROM [dbo].[Company]
	WHERE ISNULL(IsDeleted, 0) = 0
END