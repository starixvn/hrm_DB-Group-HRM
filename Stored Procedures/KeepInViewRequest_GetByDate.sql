/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_GetByDate]
(
    @EmpId INT,
	@CompanyId SMALLINT,
	@FromDate DATE,
	@ToDate DATE
)
AS
/*
    Created: Quinn.Vo@20190604
    Task: Get Keep In View request by empId & date range.
    DB: bodb_HRM

    Revisions:
        20250602@Jay: Cross company
        20250716@Mira: remove company with nick name for employee in different company [#Redmine: 232030]
        20250724@Tim: return system in case auto approve request [Redmine: #233324]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    WITH tmpRequestHistory AS (
        SELECT ROW_NUMBER() OVER (PARTITION BY rh.RequestId ORDER BY rh.LogDate DESC) AS RowIndex
            ,rh.RequestId
            ,ap_AH.ModifiedBy AS EmpId
            ,CASE WHEN rh.ModifiedBy = -1 THEN 'System' ELSE ap_AH.NickName END AS Nickname
            ,CASE WHEN rh.ModifiedBy = -1 THEN '' ELSE ap_AH.FullName END AS FullName
        FROM dbo.WorkingTimeRequestHistory AS rh WITH (NOLOCK)
            INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON rh.RequestId = kiv.RequestId
            LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.EmpId = rh.ModifiedBy
        WHERE rh.EmpId = @EmpId
    )

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
		,ve.NickName
		,Ve.FullName
		,ap.EmpId AS ApproverId
		,ap.NickName
		,ap.FullName
		,pr.EmpId AS HRId
		,pr.NickName
		,pr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.Nickname
		,ap_AH.FullName
	FROM dbo.KeepInViewRequest AS kiv WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON kiv.RequestId = wk.RequestId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON kiv.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = kiv.EmpId
		AND ce.CompanyId = @CompanyId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON wk.VerifierId = ve.EmpId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = ve.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON wk.ApproverId = ap.EmpId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = ap.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON wk.HRId = pr.EmpId
		LEFT JOIN tmpRequestHistory AS ap_AH ON wk.RequestId = ap_AH.RequestId AND ap_AH.RowIndex = 1
	WHERE (
			@EmpId IS NULL
			OR kiv.EmpId = @EmpId
			)
		AND kiv.OnDate BETWEEN @FromDate
			AND @ToDate
	ORDER BY wk.CreatedDate DESC
END