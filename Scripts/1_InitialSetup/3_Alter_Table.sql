ALTER TABLE bodb_HRM.dbo.Unit ADD CompanyId INT NOT NULL; -- Temp CompanyId for mapping
ALTER TABLE bodb_HRM.dbo.Unit ADD OldUnitId INT NOT NULL;

ALTER TABLE bodb_HRM.dbo.Department ADD CompanyId INT NOT NULL; -- Temp CompanyId for mapping
ALTER TABLE bodb_HRM.dbo.Department ADD OldDepartmentId INT NOT NULL;

ALTER TABLE bodb_HRM.dbo.Section ADD CompanyId INT NOT NULL; -- Temp CompanyId for mapping
ALTER TABLE bodb_HRM.dbo.Section ADD OldSectionId INT NOT NULL;

ALTER TABLE bodb_HRM.dbo.[Group] ADD CompanyId INT NOT NULL;
ALTER TABLE bodb_HRM.dbo.[Group] ADD OldGroupId INT NOT NULL;

ALTER TABLE bodb_HRM.dbo.Shift ADD CompanyId INT NOT NULL;
ALTER TABLE bodb_HRM.dbo.Shift ADD OldShiftId INT NOT NULL;

ALTER TABLE bodb_HRM.dbo.LeaveType ADD CompanyId INT NOT NULL;
ALTER TABLE bodb_HRM.dbo.LeaveType DROP CONSTRAINT PK_LeaveType;
ALTER TABLE bodb_HRM.dbo.LeaveType DROP COLUMN LeaveTypeId;
ALTER TABLE bodb_HRM.dbo.LeaveType ADD LeaveTypeId INT NOT NULL;
ALTER TABLE bodb_HRM.dbo.LeaveType ADD CONSTRAINT PK_LeaveType PRIMARY KEY CLUSTERED (CompanyId, LeaveTypeId);

ALTER TABLE bodb_HRM.dbo.Holiday ADD CompanyId INT NOT NULL;
ALTER TABLE bodb_HRM.dbo.Holiday ADD OldHolidayId INT NOT NULL;

-- ALTER TABLE bodb_HRM.dbo.DisciplineType ADD CompanyId INT;
-- ALTER TABLE bodb_HRM.dbo.DisciplineType ADD OldDisciplineTypeId INT;
-- ALTER TABLE bodb_HRM.dbo.DisciplineType DROP CONSTRAINT PK_DisciplineType;
-- ALTER TABLE bodb_HRM.dbo.DisciplineType DROP COLUMN DisciplineTypeId;
-- ALTER TABLE bodb_HRM.dbo.DisciplineType ADD DisciplineTypeId INT IDENTITY(1,1) PRIMARY KEY;

ALTER TABLE bodb_HRM.dbo.Memo ADD CompanyId INT NOT NULL;
ALTER TABLE bodb_HRM.dbo.Memo ADD OldId INT NOT NULL;

ALTER TABLE bodb_HRM.dbo.SystemConfigs ADD CompanyId INT NOT NULL;

ALTER TABLE bodb_HRM.dbo.[Message] ADD CompanyId INT NOT NULL; -- Temp CompanyId for mapping
ALTER TABLE bodb_HRM.dbo.[Message] ADD OldMessageId INT NOT NULL;


