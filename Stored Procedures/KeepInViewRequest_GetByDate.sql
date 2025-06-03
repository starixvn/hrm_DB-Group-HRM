/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_GetByDate] @EmpId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Quinn.Vo@20190604
Task: Get Keep In View request by empId & date range.
DB: HRM
Original:

Revisions:
	- Jay.Do: 20250602: Cross company
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT kiv.RequestId
		,kiv.KeepInViewType AS KeepInViewTypeId
		,kiv.OnDate
		,kiv.FromTime
		,kiv.ToTime
		,kiv.IsHalfDay
		,wk.Remark
		,kiv.RefNo
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,kiv.EmpId
		,e.NickName
		,e.FullName
		,ve.EmpId AS VerifierId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND vec.CompanyId != @CompanyId 
				THEN ve.NickName + ' (' + vec.[Name]  +')'
				ELSE ve.NickName
		END NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND apc.CompanyId != @CompanyId 
				THEN ap.NickName + ' (' + apc.[Name]  +')'
				ELSE ap.NickName
		END NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON kiv.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON kiv.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = kiv.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = kiv.RequestId ORDER BY LogDate DESC)
	WHERE (
			@EmpId IS NULL
			OR kiv.EmpId = @EmpId
			)
		AND ce.CompanyId = @CompanyId
		AND kiv.OnDate BETWEEN @FromDate
			AND @ToDate
	ORDER BY wk.CreatedDate DESC
END