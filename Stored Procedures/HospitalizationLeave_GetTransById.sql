/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[HospitalizationLeave_GetTransById] @TransId INT
AS
/*
Created: Tim.Trinh@2021-08-20
Task: get hospitalization leave transaction by id
DB: HRM
Original:

Revisions:
	20250821@Jay: restructure for transfer [Redmine: #235678]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT TransId
		,ce.EmpId
		,ce.NickName
		,RequestId
		,[Description]
		,FromDate AS AffectedFrom
		,ToDate
		,DeductDays
		,CreditDays
		,ISNULL(CreditDays, 0) - ISNULL(DeductDays, 0) AS TotalDays
		,t.IsDeleted
	FROM dbo.HospitalizationLeaveTrans AS t WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON t.EmpId = ce.EmpId
	WHERE TransId = @TransId
		AND RequestId IS NULL
		AND t.IsDeleted = 0
END
