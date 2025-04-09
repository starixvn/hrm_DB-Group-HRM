/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[FnB_Unit_GetByLastModifiedDate]
	@LastModifiedDate DATETIME,
	@CompanyId SMALLINT
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

	SELECT DISTINCT u.UnitId
		,u.Code
		,u.Name
		,u.IsActive
		,u.ModifiedDate
		,u.IsDeleted
	FROM dbo.Unit AS u WITH (NOLOCK) 
	LEFT JOIN dbo.Department AS d WITH (NOLOCK) ON d.UnitId = u.UnitId
	INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
		AND g.CompanyId = @CompanyId
	WHERE u.ModifiedDate > @LastModifiedDate
END


