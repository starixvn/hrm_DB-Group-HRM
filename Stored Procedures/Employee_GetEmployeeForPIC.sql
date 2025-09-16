/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetEmployeeForPIC] 
AS
/*
	Created: Henry.Dinh@2025-04-18
	Task: Get employee for PIC
	DB: HRM_SMS
	Original:

	Revisions:
		20250814@Lilac: restructure for transfer [Redmine: #235678]
		20250904@Jay: update role [Redmine: #237201]
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @NexcelId SMALLINT = 1, @LumiId SMALLINT = 2,  @NexVisionId SMALLINT = 34

    SELECT ce.[EmpId] as Id
        ,ce.[Code]
        ,ce.[NickName]
        ,e.[FullName]
        ,c.[Name] AS CompanyName
    FROM [dbo].[Employee] AS e
        INNER JOIN [dbo].CompanyEmployee AS ce WITH (NOLOCK) ON ce.UserId = e.UserId
        INNER JOIN [dbo].Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
    WHERE ISNULL(ce.isDeleted, 0) = 0 and ce.[Enabled] = 1
        AND (
	        ce.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId)
	        OR ce.IsSpecialUser = 0
        )
    ORDER BY ce.[NickName], ce.[Code]
END