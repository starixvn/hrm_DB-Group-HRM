/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetNewEmployeeCode]
	@CompanyId SMALLINT
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
	FROM dbo.Employee AS e WITH(NOLOCK)
		INNER JOIN CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId 
	WHERE [Enabled] = 1 
		AND ISNULL(Code, '') != ''
		AND ce.CompanyId = @CompanyId

	IF @Code IS NOT NULL
		SELECT @Code + 1 AS Code
END