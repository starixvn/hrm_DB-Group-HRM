/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetNewEmployeeCode]
AS
/*
Created: Tom.Vo@2013-10-21
Task: get employee by code
DB: HRM
Original:

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Code VARCHAR(20)

	SELECT @Code = MAX(CAST(
		RIGHT(Code, COALESCE(NULLIF(PATINDEX('%[^0-9]%', REVERSE(Code)), 0) - 1, LEN(Code)))
		AS BIGINT))
	FROM dbo.Employee WITH(NOLOCK)
	WHERE [Enabled] = 1 AND ISNULL(Code, '') != '';

	IF @Code IS NOT NULL
		SELECT @Code + 1 AS Code
	ELSE
        SELECT RIGHT('000000000' + CAST(1 AS VARCHAR), 9) AS Code;
END