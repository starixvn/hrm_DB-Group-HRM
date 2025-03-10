/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Memo_GetById]
	@Id INT
	,@CompanyId INT 
AS
/*
Created: Tom.Vo@2013-10-23
Task: Get Memo by ID
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:

*/
BEGIN
SET NOCOUNT ON

SELECT m.*, lk.[Name] as CategoryName 
FROM dbo.MEMO m WITH(NOLOCK) 
	INNER JOIN dbo.LookupData lk WITH(NOLOCK) on lk.id = m.Category
WHERE m.Id = @id AND m.CompanyId = @CompanyId

END


