USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
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



INSERT INTO [dbo].[LateInEarlyOutRequest]
           (RequestId
           ,EmpId
           ,OnDate
           ,LateInMins
           ,EarlyOutMins
           ,ReasonId
           ,RefNo)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lieo.OnDate
           ,lieo.LateInMins
           ,lieo.EarlyOutMins
           ,lieo.ReasonId
           ,lieo.RefNo
	FROM [SMSHRM].[dbo].[LateInEarlyOutRequest] AS lieo WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lieo.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON lieo.EmpId = emp.OldEmpId



INSERT INTO [dbo].[LateInEarlyOutRequestHistory]
           (RequestId
           ,EmpId
           ,OnDate
           ,LateInMins
           ,EarlyOutMins
           ,ReasonId
           ,RefNo
           ,HistoryId)
     SELECT
            wkr.RequestId
           ,emp.EmpId
           ,lieoh.OnDate
           ,lieoh.LateInMins
           ,lieoh.EarlyOutMins
           ,lieoh.ReasonId
           ,lieoh.RefNo
           ,wkrh.HistoryId
	FROM [SMSHRM].[dbo].[LateInEarlyOutRequestHistory] AS lieoh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lieoh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON lieoh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON lieoh.EmpId = emp.OldEmpId

GO


