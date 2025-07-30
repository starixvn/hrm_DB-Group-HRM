/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeSupervisor_GetListSupervisorRequestID]
(
    @RequestId BIGINT
	,@Action INT = NULL
)
AS
/*
    Created: TOM.VO@2013/10/25
    Task: Get list supervisor for Employee by RequestID.
    DB: bodb_HRM

    Revisions:
	    2023-03-20@Teddy.Le: get Letstalk
        20250509@Tim: remove HR
        20250715@Henry: check company Letstalk config per person
        20250730@Henry: add companyId to MailSettings
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ApproverId INT
		,@VerifierId INT
		,@EmpId INT
		,@TeamId INT
		,@IsExistSetting BIT

	SELECT @ApproverId = wr.ApproverId
		,@VerifierId = wr.VerifierId
		,@EmpId = wr.EmpId
	FROM WorkingTimeRequest AS wr WITH (NOLOCK)
	WHERE wr.RequestId = @RequestId

	SELECT 0 AS RoleId
		,'Member' AS [Role]
		,e.EmpId
		,e.FullName
		,e.NickName
		,e.Email
		,CASE 
			WHEN sc.Value = 'true' THEN e.LetsTalk 
			ELSE NULL 
		END AS LetsTalk
		,e.Code AS EmpCode
		,CASE 
			WHEN epic.EmpId IS NOT NULL 
			THEN epic.NickName + ' (' + epic.Code + ')'
			ELSE '' 
		END AS PICDisplayName
	FROM dbo.Employee e WITH (NOLOCK)
	LEFT JOIN dbo.[Group] g WITH (NOLOCK) ON e.GroupId = g.GroupId
	LEFT JOIN dbo.Employee epic WITH (NOLOCK) ON g.PICEmpId = epic.EmpId
	LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
	LEFT JOIN dbo.SystemConfigs sc WITH (NOLOCK) ON ce.CompanyId = sc.CompanyId AND sc.[Key] = 'EnableLetstalk'
	WHERE e.EmpId = @EmpId
		AND e.[Enabled] = 1
		AND e.isDeleted = 0

	SELECT 2 AS RoleId
		,'Verifier' AS [Role]
		,e.EmpId
		,e.FullName
		,e.NickName
		,e.Email
		,CASE 
			WHEN sc.Value = 'true' THEN e.LetsTalk 
			ELSE NULL 
		END AS LetsTalk
	FROM dbo.Employee e WITH (NOLOCK)
	LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
	LEFT JOIN dbo.SystemConfigs sc WITH (NOLOCK) ON ce.CompanyId = sc.CompanyId AND sc.[Key] = 'EnableLetstalk'
	WHERE e.EmpId = @VerifierId
		AND e.[Enabled] = 1
		AND e.isDeleted = 0

	SELECT 3 AS RoleId
		,'Approver' AS [Role]
		,e.EmpId
		,e.FullName
		,e.NickName
		,e.Email
		,CASE 
			WHEN sc.Value = 'true' THEN e.LetsTalk 
			ELSE NULL 
		END AS LetsTalk
	FROM dbo.Employee e WITH (NOLOCK)
	LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
	LEFT JOIN dbo.SystemConfigs sc WITH (NOLOCK) ON ce.CompanyId = sc.CompanyId AND sc.[Key] = 'EnableLetstalk'
	WHERE e.EmpId = @ApproverId
		AND e.[Enabled] = 1
		AND e.isDeleted = 0

	SELECT @TeamId = GroupId
	FROM dbo.Employee WITH (NOLOCK)
	WHERE EmpId = @EmpId

	IF EXISTS (
			SELECT 1
			FROM dbo.MailSettings WITH (NOLOCK)
			WHERE GroupId = @TeamId
				AND [Action] = @Action
			)
	BEGIN
		SELECT ms.GroupId
			,ms.[Action]
			,ms.AllowSendUser
			,ms.AllowSendVerifier
			,ms.AllowSendApprover
			,ms.AllowSendHR
			,ms.AllowSendMailGroup
			,cs.Domain AS CallbackUrl
			,ce.CompanyId
		FROM dbo.MailSettings ms WITH (NOLOCK)
		LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = @EmpId AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
		LEFT JOIN dbo.CompanySite cs WITH (NOLOCK) ON ce.CompanyId = cs.CompanyId
		WHERE ms.GroupId = @TeamId
			AND ms.[Action] = @Action
	END
	ELSE
	BEGIN
		SELECT ms.GroupId
			,ms.[Action]
			,ms.AllowSendUser
			,ms.AllowSendVerifier
			,ms.AllowSendApprover
			,ms.AllowSendHR
			,ms.AllowSendMailGroup
			,cs.Domain AS CallbackUrl
			,ce.CompanyId
		FROM dbo.MailSettings ms WITH (NOLOCK)
		LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = @EmpId AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
		LEFT JOIN dbo.CompanySite cs WITH (NOLOCK) ON ce.CompanyId = cs.CompanyId
		WHERE ms.GroupId = 0
			AND ms.[Action] = @Action
	END
END