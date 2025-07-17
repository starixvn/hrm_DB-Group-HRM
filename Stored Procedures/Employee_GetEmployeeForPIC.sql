/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Employee_GetEmployeeForPIC] 
AS
/*
	Created: Henry.Dinh@2025-04-18
	Task: Get employee for PIC
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT e.[EmpId] as Id
      ,e.[Code]
      ,e.[NickName]
      ,e.[FullName]
	  ,c.[Name] AS CompanyName
	FROM [dbo].[Employee] e
	INNER JOIN [dbo].CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ISNULL(ce.IsSpecialUser, 0) = 0 AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
	INNER JOIN [dbo].Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE ISNULL(e.isDeleted, 0) = 0 and e.Enabled = 1
	ORDER BY e.[NickName], e.[Code]
END
