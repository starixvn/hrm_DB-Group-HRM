/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetByEmployee]
(
    @EmpId INT,
    @CompanyId SMALLINT,
    @FromDate DATE,
    @ToDate DATE
)
AS
/*
    Created: Tim.Trinh@2019-09-27
    Task: get change shift request
    DB: bodb_HRM

    Revisions:
	    20250602@Jay: Cross company
	    20250716@Mira: remove company with nick name for employee in different company [#Redmine: 232030]
        20250724@Tim: return system in case auto approve request [Redmine: #233324]
    Param's Explanation:
*/
BEGIN
    WITH tmpRequestHistory AS (
        SELECT ROW_NUMBER() OVER (PARTITION BY rh.RequestId ORDER BY rh.LogDate DESC) AS RowIndex
            ,rh.RequestId
            ,ap_AH.ModifiedBy AS EmpId
            ,CASE WHEN rh.ModifiedBy = -1 THEN 'System' ELSE ap_AH.NickName END AS Nickname
            ,CASE WHEN rh.ModifiedBy = -1 THEN '' ELSE ap_AH.FullName END AS FullName
        FROM dbo.WorkingTimeRequestHistory AS rh WITH (NOLOCK)
            INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON rh.RequestId = cs.RequestId
            LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.EmpId = rh.ModifiedBy
        WHERE rh.EmpId = @EmpId
    )

	SELECT wkr.RequestId
		,cs.TypeId
		,cs.FromDate
		,cs.ToDate
		,wkr.Remark
		,wkr.CurrentStatus
		,wkr.CreatedDate
		,wkr.VerifiedDate
		,wkr.ApprovedDate
		,wkr.HRDate AS ProcessedDate
		,emp.EmpId
		,emp.NickName
		,emp.FullName
		,verifier.EmpId AS VerifierId
		,verifier.NickName
		,verifier.FullName
		,approver.EmpId AS ApproverId
		,approver.NickName
		,approver.FullName
		,hr.EmpId AS HRId
		,hr.NickName
		,hr.FullName
		,ap_AH.EmpId AS ApprovedById
		,ap_AH.Nickname
		,ap_AH.FullName
	FROM dbo.WorkingTimeRequest AS wkr WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wkr.RequestId = cs.RequestId
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON cs.EmpId = emp.EmpId
		AND emp.EmpId = @EmpId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = wkr.VerifierId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = verifier.EmpId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = wkr.ApproverId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = approver.EmpId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.EmpId = wkr.EmpId
		LEFT JOIN tmpRequestHistory AS ap_AH ON cs.RequestId = ap_AH.RequestId AND ap_AH.RowIndex = 1
    WHERE (
			cs.FromDate BETWEEN @fromdate AND @todate
			AND cs.ToDate >= @todate
			)
		OR (
			cs.FromDate <= @fromdate
			AND @todate BETWEEN cs.FromDate AND cs.ToDate
			)
		OR cs.ToDate BETWEEN @fromdate AND @todate
	ORDER BY wkr.CreatedDate DESC
END