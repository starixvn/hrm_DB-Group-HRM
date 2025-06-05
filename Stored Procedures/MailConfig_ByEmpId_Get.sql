/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE MailConfig_ByEmpId_Get 
	@EmpId INT
AS
/*
Created: Jay.Do@20250605
Task: Get Mail config by Employee Id
DB: HRM_SMS
Original: 

Revisions: 
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		ce.CompanyId,
		cs.Domain,
		sc.[Value] AS MailSetting
	FROM dbo.CompanyEmployee ce WITH (NOLOCK)
		INNER JOIN dbo.SystemConfigs sc WITH (NOLOCK) ON sc.CompanyId = ce.CompanyId
		INNER JOIN dbo.CompanySite cs WITH (NOLOCK) ON cs.CompanyId = ce.CompanyId
	WHERE ce.EmpId = @EmpId AND [Key] = 'MailSetting'
END
GO