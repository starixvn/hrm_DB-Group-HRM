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




INSERT INTO [dbo].[ScheduleArrangement]
           (EmployeeId
           ,Remark
           ,DisplayOrder
           ,ModifiedBy
           ,ModifiedDate)
     SELECT
           emp.EmpId
           ,sa.Remark
           ,sa.DisplayOrder
           ,empModified.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, sa.ModifiedDate)
	FROM [SMSHRM].[dbo].[ScheduleArrangement] AS sa  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON sa.EmployeeId = emp.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified ON sa.ModifiedBy = empModified.OldEmpId;

INSERT INTO [dbo].[ScheduleArrangementDefaultShift]
           (EmployeeId
           ,FromDate
           ,ShiftId
           ,ModifiedBy
           ,ModifiedDate)
     SELECT
           emp.EmpId
           ,sas.FromDate
           ,s.ShiftId
           ,empModified.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, sas.ModifiedDate)
	FROM [SMSHRM].[dbo].[ScheduleArrangementDefaultShift] AS sas  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON sas.EmployeeId = emp.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified ON sas.ModifiedBy = empModified.OldEmpId
	LEFT JOIN dbo.Shift AS s WITH (NOLOCK) ON sas.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId;



INSERT INTO [dbo].[ScheduleArrangementGroupOrder]
           (GroupId
           ,DisplayOrder
           ,ModifiedBy
           ,ModifiedDate)
     SELECT
           g.GroupId
           ,sag.DisplayOrder
           ,empModified.EmpId
           ,DATEADD(HOUR, @ServerTimeZone - @CompanyTimeZone, sag.ModifiedDate)
	FROM [SMSHRM].[dbo].[ScheduleArrangementGroupOrder] AS sag  WITH (NOLOCK)
	INNER JOIN dbo.[Group] AS g ON sag.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId 
	LEFT JOIN @EmployeeMapping AS empModified ON sag.ModifiedBy = empModified.OldEmpId;




INSERT INTO [dbo].[ScheduleArrangementOffDayReplacement]
           (EmployeeId
           ,WorkDate
           ,ReplaceForDate)
     SELECT
           emp.EmpId
           ,sar.WorkDate
           ,sar.ReplaceForDate
	FROM [SMSHRM].[dbo].[ScheduleArrangementOffDayReplacement] AS sar  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON sar.EmployeeId = emp.OldEmpId 



GO

