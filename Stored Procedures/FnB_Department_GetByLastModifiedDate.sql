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
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(YYYY, -10, GETDATE())
	END

	SELECT [DepartmentId]
      ,[Code]
      ,[Name]
      ,[UnitId]
      ,[IsActive]
      ,[ModifiedDate]
      ,[IsDeleted]
	  ,[OldDepartmentId]
	FROM dbo.Department WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
		AND ModifiedDate > @LastModifiedDate
END


