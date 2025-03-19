/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_GetById]
	@UnitId INT,
	@CompanyId SMALLINT
AS
/*
Created: 20200520@Patsy.doan
Task: Unit_GetById
DB: HRM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	SELECT u.UnitId
		,u.Code
		,u.Name
		,u.IsActive
		,u.ModifiedDate
	FROM dbo.Unit as u
	WHERE u.UnitId =@UnitId
		AND u.CompanyId = @CompanyId
END