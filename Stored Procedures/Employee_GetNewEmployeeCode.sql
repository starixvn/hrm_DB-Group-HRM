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

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @MaxCodeNumber VARCHAR(20)

	DECLARE @LastestPrefix VARCHAR(20)

	SELECT @MaxCodeNumber = MAX(CAST(
		RIGHT(Code, COALESCE(NULLIF(PATINDEX('%[^0-9]%', REVERSE(Code)), 0) - 1, LEN(Code)))
		AS BIGINT))
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
	WHERE ce.[Enabled] = 1 
		AND ISNULL(Code, '') != ''
		AND ce.CompanyId = @CompanyId

	IF @MaxCodeNumber IS NOT NULL
		SELECT TOP 1 @LastestPrefix = LEFT(Code, PATINDEX('%[0-9]%', Code) - 1)
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		WHERE ce.[Enabled] = 1 
			AND ISNULL(ce.Code, '') != ''
			AND ce.CompanyId = @CompanyId
		ORDER BY ce.EmpId DESC


		SELECT @LastestPrefix + CAST((@MaxCodeNumber + 1) AS VARCHAR(20)) AS Code
END