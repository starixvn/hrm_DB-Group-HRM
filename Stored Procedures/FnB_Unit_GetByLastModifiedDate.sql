/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[FnB_Unit_GetByLastModifiedDate]
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
Created: 20230220@Quinn.Vo
Task: Get last modified date
DB: FBM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(YYYY, -10, GETDATE())
	END

	SELECT u.UnitId
		,u.Code
		,u.Name
		,u.IsActive
		,u.ModifiedDate
		,u.IsDeleted
	FROM dbo.Unit as u WITH (NOLOCK) 
	WHERE CompanyId = @CompanyId
		AND ModifiedDate > @LastModifiedDate
	
END


