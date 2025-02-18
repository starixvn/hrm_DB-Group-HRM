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




INSERT INTO [dbo].[CheckInOutRequest]
           (RequestId
           ,EmpId
           ,OnDate
           ,RequestTime
           ,ReasonId
           ,RefNo)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,cio.OnDate
           ,cio.RequestTime --Actual Request time
           ,cio.ReasonId
           ,cio.RefNo
	FROM SMSHRM.dbo.CheckInOutRequest AS cio WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON cio.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON cio.EmpId = emp.OldEmpId


INSERT INTO [dbo].[CheckInOutRequestHistory]
           (RequestId
           ,EmpId
           ,OnDate
           ,RequestTime 
           ,ReasonId
           ,RefNo
           ,HistoryId)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,cioh.OnDate
           ,cioh.RequestTime
           ,cioh.ReasonId
           ,cioh.RefNo
           ,wkrh.HistoryId
	FROM SMSHRM.dbo.CheckInOutRequestHistory AS cioh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON cioh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON cioh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON cioh.EmpId = emp.OldEmpId
GO






/*INSERT INTO [dbo].[ChangeShiftRequestDetailHistory]
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
	LEFT JOIN dbo.Shift AS s2 WITH (NOLOCK) ON s2.OldShiftId = csdh.ToShift AND s2.CompanyId = @CompanyId;*/


GO


