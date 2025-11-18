/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Currency_Get]
AS
/*
Created: 20250714@Lilac.Nguyen
Task: get currency
DB: HRM
Original: 

Revisions:
	20251117@Lilac: get rounding
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT  Id
		,[CurrencyCode]
		,Rounding
	FROM dbo.Currency WITH (NOLOCK)
END