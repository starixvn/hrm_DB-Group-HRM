USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CompanyTimeZone INT;
DECLARE @ServerTimeZone INT;
SET @CompanyId = 3;
SET @ServerTimeZone =  DATEPART(TZOFFSET, SYSDATETIMEOFFSET()) / 60;
SET @CompanyTimeZone = 7;
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
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wr.VerifiedDate)
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wr.ApprovedDate)
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wr.HRDate)
           ,wr.VerifiedStatus
           ,wr.ApprovedStatus
           ,wr.HRStatus
           ,empCreated.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wr.CreatedDate)
           ,empModified.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wr.ModifiedDate)
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
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wrh.VerifiedDate)
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wrh.ApprovedDate)
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wrh.HRDate)
           ,wrh.VerifiedStatus
           ,wrh.ApprovedStatus
           ,wrh.HRStatus
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wrh.InsertedDate)
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wrh.ModifiedDate)
           ,empModified.EmpId
           ,empCreated.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wrh.CreatedDate)
           ,wrh.ReworkCount
           ,wrh.ApproverComment
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, wrh.LogDate)
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


