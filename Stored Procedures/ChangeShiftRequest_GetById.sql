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
        20250813@Jay: change db structure [Redmine: #235678]
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
		,ce.EmpId
		,ce.NickName
		,emp.FullName
		,ce.CompanyId
		,ce.AutoApproveRequest
		,vece.EmpId AS VerifierId
		,vece.NickName
		,ve.FullName
		,vece.CompanyId
		,apce.EmpId AS ApproverId
		,apce.NickName
		,ap.FullName
		,apce.CompanyId
	FROM dbo.WorkingTimeRequest AS wkr WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wkr.RequestId = cs.RequestId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = cs.EmpId
        --AND ce.CompanyId = @CompanyId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON wkr.VerifierId = vece.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON ve.UserId = vece.UserId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON wkr.ApproverId = apce.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON ap.UserId = apce.UserId
	WHERE wkr.RequestId = @RequestId
END
