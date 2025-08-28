/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_GetById]
(
    @RequestId INT
    ,@CompanyId INT = 0
)
AS
/*
    Created: Quinn.Vo@20190626
    Task: Get late in/early out request by RequestId.
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT lieo.RequestId
		,lieo.OnDate
		,lieo.LateInMins
		,lieo.EarlyOutMins
		,lieo.ReasonId
		,wk.Remark
		,lieo.RefNo
		,wk.RequestType AS RequestTypeId
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,lieo.EmpId
		,ce.NickName
		,emp.FullName
        ,ce.CompanyId
		,ce.AutoApproveRequest
		,vece.EmpId AS VerifierId
		,vece.NickName
		,vece.CompanyId
		,Ve.FullName
		,apce.EmpId AS ApproverId
		,apce.NickName
		,ap.FullName
		,apce.CompanyId
		,prce.EmpId AS HRId
		,prce.NickName
		,pr.FullName
	FROM dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON lieo.RequestId = wk.RequestId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = lieo.EmpId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ce.UserId = emp.UserId
        --AND ce.CompanyId = @CompanyId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON wk.VerifierId = vece.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON vece.UserId = ve.UserId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON wk.ApproverId = apce.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON apce.UserId = ap.UserId
		LEFT JOIN dbo.CompanyEmployee AS prce WITH (NOLOCK) ON wk.HRId = apce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON pr.UserId = prce.UserId
	WHERE lieo.RequestId = @RequestId
END
