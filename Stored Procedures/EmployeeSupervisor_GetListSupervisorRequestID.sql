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
		,EmpId
		,FullName
		,NickName
		,Email
		,LetsTalk
	FROM dbo.Employee WITH (NOLOCK)
	WHERE EmpId = @EmpId
		AND [Enabled] = 1
		AND isDeleted = 0

	SELECT 2 AS RoleId
		,'Verifier' AS [Role]
		,EmpId
		,FullName
		,NickName
		,Email
		,LetsTalk
	FROM dbo.Employee WITH (NOLOCK)
	WHERE EmpId = @VerifierId
		AND [Enabled] = 1
		AND isDeleted = 0

	SELECT 3 AS RoleId
		,'Approver' AS [Role]
		,EmpId
		,FullName
		,NickName
		,Email
		,LetsTalk
	FROM dbo.Employee WITH (NOLOCK)
	WHERE EmpId = @ApproverId
		AND [Enabled] = 1
		AND isDeleted = 0

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
		SELECT GroupId
			,[Action]
			,AllowSendUser
			,AllowSendVerifier
			,AllowSendApprover
			,AllowSendHR
			,AllowSendMailGroup
		FROM dbo.MailSettings WITH (NOLOCK)
		WHERE GroupId = @TeamId
			AND [Action] = @Action
	END
	ELSE
	BEGIN
		SELECT GroupId
			,[Action]
			,AllowSendUser
			,AllowSendVerifier
			,AllowSendApprover
			,AllowSendHR
			,AllowSendMailGroup
		FROM dbo.MailSettings WITH (NOLOCK)
		WHERE GroupId = 0
			AND [Action] = @Action
	END
END