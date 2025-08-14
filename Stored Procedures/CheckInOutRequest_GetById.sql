/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_GetById]
(
	@RequestId INT,
	@CompanyId SMALLINT
)
AS
/*
    Created: Quinn.Vo@20190624
    Task: Get Check in/out request by RequestId.
    DB: bodb_HRM

    Revisions:
        20250722@Tim: auto approve request [Redmine: #233324]
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT cio.RequestId
		,cio.OnDate
		,wk.RequestType AS RequestTypeId
		,cio.RequestTime
		,cio.ReasonId
		,wk.Remark
		,cio.RefNo
		,sh.[Name] AS ShiftName
		,wk.CreatedDate
		,wk.CurrentStatus
		,wk.VerifiedDate
		,wk.ApprovedDate
		,wk.HRDate AS ProcessedDate
		,cio.EmpId
		,ce.NickName
		,e.FullName
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
	FROM dbo.CheckInOutRequest AS cio WITH (NOLOCK)
		INNER JOIN dbo.WorkingTimeRequest AS wk WITH (NOLOCK) ON cio.RequestId = wk.RequestId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON cio.EmpId = ce.EmpId
		INNER JOIN dbo.EmployeeCalendar AS empca WITH (NOLOCK) ON cio.OnDate = empca.WorkDate
		AND cio.EmpId = empca.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
        --AND ce.CompanyId = @CompanyId
		LEFT JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON empca.ShiftId = sh.ShiftId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON wk.VerifierId = vece.EmpId
		LEFT JOIN dbo.Employee AS ve WITH (NOLOCK) ON vece.UserId = ve.UserId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON wk.ApproverId = apce.EmpId
		LEFT JOIN dbo.Employee AS ap WITH (NOLOCK) ON ap.UserId = apce.UserId
		LEFT JOIN dbo.CompanyEmployee AS prce WITH (NOLOCK) ON wk.HRId = prce.EmpId
		LEFT JOIN dbo.Employee AS pr WITH (NOLOCK) ON prce.UserId = pr.UserId
	WHERE cio.RequestId = @RequestId
END