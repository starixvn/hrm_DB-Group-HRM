/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Holiday_GetByYear] @Year INT,
	@CompanyId SMALLINT
AS
/*
Created: Tom.Vo@2013-10-23
Task: Get Holiday by Year
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT *
	FROM dbo.Holiday WITH (NOLOCK)
	WHERE YEAR(FromDate) = @Year
		AND CompanyId = @CompanyId
	ORDER BY FromDate
END


