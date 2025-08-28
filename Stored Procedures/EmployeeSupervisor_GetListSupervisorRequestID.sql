/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
        20250115@Henry: check company Letstalk config per person
        20250813@Jay: change db structure [Redmine: #235678]
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
		,ce.EmpId
		,e.FullName
		,ce.NickName
		,ce.Email
		,CASE 
			WHEN sc.Value = 'true' THEN e.LetsTalk 
			ELSE NULL 
		END AS LetsTalk
		,ce.Code AS EmpCode
		,CASE 
			WHEN epic.EmpId IS NOT NULL 
			THEN epic.NickName + ' (' + epic.Code + ')'
			ELSE '' 
		END AS PICDisplayName
	FROM dbo.CompanyEmployee ce WITH (NOLOCK)
	LEFT JOIN dbo.[Group] g WITH (NOLOCK) ON ce.GroupId = g.GroupId
	LEFT JOIN dbo.CompanyEmployee epic WITH (NOLOCK) ON g.PICEmpId = epic.EmpId
	INNER JOIN dbo.Employee e (NOLOCK) ON e.UserId = ce.UserId
	LEFT JOIN dbo.SystemConfigs sc WITH (NOLOCK) ON ce.CompanyId = sc.CompanyId AND sc.[Key] = 'EnableLetstalk'
	WHERE ce.EmpId = @EmpId
		AND ce.[Enabled] = 1
		AND ce.isDeleted = 0

	SELECT 2 AS RoleId
		,'Verifier' AS [Role]
		,ce.EmpId
		,e.FullName
		,ce.NickName
		,ce.Email
		,CASE 
			WHEN sc.Value = 'true' THEN e.LetsTalk 
			ELSE NULL 
		END AS LetsTalk
	FROM dbo.CompanyEmployee ce WITH (NOLOCK)
	LEFT JOIN dbo.Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
	LEFT JOIN dbo.SystemConfigs sc WITH (NOLOCK) ON ce.CompanyId = sc.CompanyId AND sc.[Key] = 'EnableLetstalk'
	WHERE ce.EmpId = @VerifierId
		AND ce.[Enabled] = 1
		AND ce.isDeleted = 0

	SELECT 3 AS RoleId
		,'Approver' AS [Role]
		,ce.EmpId
		,e.FullName
		,ce.NickName
		,ce.Email
		,CASE 
			WHEN sc.Value = 'true' THEN e.LetsTalk 
			ELSE NULL 
		END AS LetsTalk
	FROM dbo.CompanyEmployee ce WITH (NOLOCK)
	LEFT JOIN dbo.Employee e WITH (NOLOCK) ON e.UserId = ce.UserId
	LEFT JOIN dbo.SystemConfigs sc WITH (NOLOCK) ON ce.CompanyId = sc.CompanyId AND sc.[Key] = 'EnableLetstalk'
	WHERE ce.EmpId = @ApproverId
		AND ce.[Enabled] = 1
		AND ce.isDeleted = 0

	SELECT @TeamId = GroupId
	FROM dbo.CompanyEmployee WITH (NOLOCK)
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
			,ce.CompanyId
		FROM dbo.MailSettings ms WITH (NOLOCK)
		LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = @EmpId AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
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
			,ce.CompanyId
		FROM dbo.MailSettings ms WITH (NOLOCK)
		LEFT JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = @EmpId AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
		WHERE ms.GroupId = 0
			AND ms.[Action] = @Action
	END
END