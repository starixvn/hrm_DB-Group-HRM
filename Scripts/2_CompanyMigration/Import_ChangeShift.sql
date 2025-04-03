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


INSERT INTO [dbo].[ChangeShiftRequest]
           (RequestId
           ,EmpId
           ,FromDate
           ,ToDate
           ,TypeId) --ChangeShift or MoveOff Day
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,cs.FromDate
           ,cs.ToDate
           ,cs.TypeId 
	FROM SMSHRM.dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON cs.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON cs.EmpId = emp.OldEmpId;



INSERT INTO [dbo].[ChangeShiftRequestDetail]
           (OnDate
           ,EmpId
           ,RequestId
           ,FromShift
           ,ToShift
           ,Remark
           ,ToDate)
     SELECT
           OnDate
           ,emp.EmpId
           ,wkr.RequestId
           ,CASE WHEN  csd.FromShift = -1 THEN csd.FromShift   -- (-1 is OffDay)
				 ELSE  s1.ShiftID 
			END
           ,CASE WHEN  csd.ToShift = -1 THEN csd.ToShift 
				 ELSE  s2.ShiftID
			END 
           ,csd.Remark
           ,csd.ToDate
	FROM SMSHRM.dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON csd.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON csd.EmpId = emp.OldEmpId
	LEFT JOIN dbo.Shift AS s1 WITH (NOLOCK) ON s1.OldShiftId = csd.FromShift AND s1.CompanyId = @CompanyId
	LEFT JOIN dbo.Shift AS s2 WITH (NOLOCK) ON s2.OldShiftId = csd.ToShift AND s2.CompanyId = @CompanyId;


INSERT INTO [dbo].[ChangeShiftRequestDetailHistory]
           (RequestId
           ,EmpId
           ,OnDate
           ,FromShift
           ,ToShift
           ,Remark
           ,ToDate
           ,HistoryId)
     SELECT 
           wkr.RequestId
           ,emp.EmpId
           ,csdh.OnDate
           ,CASE WHEN  csdh.FromShift = -1 THEN csdh.FromShift   -- (-1 is OffDay)
				 ELSE  s1.ShiftID 
			END
           ,CASE WHEN  csdh.ToShift = -1 THEN csdh.ToShift 
				 ELSE  s2.ShiftID
			END 
           ,csdh.Remark
           ,csdh.ToDate
           ,wkrh.HistoryId
	FROM SMSHRM.dbo.ChangeShiftRequestDetailHistory AS csdh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON csdh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON csdh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON csdh.EmpId = emp.OldEmpId
	LEFT JOIN dbo.Shift AS s1 WITH (NOLOCK) ON s1.OldShiftId = csdh.FromShift AND s1.CompanyId = @CompanyId
	LEFT JOIN dbo.Shift AS s2 WITH (NOLOCK) ON s2.OldShiftId = csdh.ToShift AND s2.CompanyId = @CompanyId;



INSERT INTO [dbo].[ChangeShiftRequestHistory]
           (RequestId
           ,EmpId
           ,FromDate
           ,ToDate
           ,TypeId
           ,HistoryId)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,csh.FromDate
           ,csh.ToDate
           ,csh.TypeId
           ,wkrh.HistoryId
	FROM SMSHRM.dbo.ChangeShiftRequestHistory AS csh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON csh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON csh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON csh.EmpId = emp.OldEmpId

GO


