USE [bodb_HRM]
GO
/****** Object:  StoredProcedure [dbo].[ChangeShiftRequest_GetByEmployee]    Script Date: 3/10/2025 2:34:55 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetByEmployee] @EmpId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-09-27
Task: get change shift request
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
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
		,ap_AH.NickName
		,ap_AH.FullName
	FROM dbo.WorkingTimeRequest AS wkr WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wkr.RequestId = cs.RequestId
		AND (
			(
				cs.FromDate BETWEEN @fromdate
					AND @todate
				AND cs.ToDate >= @todate
				)
			OR (
				cs.FromDate <= @fromdate
				AND @todate BETWEEN cs.FromDate
					AND cs.ToDate
				)
			OR cs.ToDate BETWEEN @fromdate
				AND @todate
			)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON cs.EmpId = emp.EmpId
		AND emp.EmpId = @EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON wkr.EmpId = ce.EmpId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.EmpId = wkr.VerifierId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.EmpId = wkr.ApproverId
		LEFT JOIN dbo.Employee AS hr WITH (NOLOCK) ON hr.EmpId = wkr.EmpId
		LEFT JOIN dbo.Employee AS ap_AH WITH (NOLOCK) ON ap_AH.empid = (SELECT TOP 1 ModifiedBy FROM WorkingTimeRequestHistory WITH (NOLOCK) WHERE RequestId = cs.RequestId ORDER BY LogDate DESC)
	WHERE ce.CompanyId = @CompanyId
	ORDER BY wkr.CreatedDate DESC
END





