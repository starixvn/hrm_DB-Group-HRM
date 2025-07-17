/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[Currency_Get]
AS
/*
Created: 20250714@Lilac.Nguyen
Task: get currency
DB: HRM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT  Id
		,[CurrencyCode]
	FROM dbo.Currency WITH (NOLOCK)
END