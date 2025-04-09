/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[FnB_Department_GetByLastModifiedDate]
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
ALTER   PROCEDURE [dbo].[FnB_Department_GetByLastModifiedDate]
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

	SELECT DISTINCT d.[DepartmentId]
		,d.[Code]
		,d.[Name]
		,[UnitId]
		,[IsActive]
		,d.[ModifiedDate]
		,d.[IsDeleted]
	FROM dbo.Department AS d WITH (NOLOCK)
		INNER JOIN [Group] AS g WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
	WHERE g.CompanyId = @CompanyId
		AND d.ModifiedDate > @LastModifiedDate
END

