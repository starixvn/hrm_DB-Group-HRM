/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetById] 
	@RequestId BIGINT,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-09-20
Task: get request by id
DB: HRM

Revisions:
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
		,empsum.IsTopManager
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
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = wkr.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON verifier.EmpId = vece.EmpId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = wkr.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON approver.EmpId = apce.EmpId
	WHERE wkr.RequestId = @RequestId
END
