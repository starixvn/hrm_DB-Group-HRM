USE bodb_HRM
GO

ALTER TABLE dbo.Unit ADD CompanyId INT NOT NULL; -- Temp CompanyId for mapping
ALTER TABLE dbo.Unit ADD OldUnitId INT NULL;

ALTER TABLE dbo.Department ADD CompanyId INT NOT NULL; -- Temp CompanyId for mapping
ALTER TABLE dbo.Department ADD OldDepartmentId INT NULL;

ALTER TABLE dbo.Section ADD CompanyId INT NOT NULL; -- Temp CompanyId for mapping
ALTER TABLE dbo.Section ADD OldSectionId INT NULL;

ALTER TABLE dbo.[Group] ADD CompanyId INT NOT NULL;
ALTER TABLE dbo.[Group] ADD OldGroupId INT NULL;

ALTER TABLE dbo.Shift ADD CompanyId INT NOT NULL;
ALTER TABLE dbo.Shift ADD OldShiftId INT NULL;

ALTER TABLE dbo.LeaveType ADD CompanyId INT NOT NULL;
ALTER TABLE dbo.LeaveType DROP CONSTRAINT PK_LeaveType;
ALTER TABLE dbo.LeaveType DROP COLUMN LeaveTypeId;
ALTER TABLE dbo.LeaveType ADD LeaveTypeId INT NOT NULL;
ALTER TABLE dbo.LeaveType ADD CONSTRAINT PK_LeaveType PRIMARY KEY CLUSTERED (CompanyId, LeaveTypeId);

ALTER TABLE dbo.Holiday ADD CompanyId INT NOT NULL;
ALTER TABLE dbo.Holiday ADD OldHolidayId INT NULL;

-- ALTER TABLE dbo.DisciplineType ADD CompanyId INT;
-- ALTER TABLE dbo.DisciplineType ADD OldDisciplineTypeId INT;
-- ALTER TABLE dbo.DisciplineType DROP CONSTRAINT PK_DisciplineType;
-- ALTER TABLE dbo.DisciplineType DROP COLUMN DisciplineTypeId;
-- ALTER TABLE dbo.DisciplineType ADD DisciplineTypeId INT IDENTITY(1,1) PRIMARY KEY;

ALTER TABLE dbo.Memo ADD CompanyId INT NOT NULL;
ALTER TABLE dbo.Memo ADD OldId INT NULL;

ALTER TABLE dbo.SystemConfigs ADD CompanyId INT NOT NULL;

ALTER TABLE dbo.[Message] ADD CompanyId INT NOT NULL; -- Temp CompanyId for mapping
ALTER TABLE dbo.[Message] ADD OldMessageId INT NULL;

ALTER TABLE dbo.LookupData ADD CompanyId INT NOT NULL;
ALTER TABLE dbo.LookupData ADD OldId INT NULL;

ALTER TABLE dbo.Employee ADD OldEmpId INT NULL;

ALTER TABLE dbo.EmployeePaternity ADD OldPaternityId INT NULL;
ALTER TABLE dbo.EmployeePostnatal ADD OldPostnatalId INT NULL;
ALTER TABLE dbo.EmployeeRelationship ADD OldId INT NULL;
ALTER TABLE dbo.EmployeeWorkFromHome ADD OldEmployeeWorkFromHomeId INT NULL;

ALTER TABLE [bodb_HRM].[dbo].[WorkingTimeRequest]
ADD CompanyId INT NULL, --temp for query
OldRequestId INT NULL;

ALTER TABLE [bodb_HRM].[dbo].[WorkingTimeRequestHistory]
ADD OldHistoryId INT NULL;

ALTER TABLE [bodb_HRM].[dbo].[HospitalizationLeaveTrans]
ADD OldTransId INT NULL;

ALTER TABLE [bodb_HRM].[dbo].[LeaveTrans]
ADD OldLeaveTransId INT NULL;

ALTER TABLE [bodb_HRM].[dbo].[OTMonthlyRequest]
ADD OldRequestId INT NULL; -- this new id type not related to RequestId from WorkingTimeRequest table

ALTER TABLE [bodb_HRM].[dbo].[RefResource]
ADD CompanyId INT NULL;

ALTER TABLE dbo.TimeRecord ADD CompanyId SMALLINT, OldId BIGINT;
ALTER TABLE dbo.TimeRecord DROP CONSTRAINT PK_TimeRecord;
ALTER TABLE dbo.TimeRecord ALTER COLUMN Id BIGINT;
ALTER TABLE dbo.TimeRecord ADD CONSTRAINT PK_TimeRecord PRIMARY KEY (Id);

ALTER TABLE dbo.TimeRecordExt DROP CONSTRAINT PK_TimeRecordExt;
ALTER TABLE dbo.TimeRecordExt ALTER COLUMN Id BIGINT NOT NULL;
ALTER TABLE dbo.TimeRecordExt ADD CONSTRAINT PK_TimeRecordExt PRIMARY KEY (Id);

ALTER TABLE dbo.RoleFunction DROP CONSTRAINT PK_RoleFunction;
ALTER TABLE dbo.RoleFunction ADD CompanyId INT NOT NULL;
ALTER TABLE dbo.RoleFunction ADD CONSTRAINT PK_RoleFunction PRIMARY KEY (CompanyId, RoleId, FunctionId);