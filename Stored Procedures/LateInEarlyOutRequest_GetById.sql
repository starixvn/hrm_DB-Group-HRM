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
		,emp.NickName
		,emp.FullName
        ,ce.CompanyId
		,ce.AutoApproveRequest
		,ve.EmpId AS VerifierId
		,ve.NickName
		,vece.CompanyId
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,apce.CompanyId
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
	FROM dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON lieo.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON lieo.EmpId = emp.EmpId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = lieo.EmpId
        --AND ce.CompanyId = @CompanyId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON ve.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON ap.EmpId = apce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
	WHERE lieo.RequestId = @RequestId
END