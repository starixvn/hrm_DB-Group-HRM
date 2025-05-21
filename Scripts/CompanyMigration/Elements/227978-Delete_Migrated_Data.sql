

USE [bodb_HRM]
GO

DECLARE @CompanyId INT = 16;

-- Delete data in reverse order of insertion to maintain referential integrity

-- 1. Delete RefResource
DELETE FROM dbo.RefResource WHERE CompanyId = @CompanyId;

-- 2. Delete ScheduleArrangement related tables
DELETE FROM dbo.ScheduleArrangementOffDayReplacement 
WHERE EmployeeId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.ScheduleArrangementGroupOrder 
WHERE GroupId IN (SELECT GroupId FROM dbo.[Group] WHERE CompanyId = @CompanyId);

DELETE FROM dbo.ScheduleArrangementDefaultShift 
WHERE EmployeeId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.ScheduleArrangement 
WHERE EmployeeId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 3. Delete OT related tables
DELETE FROM dbo.OTDailyRequest 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.OTMonthlyRequest 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 4. Delete Message related tables
DELETE FROM dbo.MessageGroup 
WHERE MessageId IN (SELECT MessageId FROM dbo.[Message] WHERE CompanyId = @CompanyId);

DELETE FROM dbo.MessageEmployee 
WHERE MessageId IN (SELECT MessageId FROM dbo.[Message] WHERE CompanyId = @CompanyId);

DELETE FROM dbo.[Message] WHERE CompanyId = @CompanyId;

-- 5. Delete Leave related tables
DELETE FROM dbo.LeaveTrans 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.LeaveRequestDetailHistory 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.LeaveRequestDetail 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.LeaveRequestHistory 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.LeaveRequest 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 6. Delete LateInEarlyOut related tables
DELETE FROM dbo.LateInEarlyOutRequestHistory 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.LateInEarlyOutRequest 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 7. Delete KeepInView related tables
DELETE FROM dbo.KeepInViewRequestHistory 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.KeepInViewRequest 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.KeepInViewByHourTrans 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.KeepInViewByDayTrans 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 8. Delete WeekendLeaveTrans
DELETE FROM dbo.WeekendLeaveTrans 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 9. Delete HospitalLeave related tables
DELETE FROM dbo.HospitalLeave 
WHERE RequestId IN (SELECT RequestId FROM dbo.WorkingTimeRequest WHERE CompanyId = @CompanyId);

DELETE FROM dbo.HospitalizationLeaveTrans 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 10. Delete MailSettings
DELETE FROM dbo.MailSettings 
WHERE GroupId IN (SELECT GroupId FROM dbo.[Group] WHERE CompanyId = @CompanyId);

-- 11. Delete ExtensionNumbers
DELETE FROM dbo.ExtensionNumbers WHERE CompanyId = @CompanyId;

-- 12. Delete Group related tables
DELETE FROM dbo.GroupSupervisor 
WHERE GroupId IN (SELECT GroupId FROM dbo.[Group] WHERE CompanyId = @CompanyId);

DELETE FROM dbo.GroupManager 
WHERE GroupId IN (SELECT GroupId FROM dbo.[Group] WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeGroup 
WHERE GroupId IN (SELECT GroupId FROM dbo.[Group] WHERE CompanyId = @CompanyId);

-- 13. Delete Employee related tables
DELETE FROM dbo.EmployeeWorkFromHome 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeSupervisor 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeSummary 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeRole 
WHERE EmployeeId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeRelationship 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeePostnatal 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeePaternity 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeDefaultShift 
WHERE EmpID IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeContract 
WHERE EmpID IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeCalendar 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.EmployeeAttendance 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 14. Delete Discipline related tables
DELETE FROM dbo.DisciplineRequestTrans 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.DisciplineOutOfControl 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.DisciplineIgnoreDetail 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.DisciplineIgnore 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.DisciplineGroupRule 
WHERE GroupId IN (SELECT GroupId FROM dbo.[Group] WHERE CompanyId = @CompanyId);

DELETE FROM dbo.Discipline 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.OtherDiscipline
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 15. Delete CheckInOut related tables
DELETE FROM dbo.CheckInOutRequestHistory 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.CheckInOutRequest 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 16. Delete ChangeShift related tables
DELETE FROM dbo.ChangeShiftRequestHistory 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.ChangeShiftRequestDetailHistory 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.ChangeShiftRequestDetail 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.ChangeShiftRequest 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 17. Delete RoleFunction
DELETE FROM dbo.RoleFunction WHERE CompanyId = @CompanyId;

-- 18. Delete SickLeaveTrans
DELETE FROM dbo.SickLeaveTrans 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 19. Delete TimeRecord related tables
DELETE FROM dbo.TimeRecordExt 
WHERE Id IN (SELECT Id FROM dbo.TimeRecord WHERE CompanyId = @CompanyId);

DELETE FROM dbo.TimeRecord WHERE CompanyId = @CompanyId;

-- 20. Delete tmpEmployeeAttendace
DELETE FROM dbo.tmpEmployeeAttendace 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 21. Delete tmpEmployeeCalendar
DELETE FROM dbo.tmpEmployeeCalendar 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 22. Delete tmpLeaveBalance related tables
DELETE FROM dbo.tmpHospitalizationLeaveBalance 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.tmpKIVLeaveBalance 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.tmpLeaveBalance 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

DELETE FROM dbo.tmpSickLeaveBalance 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 23. Delete WorkingTimeRequest related tables
DELETE FROM dbo.WorkingTimeRequestHistory 
WHERE RequestId IN (SELECT RequestId FROM dbo.WorkingTimeRequest WHERE CompanyId = @CompanyId);

DELETE FROM dbo.WorkingTimeRequest WHERE CompanyId = @CompanyId;

-- 24. Delete [Group]
DELETE FROM dbo.[Group] WHERE CompanyId = @CompanyId;

-- 26. Delete LookupData
DELETE FROM dbo.LookupData WHERE CompanyId = @CompanyId;

-- 27. Delete SystemConfigs
DELETE FROM dbo.SystemConfigs WHERE CompanyId = @CompanyId;

-- 28. Delete Memo
DELETE FROM dbo.Memo WHERE CompanyId = @CompanyId;

-- 29. Delete Holiday
DELETE FROM dbo.Holiday WHERE CompanyId = @CompanyId;

-- 30. Delete LeaveType
DELETE FROM dbo.LeaveType WHERE CompanyId = @CompanyId;

-- 31. Delete Shift
DELETE FROM dbo.Shift WHERE CompanyId = @CompanyId;

-- 32. Delete Employee
DELETE FROM dbo.Employee 
WHERE EmpId IN (SELECT EmpId FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId);

-- 33. Delete CompanyEmployee
DELETE FROM dbo.CompanyEmployee WHERE CompanyId = @CompanyId;

