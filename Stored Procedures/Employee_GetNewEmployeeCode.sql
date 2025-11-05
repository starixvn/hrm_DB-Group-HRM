/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetNewEmployeeCode]
	@CompanyId SMALLINT
AS
/*
Created: Tom.Vo@2013-10-21
Task: get employee by code
DB: HRM
Original:

Revisions:
    - 20250619@Henry: fix ambiguous column error migrate nex
	- 20250812@Mira: change DB structure [Redmine: #235678]
	- 20251105@Jay: fix generate code [Redmine: #233310]

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @MaxCodeNumber VARCHAR(20),
		@LastestPrefix VARCHAR(20),
		@NumberLen INT;

	-- Find the digit count (max digits in code)
	SELECT TOP 1
		@NumberLen = PATINDEX('%[^0]%', SUBSTRING(Code, PATINDEX('%[0-9]%', Code), LEN(Code))) - 1
	FROM dbo.CompanyEmployee WITH (NOLOCK)
	WHERE [Enabled] = 1
		AND ISNULL(Code, '') <> ''
		AND CompanyId = @CompanyId
	ORDER BY EmpId DESC;

	SELECT @MaxCodeNumber = MAX(CAST(
		RIGHT(Code, COALESCE(NULLIF(PATINDEX('%[^0-9]%', REVERSE(Code)), 0) - 1, LEN(Code)))
		AS BIGINT))
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
	WHERE ce.[Enabled] = 1 
		AND ISNULL(Code, '') <> ''
		AND ce.CompanyId = @CompanyId

	IF @MaxCodeNumber IS NOT NULL
		SELECT TOP 1 @LastestPrefix = LEFT(Code, PATINDEX('%[0-9]%', Code) - 1)
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		WHERE ce.[Enabled] = 1 
			AND ISNULL(Code, '') != ''
			AND ce.CompanyId = @CompanyId
		ORDER BY ce.EmpId DESC

		SET @MaxCodeNumber = REPLICATE('0', @NumberLen) + CAST(@MaxCodeNumber + 1 AS VARCHAR(10))

		SELECT @LastestPrefix + @MaxCodeNumber AS Code
END