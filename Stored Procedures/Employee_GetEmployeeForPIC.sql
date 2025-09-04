/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[Employee_GetEmployeeForPIC] 
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
	DECLARE @NexCompaniesIds VARCHAR(100) = '1,2,34' 

	SELECT ce.[EmpId] as Id
      ,ce.[Code]
      ,ce.[NickName]
      ,e.[FullName]
	  ,c.[Name] AS CompanyName
	FROM [dbo].[Employee] e
	INNER JOIN [dbo].CompanyEmployee ce WITH (NOLOCK) ON ce.UserId = e.UserId
		AND ISNULL(ce.IsDeleted, 0) = 0
		AND ISNULL(ce.Enabled, 1) = 1
        AND (
			ce.CompanyId NOT IN (SELECT CAST([value] AS INT) FROM STRING_SPLIT(@NexCompaniesIds, ','))
			OR ISNULL(ce.IsSpecialUser, 0) = 0
		)
	INNER JOIN [dbo].Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE ISNULL(ce.isDeleted, 0) = 0 and ce.[Enabled] = 1
	ORDER BY ce.[NickName], ce.[Code]
END
