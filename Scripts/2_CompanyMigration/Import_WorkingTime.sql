USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'UTC'; 
DECLARE @TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time'; 
SET @CompanyId = 3;

DECLARE @EmployeeMapping TABLE (
    EmpId INT,
    OldEmpId INT,
    CompanyId INT
);


INSERT INTO @EmployeeMapping (EmpId, OldEmpId, CompanyId)
SELECT DISTINCT tmpEmp.EmpId, tmpEmp.OldEmpId, ce.CompanyId  
FROM dbo.Employee AS tmpEmp WITH (NOLOCK) 
INNER JOIN dbo.CompanyEmployee AS ce  WITH (NOLOCK)
    ON tmpEmp.EmpId = ce.EmpId 
WHERE ce.CompanyId = @CompanyId


INSERT INTO [dbo].[WorkingTimeRequest]
           (EmpId
           ,RequestType
           ,Remark
           ,CurrentStatus
           ,VerifierId
           ,ApproverId
           ,HRId
           ,VerifiedDate
           ,ApprovedDate
           ,HRDate
           ,VerifiedStatus
           ,ApprovedStatus
           ,HRStatus
           ,CreatedBy
           ,CreatedDate
           ,ModifiedBy
           ,ModifiedDate
           ,ReworkCount
           ,ApproverComment
		   ,CompanyId
		   ,OldRequestId)
     SELECT
           emp.EmpId
           ,wr.RequestType
           ,wr.Remark
           ,wr.CurrentStatus
           ,empVerify.EmpId
           ,empApprove.EmpId
           ,empHr.EmpId
           ,wr.VerifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wr.ApprovedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wr.HRDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wr.VerifiedStatus
           ,wr.ApprovedStatus
           ,wr.HRStatus
           ,empCreated.EmpId
           ,wr.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empModified.EmpId
           ,wr.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wr.ReworkCount
           ,wr.ApproverComment
		   ,@CompanyId
		   ,wr.RequestId
	FROM SMSHRM.dbo.WorkingTimeRequest AS wr  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON wr.EmpId = emp.OldEmpId
	LEFT JOIN @EmployeeMapping AS empVerify ON wr.VerifierId = empVerify.OldEmpId
	LEFT JOIN @EmployeeMapping AS empApprove ON wr.ApproverId = empApprove.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empHr ON wr.HRId = empHr.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empCreated ON wr.CreatedBy = empCreated.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified ON wr.ModifiedBy = empModified.OldEmpId;
	

INSERT INTO [dbo].[WorkingTimeRequestHistory]
           (RequestId
           ,EmpId
           ,RequestType
           ,Remark
           ,CurrentStatus
           ,VerifierId
           ,ApproverId
           ,HRId
           ,VerifiedDate
           ,ApprovedDate
           ,HRDate
           ,VerifiedStatus
           ,ApprovedStatus
           ,HRStatus
           ,InsertedDate
           ,ModifiedDate
           ,ModifiedBy
           ,CreatedBy
           ,CreatedDate
           ,ReworkCount
           ,ApproverComment
           ,LogDate
		   ,OldHistoryId)
     SELECT
           wr.RequestId
           ,emp.EmpId
           ,wrh.RequestType
           ,wrh.Remark
           ,wrh.CurrentStatus
           ,empVerify.EmpId
           ,empApprove.EmpId
           ,empHr.EmpId
           ,wrh.VerifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wrh.ApprovedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wrh.HRDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wrh.VerifiedStatus
           ,wrh.ApprovedStatus
           ,wrh.HRStatus
           ,wrh.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wrh.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empModified.EmpId
           ,empCreated.EmpId
           ,wrh.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wrh.ReworkCount
           ,wrh.ApproverComment
           ,wrh.LogDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
		   ,wrh.HistoryId
	FROM SMSHRM.dbo.WorkingTimeRequestHistory as wrh  WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wr WITH (NOLOCK) ON wrh.RequestId = wr.OldRequestId AND wr.CompanyId = @CompanyId  --some requestId not exists in WR
	INNER JOIN @EmployeeMapping AS emp ON wrh.EmpId = emp.OldEmpId
	LEFT JOIN @EmployeeMapping AS empVerify ON wrh.VerifierId = empVerify.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empApprove  ON wrh.ApproverId = empApprove.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empHr  ON wrh.HRId = empHr.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empCreated ON wrh.CreatedBy = empCreated.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified  ON wrh.ModifiedBy = empModified.OldEmpId;

GO


