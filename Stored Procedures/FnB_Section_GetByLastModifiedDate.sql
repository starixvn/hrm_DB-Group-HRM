/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[FnB_Section_GetByLastModifiedDate]
	@LastModifiedDate DATETIME
AS
/*
Created: Jay
Task: Get section last modified date
DB: HRM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT *
	FROM dbo.Section WITH (NOLOCK)
	WHERE @LastModifiedDate IS NOT NULL
		AND ModifiedDate > @LastModifiedDate
END