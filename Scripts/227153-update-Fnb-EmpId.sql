USE [FBM]
GO


SELECT *
INTO EmpCalendar_Staging
FROM EmpCalendar
WHERE 1 = 0;  -- Structure only, no data

INSERT INTO EmpCalendar_Staging (
    WorkDate, EmpId, CompanyID, ShiftId,
    IsHoliday, IsOffDay, IsLeaveDay,
    LeaveTypeId, LeaveDay, ModifiedDate,
    SynDate, HasCheckIn
)
SELECT
    ec.WorkDate,
    e.UserId AS EmpId,
    ec.CompanyID,
    ec.ShiftId,
    ec.IsHoliday,
    ec.IsOffDay,
    ec.IsLeaveDay,
    ec.LeaveTypeId,
    ec.LeaveDay,
    ec.ModifiedDate,
    ec.SynDate,
    ec.HasCheckIn
FROM EmpCalendar ec
JOIN Employee e ON e.EmpId = ec.EmpId AND e.CompanyId = 2
WHERE ec.CompanyID = 2;

DELETE FROM EmpCalendar
WHERE CompanyID = 2

INSERT INTO EmpCalendar
SELECT * FROM EmpCalendar_Staging;

 DROP TABLE EmpCalendar_Staging;

 GO


UPDATE e
SET e.EmpId = e.UserId
FROM Employee e
WHERE e.CompanyID = 2;
