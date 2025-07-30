/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetById]
(
	@RequestId BIGINT,
	@CompanyId SMALLINT
)
AS
/*
    Created: Tim.Trinh@2019-09-20
    Task: get request by id
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT wkr.RequestId
		,cs.TypeId
		,cs.FromDate
		,cs.ToDate
		,wkr.Remark
		,wkr.CurrentStatus
		,wkr.CreatedDate
		,wkr.VerifiedDate
		,wkr.ApprovedDate
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,ce.CompanyId
		,ce.AutoApproveRequest
		,verifier.EmpId AS VerifierId
		,verifier.NickName
		,verifier.FullName
		,vece.CompanyId
		,approver.EmpId AS ApproverId
		,approver.NickName
		,approver.FullName
		,apce.CompanyId
	FROM dbo.WorkingTimeRequest AS wkr WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wkr.RequestId = cs.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON cs.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = cs.EmpId
        --AND ce.CompanyId = @CompanyId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = wkr.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON verifier.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = wkr.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON approver.EmpId = apce.EmpId
	WHERE wkr.RequestId = @RequestId
END