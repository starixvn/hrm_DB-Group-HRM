BEGIN TRANSACTION;



USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 
SET @CompanyId = 9;

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




INSERT INTO dbo.Employee (
    EmpId, Code, DomainUsername, FullName, NickName, DOB, Email, JobTitleId, 
    Enabled, Phone, Gender, GroupId, Roles, ManagerId, JoinedDate, ConfirmedDate, 
    ResignedDate, Skype, Yahoo, Marriage, LastLogin, CreatedDate, CreatedBy, 
    ModifiedDate, ModifiedBy, isDeleted, PermanentAddress, CurrentAddress, 
    IdCardNumber, PassportNo, PassportExp, Password, ChineseName, PlaceOfbirth, 
    Ethnic, Native, Religion, DateOfIDCard, PlaceOfIDCard, HomePhone, Qualification, 
    Major, PasswordReset, EmployeeCard, PickupRemark, TeamDate, PromotionDate, 
    LetsTalk, JobLevelId, UserId, UC_ModifiedDate, UC_SyncDate, ResignedReason, 
    ExpertGradeId, OldEmpId  -- Keep Old Employee ID
)
OUTPUT INSERTED.EmpId, INSERTED.OldEmpId, @CompanyId INTO @EmployeeMapping  -- Store new & old EmpId
SELECT 
    UserId, Code, DomainUsername, FullName, NickName, DOB, Email, JobTitleId,
    Enabled, Phone, Gender, GroupId, Roles, ManagerId, JoinedDate, ConfirmedDate, 
    ResignedDate, Skype, Yahoo, Marriage, 
    LastLogin,
    CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    CreatedBy, 
    ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    ModifiedBy, 
    isDeleted, PermanentAddress, CurrentAddress, 
    IdCardNumber, PassportNo, PassportExp, Password, ChineseName, PlaceOfbirth, 
    Ethnic, Native, Religion, DateOfIDCard, PlaceOfIDCard, HomePhone, Qualification, 
    Major, PasswordReset, EmployeeCard, PickupRemark, TeamDate, PromotionDate, 
    LetsTalk, JobLevelId, UserId, UC_ModifiedDate, UC_SyncDate, ResignedReason, 
    ExpertGradeId, EmpId AS OldEmpId  -- Keep track of old EmpId
FROM CabintechHRM.dbo.Employee
WHERE UserId is not null

-- Insert into CompanyEmployee using NewEmpId and CompanyId
INSERT INTO dbo.CompanyEmployee (EmpId, CompanyId)
SELECT EmpId, @CompanyId FROM @EmployeeMapping;

UPDATE emp
SET 
    emp.CreatedBy = em_created.EmpId,
    emp.ModifiedBy = em_modified.EmpId,
    emp.ManagerId = em_manager.EmpId
FROM dbo.Employee emp
INNER JOIN dbo.CompanyEmployee ce ON emp.EmpId = ce.EmpId AND ce.CompanyId = @CompanyId
LEFT JOIN @EmployeeMapping em_created ON emp.CreatedBy = em_created.OldEmpId AND em_created.CompanyId = @CompanyId
LEFT JOIN @EmployeeMapping em_modified ON emp.ModifiedBy = em_modified.OldEmpId AND em_modified.CompanyId = @CompanyId
LEFT JOIN @EmployeeMapping em_manager ON emp.ManagerId = em_manager.OldEmpId AND em_manager.CompanyId = @CompanyId;

INSERT INTO dbo.Shift (
    Code, Name, BeginCheckInTime, EndCheckInTime, BeginCheckOutTime, EndCheckOutTime, BreakTimeMins, 
    OrderNo, BeginBreakTime, EndBreakTime, CrossDay, Color, TotalHours, IsInAfterDay, IsOutAfterDay, 
    IsDisabled, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, OWPModifiedDate, OWPSyncDate, 
    CompanyId, OldShiftId
)
SELECT 
    s.Code, 
    s.Name, 
    s.BeginCheckInTime, 
    s.EndCheckInTime, 
    s.BeginCheckOutTime, 
    s.EndCheckOutTime, 
    s.BreakTimeMins, 
    s.OrderNo, 
    s.BeginBreakTime, 
    s.EndBreakTime, 
    s.CrossDay, 
    s.Color, 
    s.TotalHours, 
    s.IsInAfterDay, 
    s.IsOutAfterDay, 
    s.IsDisabled, 
    em_created.EmpId, 
    s.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    em_modified.EmpId, 
    s.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    s.OWPModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    s.OWPSyncDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    @CompanyId, 
    s.ShiftID 
FROM CabintechHRM.dbo.Shift s
LEFT JOIN @EmployeeMapping em_created ON s.CreatedBy = em_created.OldEmpId
LEFT JOIN @EmployeeMapping em_modified ON s.ModifiedBy = em_modified.OldEmpId;    
-- #endregion

-- #region LEAVE TYPE TABLE
INSERT INTO dbo.LeaveType (
    LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction, 
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, 
    OrderNo, Description, CompanyId
)
SELECT LeaveTypeId, Code, Name, IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction, 
    IsHoliday, isShown, IsLeaveDuringWorking, IsCalculateWoking, Color, 
    OrderNo, Description, @CompanyId 
FROM CabintechHRM.dbo.LeaveType;
-- #endregion

-- #region HOLIDAY TABLE
INSERT INTO dbo.Holiday (HolidayName, FromDate, ToDate, TypeId, CompanyId, OldHolidayId)
SELECT HolidayName, FromDate, ToDate, TypeId, @CompanyId, Id 
FROM CabintechHRM.dbo.Holiday;
-- #endregion

-- #region MEMO TABLE
INSERT INTO dbo.Memo (
    RefNo, Contents, Subject, SentTo, SentFrom, ForInfo, TotalPages, 
    SentDate, Category, Type, Enabled, CompanyId, OldId
)
SELECT RefNo, Contents, Subject, SentTo, SentFrom, ForInfo, TotalPages, 
    SentDate, Category, Type, Enabled, @CompanyId, Id 
FROM CabintechHRM.dbo.Memo;
-- #endregion

-- #region SYSTEM CONFIGS TABLE
INSERT INTO dbo.SystemConfigs ([Key], [Value], CompanyId)
SELECT [Key], [Value], @CompanyId 
FROM CabintechHRM.dbo.SystemConfigs;
-- #endregion

-- #region LOOKUP DATA TABLE
INSERT INTO dbo.LookupData (LookupId, Code, Name, Value, CompanyId, OldId)
SELECT 
	ld.LookupId,
    ld.Code, 
    ld.Name, 
    ld.Value, 
    @CompanyId,
    ld.Id AS OldId 
FROM CabintechHRM.dbo.LookupData ld;

UPDATE emp
SET emp.JobTitleId = ld.Id
FROM dbo.Employee emp
INNER JOIN dbo.CompanyEmployee ce ON emp.EmpId = ce.EmpId AND ce.CompanyId = @CompanyId
LEFT JOIN dbo.LookupData ld ON emp.JobTitleId = ld.OldId and ld.CompanyId = @CompanyId


--#region NEW STRUCTURE =============================================================================================================
DECLARE @DepartmentTeamTemp TABLE(
	DeptId INT,
    UnitCode VARCHAR(10),
    DepartCode VARCHAR(100),
    DepartName VARCHAR(50),
    TeamName VARCHAR(100)
);
INSERT INTO @DepartmentTeamTemp (UnitCode, DepartCode, DepartName, TeamName)
VALUES
('HH','ADM','ADM','ADM - PP'),
('HH','ADM','ADM','Admin'),
('HH','ADM','ADM','Admin - SHV'),
('HH','ADM','ADM','Driver'),
('HH','HM66','HRA CBT','HR'),
('HH','HM66','HRA CBT','HR Local - PP'),
('IH','IH11','ITNS CBT','Technical Support'),
('MW','MW11','Marketing','Marketing Team'),
('NV','NV99','B&D','Business&Development'),
('NV','NV28','Core Team','Core Team - NV'),
('NV','NV36','CRM','CRM'),
('NV','NV66','CSD','CSD-NV-IDR'),
('NV','NV66','CSD','CSD-NV-MYR'),
('NV','NV66','CSD','CSD-NV-THB'),
('NV','NV66','CSD','CSD-NV-VND'),
('NV','NV69','Marketing','Affiliate Team'),
('NV','NV69','Marketing','Marketing - NV'),
('NV','NV38','PMO','PMO - NV'),
('NV','NV06','Product & Risk','Product & Data'),
('NV','NV06','Product & Risk','Risk Compliance'),
('OT','OT66','CSD','CSD'),
('OT','OT66','CSD','CSD - OT - CT'),
('OT','OT66','CSD','CSD-OT-BDT'),
('OT','OT66','CSD','CSD-OT-CRM'),
('OT','OT66','CSD','CSD-OT-CSS'),
('OT','OT66','CSD','CSD-OT-INR'),
('OT','OT66','CSD','CSD-OT-KRW'),
('OT','OT66','CSD','CSD-OT-MYR'),
('OT','OT66','CSD','CSD-OT-RMB'),
('OT','OT66','CSD','CSD-OT-THB'),
('OT','OT66','CSD','CSD-OT-VND'),
('OT','Marketing','Marketing','Marketing - OT'),
('OT','OT69','PMO','PMO - OT'),
('OT','Risk','Risk','Risk - OT'),
('OTHER','Other','Other','Special User'),
('OTHER','Management','Management','Management'),
('SS','SS98','Operation','I.O (Bo)'),
('SS','SS98','Operation','I.O (Emily)'),
('SS','SS98','Operation','Internal Operation'),
('SS','SS98','Operation','Payment OPS CT'),
('SS','SS88','Payment CT','Payment CT'),
('SS','SS38','Resource Provider','R.M.R'),
('SS','SS38','Resource Provider','RP CT'),
('SS','SS38','Resource Provider','S.A.A');
DECLARE @maxDeptId INT = ISNULL((SELECT MAX(GroupDeptId) FROM dbo.Department), 0);
WITH DistinctDepartments AS (
    SELECT DISTINCT
        d.DepartCode,
        d.DepartName,
        u.UnitId,
        d.DepartName AS AccountableArea
    FROM @DepartmentTeamTemp d
    LEFT JOIN dbo.Unit u WITH(NOLOCK) ON d.UnitCode = u.Code
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.Department dep
        WHERE dep.Code = d.DepartCode
    )
)
INSERT INTO dbo.Department (Code, Name, UnitId, ModifiedDate, GroupDeptId, AccountableArea, IsDeleted, IsActive)
SELECT DISTINCT
	d.DepartName,
	d.DepartName,
	d.UnitId,
	GETDATE(),
	ROW_NUMBER() OVER (ORDER BY (SELECT 1)) + @maxDeptId,
	d.DepartName,
	0,
	0
FROM DistinctDepartments d;

-- Team
DECLARE @maxGroupId INT = ISNULL((SELECT MAX(GroupTeamId) FROM dbo.[Group]), 0);
INSERT INTO dbo.[Group] (
    Code, Name, Rank, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, IsDeleted, MailGroup,
    LocalBasicAnnualLeaveBalance, LocalWorkingDays, LocalWorkingHours, LocalOffDaysbyWeek,
    ExpatBasicAnnualLeaveBalance, ExpatWorkingDays, ExpatWorkingHours, ExpatOffDaysbyWeek,
    LocalWorkingHoursbyWeek, ExpatWorkingHoursbyWeek, CompanyId, OldGroupId, 
	DepartmentId, AccountableArea, GroupTeamId, PICEmpId
)
SELECT 
    g.Code, 
    g.Name, 
    g.Rank, 
    GETDATE(), 
    NULL, 
    NULL, 
    NULL, 
    g.IsDeleted, 
    g.MailGroup,
    g.LocalBasicAnnualLeaveBalance, 
    g.LocalWorkingDays, 
    g.LocalWorkingHours, 
    g.LocalOffDaysbyWeek,
    g.ExpatBasicAnnualLeaveBalance, 
    g.ExpatWorkingDays, 
    g.ExpatWorkingHours, 
    g.ExpatOffDaysbyWeek,
    g.LocalWorkingHoursbyWeek, 
    g.ExpatWorkingHoursbyWeek, 
    @CompanyId, 
    g.GroupId,
	dept.DepartmentId,
	g.Name,
	ROW_NUMBER() OVER (ORDER BY (SELECT 1)) + @maxGroupId,
	em.EmpId
FROM CabintechHRM.dbo.[Group] g
INNER JOIN @DepartmentTeamTemp d ON g.Code = d.TeamName
INNER JOIN dbo.Department dept WITH (NOLOCK) ON dept.Code = d.DepartCode
OUTER APPLY (
    SELECT TOP 1 mng.*
    FROM CabintechHRM.dbo.GroupManager mng WITH (NOLOCK)
    WHERE mng.GroupId = g.GroupId AND mng.RoleId = 3
) AS mng
LEFT JOIN @EmployeeMapping AS em ON mng.EmpID = em.OldEmpId

-- Map Employee to new GroupId
DECLARE @EmpNewInfo TABLE(
	UserId INT,
	TeamCode VARCHAR(100),
	CtrlId INT
)
INSERT INTO @EmpNewInfo(UserId, TeamCode, CtrlId) VALUES
(4878,'HR',NULL),
(5103,'Technical Support',2139),
(4652,'Special User',NULL),
(4653,'Special User',NULL),
(4654,'Special User',NULL),
(4655,'Special User',NULL),
(4349,'Special User',NULL),
(4352,'Special User',NULL),
(4462,'Special User',NULL),
(4526,'Special User',NULL),
(4527,'Special User',NULL),
(4528,'Special User',NULL),
(4651,'Special User',NULL),
(5229,'Special User',NULL),
(5270,'Special User',NULL),
(5302,'Special User',NULL),
(4436,'Admin',NULL),
(4601,'Admin',NULL),
(4213,'CSD',NULL),
(4214,'CSD',NULL),
(4221,'CSD',NULL),
(4222,'CSD',NULL),
(4225,'CSD',NULL),
(4226,'CSD',NULL),
(4233,'CSD',NULL),
(4251,'CSD',NULL),
(4258,'CSD',NULL),
(4274,'CSD',NULL),
(4303,'CSD',NULL),
(4307,'CSD',NULL),
(4308,'CSD',NULL),
(4317,'CSD',NULL),
(4321,'CSD',NULL),
(4324,'CSD',NULL),
(4325,'CSD',NULL),
(4262,'Management',272),
(4333,'Management',273),
(4212,'Marketing Team',NULL),
(4215,'Marketing Team',1989),
(4227,'Marketing Team',1990),
(4242,'Marketing Team',2037),
(4249,'Marketing Team',NULL),
(4252,'Marketing Team',1468),
(4269,'Marketing Team',NULL),
(4278,'Marketing Team',786),
(4287,'Marketing Team',NULL),
(4291,'Marketing Team',1593),
(4309,'Marketing Team',1727),
(4319,'Marketing Team',1631),
(4322,'Marketing Team',855),
(4323,'Marketing Team',1991),
(4331,'Marketing Team',787),
(4334,'Marketing Team',1571),
(4336,'Marketing Team',1992),
(4444,'Marketing Team',1505),
(4446,'Marketing Team',2036),
(5107,'Marketing Team',1721),
(4266,'PMO - OT',1124),
(4327,'PMO - OT',816),
(4217,'Risk - OT',1686),
(4234,'Risk - OT',1413),
(4240,'Risk - OT',374),
(4279,'Risk - OT',1411),
(4301,'Risk - OT',1988),
(4329,'Risk - OT',992),
(4423,'Risk - OT',2094),
(4424,'Risk - OT',NULL),
(4427,'Risk - OT',2090),
(4467,'Risk - OT',NULL),
(4469,'Risk - OT',NULL),
(4470,'Risk - OT',NULL),
(4603,'Risk - OT',2092),
(4656,'Risk - OT',NULL),
(4679,'Risk - OT',2089),
(4697,'Risk - OT',2093),
(4698,'Risk - OT',2091),
(5237,'Risk - OT',2095),
(5238,'Risk - OT',2096),
(5239,'Risk - OT',NULL),
(5240,'Risk - OT',NULL),
(5256,'Risk - OT',2097),
(4276,'S.A.A',NULL),
(4306,'S.A.A',568),
(4426,'S.A.A',NULL),
(4428,'S.A.A',NULL),
(4429,'S.A.A',NULL),
(4438,'S.A.A',NULL),
(4453,'S.A.A',NULL),
(4456,'S.A.A',NULL),
(4457,'S.A.A',NULL),
(4458,'S.A.A',NULL),
(4461,'S.A.A',NULL),
(4684,'S.A.A',NULL),
(4685,'S.A.A',NULL),
(4686,'S.A.A',NULL),
(4687,'S.A.A',NULL),
(4699,'S.A.A',NULL),
(4700,'S.A.A',NULL),
(4701,'S.A.A',NULL),
(4753,'S.A.A',NULL),
(5133,'S.A.A',NULL),
(5134,'S.A.A',NULL),
(5135,'S.A.A',NULL),
(5136,'S.A.A',NULL),
(5137,'S.A.A',NULL),
(5138,'S.A.A',NULL),
(5230,'S.A.A',2234),
(5252,'S.A.A',2235),
(5253,'S.A.A',2236),
(5254,'S.A.A',2237),
(5255,'S.A.A',2238),
(4376,'Internal Operation',NULL),
(4378,'Internal Operation',NULL),
(4388,'Internal Operation',2146),
(4420,'Internal Operation',NULL),
(4422,'Internal Operation',2101),
(4425,'Internal Operation',2155),
(4435,'Internal Operation',NULL),
(4440,'Internal Operation',2184),
(4441,'Internal Operation',2157),
(4447,'Internal Operation',2159),
(4459,'Internal Operation',2185),
(4658,'Internal Operation',2170),
(4688,'Internal Operation',2104),
(4694,'Internal Operation',NULL),
(4829,'Internal Operation',NULL),
(4847,'Internal Operation',NULL),
(4863,'Internal Operation',NULL),
(5222,'Internal Operation',2174),
(5224,'Internal Operation',2176),
(4375,'Risk Compliance',2040),
(4389,'Risk Compliance',2042),
(4437,'Risk Compliance',NULL),
(4442,'Risk Compliance',NULL),
(4443,'Risk Compliance',NULL),
(4452,'Risk Compliance',NULL),
(4524,'Risk Compliance',2118),
(4691,'Risk Compliance',NULL),
(4692,'Risk Compliance',2046),
(4695,'Risk Compliance',NULL),
(4696,'Risk Compliance',NULL),
(4752,'Risk Compliance',2048),
(4831,'Risk Compliance',NULL),
(4839,'Risk Compliance',NULL),
(4859,'Risk Compliance',NULL),
(4877,'Risk Compliance',NULL),
(4879,'Risk Compliance',NULL),
(5236,'Risk Compliance',2049),
(4380,'Driver',NULL),
(4381,'Driver',NULL),
(4382,'Driver',2123),
(4383,'Driver',2124),
(4384,'Driver',2125),
(4385,'Driver',NULL),
(4386,'Driver',NULL),
(4387,'Driver',2120),
(4434,'Driver',2121),
(4445,'HR Local - PP',NULL),
(4392,'Product & Data',2043),
(4417,'Product & Data',2041),
(4449,'Product & Data',NULL),
(4450,'Product & Data',NULL),
(4693,'Product & Data',2047),
(5234,'Product & Data',2051),
(5235,'Product & Data',2050),
(5263,'Product & Data',NULL),
(4268,'I.O (Bo)',339),
(4295,'I.O (Bo)',841),
(4360,'I.O (Bo)',2141),
(4377,'I.O (Bo)',2110),
(4418,'I.O (Bo)',2179),
(4439,'I.O (Bo)',2183),
(4460,'I.O (Bo)',2186),
(4468,'I.O (Bo)',2167),
(4525,'I.O (Bo)',2168),
(4659,'I.O (Bo)',2171),
(4823,'I.O (Bo)',NULL),
(4857,'I.O (Bo)',NULL),
(5223,'I.O (Bo)',2175),
(5225,'I.O (Bo)',2177),
(4260,'I.O (Emily)',936),
(4379,'I.O (Emily)',2102),
(4390,'I.O (Emily)',2178),
(4391,'I.O (Emily)',2108),
(4419,'I.O (Emily)',2180),
(4421,'I.O (Emily)',2151),
(4430,'I.O (Emily)',2181),
(4431,'I.O (Emily)',2182),
(4455,'I.O (Emily)',2143),
(4463,'I.O (Emily)',2166),
(4657,'I.O (Emily)',2169),
(4843,'I.O (Emily)',NULL),
(4864,'I.O (Emily)',NULL),
(4869,'I.O (Emily)',NULL),
(5102,'I.O (Emily)',2172),
(5146,'I.O (Emily)',2173),
(4850,'Business&Development',NULL),
(4855,'Business&Development',NULL),
(4358,'Marketing - NV',NULL),
(4359,'Marketing - NV',NULL),
(4374,'Marketing - NV',2054),
(4824,'Marketing - NV',NULL),
(4842,'Marketing - NV',NULL),
(4858,'Marketing - NV',NULL),
(4867,'Marketing - NV',NULL),
(4868,'Marketing - NV',NULL),
(4873,'Marketing - NV',NULL),
(4822,'CRM',NULL),
(4825,'CRM',NULL),
(4849,'CRM',NULL),
(4852,'CRM',NULL),
(4870,'CRM',NULL),
(4872,'CRM',NULL),
(4355,'Core Team - NV',NULL),
(4356,'Core Team - NV',NULL),
(4866,'Core Team - NV',NULL),
(4821,'CSD-NV-MYR',NULL),
(4826,'CSD-NV-MYR',NULL),
(4835,'CSD-NV-MYR',NULL),
(4836,'CSD-NV-MYR',NULL),
(5121,'CSD-NV-MYR',NULL),
(4834,'CSD-NV-THB',NULL),
(4838,'CSD-NV-THB',NULL),
(4851,'CSD-NV-THB',NULL),
(4856,'CSD-NV-THB',NULL),
(4860,'CSD-NV-THB',NULL),
(4865,'CSD-NV-THB',NULL),
(4876,'CSD-NV-THB',NULL),
(4827,'CSD-NV-VND',NULL),
(4832,'CSD-NV-VND',NULL),
(4833,'CSD-NV-VND',NULL),
(4837,'CSD-NV-VND',NULL),
(4844,'CSD-NV-VND',NULL),
(4845,'CSD-NV-VND',NULL),
(4846,'CSD-NV-VND',NULL),
(4848,'CSD-NV-VND',NULL),
(4853,'CSD-NV-VND',NULL),
(4862,'CSD-NV-VND',NULL),
(4871,'CSD-NV-VND',NULL),
(4874,'CSD-NV-VND',NULL),
(4875,'CSD-NV-VND',NULL),
(5108,'CSD-NV-VND',NULL),
(4819,'CSD-NV-IDR',NULL),
(4820,'CSD-NV-IDR',NULL),
(4840,'CSD-NV-IDR',NULL),
(4841,'CSD-NV-IDR',NULL),
(4854,'CSD-NV-IDR',NULL),
(4216,'CSD-OT-CSS',809),
(4231,'CSD-OT-CSS',944),
(4238,'CSD-OT-CSS',919),
(4254,'CSD-OT-CSS',616),
(4264,'CSD-OT-CSS',258),
(4271,'CSD-OT-CSS',874),
(4289,'CSD-OT-CSS',627),
(4294,'CSD-OT-CSS',702),
(4300,'CSD-OT-CSS',1014),
(4318,'CSD-OT-CSS',547),
(4335,'CSD-OT-CSS',879),
(4220,'CSD-OT-RMB',1500),
(4223,'CSD-OT-RMB',1484),
(4236,'CSD-OT-RMB',1517),
(4257,'CSD-OT-RMB',1432),
(4261,'CSD-OT-RMB',1051),
(4267,'CSD-OT-RMB',1404),
(4338,'CSD-OT-RMB',738),
(5243,'CSD-OT-RMB',NULL),
(4229,'CSD-OT-MYR',1028),
(4230,'CSD-OT-MYR',608),
(4232,'CSD-OT-MYR',1511),
(4243,'CSD-OT-MYR',943),
(4265,'CSD-OT-MYR',934),
(4304,'CSD-OT-MYR',1415),
(4313,'CSD-OT-MYR',1499),
(4332,'CSD-OT-MYR',1658),
(5242,'CSD-OT-MYR',NULL),
(4244,'CSD-OT-THB',1497),
(4248,'CSD-OT-THB',954),
(4281,'CSD-OT-THB',1379),
(4282,'CSD-OT-THB',839),
(4283,'CSD-OT-THB',1583),
(4293,'CSD-OT-THB',1718),
(4305,'CSD-OT-THB',703),
(4310,'CSD-OT-THB',980),
(4311,'CSD-OT-THB',1383),
(4312,'CSD-OT-THB',710),
(4314,'CSD-OT-THB',1376),
(4320,'CSD-OT-THB',504),
(4218,'CSD-OT-VND',1338),
(4237,'CSD-OT-VND',1649),
(4253,'CSD-OT-VND',873),
(4255,'CSD-OT-VND',1611),
(4256,'CSD-OT-VND',1529),
(4272,'CSD-OT-VND',NULL),
(4273,'CSD-OT-VND',1467),
(4275,'CSD-OT-VND',1327),
(4285,'CSD-OT-VND',965),
(4286,'CSD-OT-VND',990),
(4288,'CSD-OT-VND',1566),
(4296,'CSD-OT-VND',NULL),
(4316,'CSD-OT-VND',1414),
(4326,'CSD-OT-VND',1452),
(5117,'CSD-OT-VND',NULL),
(5118,'CSD-OT-VND',NULL),
(4239,'CSD-OT-INR',1211),
(4241,'CSD-OT-INR',1531),
(4250,'CSD-OT-INR',1617),
(4277,'CSD-OT-INR',1035),
(4290,'CSD-OT-INR',1530),
(4297,'CSD-OT-INR',1615),
(4299,'CSD-OT-INR',1023),
(4330,'CSD-OT-INR',972),
(4466,'CSD-OT-INR',NULL),
(5112,'CSD-OT-INR',NULL),
(5120,'CSD-OT-INR',NULL),
(5241,'CSD-OT-INR',NULL),
(4235,'CSD-OT-BDT',1604),
(4247,'CSD-OT-BDT',1665),
(4302,'CSD-OT-BDT',1616),
(4219,'CSD-OT-CRM',580),
(4228,'CSD-OT-CRM',NULL),
(4245,'CSD-OT-CRM',1117),
(4263,'CSD-OT-CRM',398),
(4270,'CSD-OT-CRM',1339),
(4280,'CSD-OT-CRM',1512),
(4284,'CSD-OT-CRM',1400),
(4292,'CSD-OT-CRM',1664),
(5104,'Marketing - OT',NULL),
(5105,'Marketing - OT',NULL),
(5106,'Marketing - OT',NULL),
(5264,'Marketing - OT',NULL),
(5265,'Marketing - OT',NULL),
(5266,'Marketing - OT',NULL),
(5267,'Marketing - OT',NULL),
(5268,'Marketing - OT',NULL),
(4353,'Admin - SHV',NULL),
(4354,'Admin - SHV',2119),
(4337,'CSD-OT-KRW',NULL),
(5116,'ADM - PP',2122),
(5259,'ADM - PP',2131),
(4828,'PMO - NV',NULL),
(4830,'Affiliate Team',NULL),
(4880,'Affiliate Team',NULL),
(4224,'CSD - OT - CT',792),
(4246,'CSD - OT - CT',399),
(4298,'CSD - OT - CT',658),
(4328,'CSD - OT - CT',791),
(4454,'R.M.R',NULL),
(4861,'R.M.R',NULL),
(4315,'RP CT',354),
(4259,'Payment CT',373),
(4357,'Payment CT',NULL),
(4451,'Payment OPS CT',NULL);

UPDATE e
SET e.CtrId = en.CtrlId,
	e.GroupId = g.GroupId
FROM Employee e WITH(ROWLOCK)
LEFT JOIN @EmpNewInfo en ON en.UserId = e.EmpId
LEFT JOIN dbo.[Group] g ON g.Code = en.TeamCode
--#endregion =============================================================================================================


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
	FROM CabintechHRM.dbo.WorkingTimeRequest AS wr  WITH (NOLOCK)
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
	FROM CabintechHRM.dbo.WorkingTimeRequestHistory as wrh  WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wr WITH (NOLOCK) ON wrh.RequestId = wr.OldRequestId AND wr.CompanyId = @CompanyId  --some requestId not exists in WR
	INNER JOIN @EmployeeMapping AS emp ON wrh.EmpId = emp.OldEmpId
	LEFT JOIN @EmployeeMapping AS empVerify ON wrh.VerifierId = empVerify.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empApprove  ON wrh.ApproverId = empApprove.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empHr  ON wrh.HRId = empHr.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empCreated ON wrh.CreatedBy = empCreated.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified  ON wrh.ModifiedBy = empModified.OldEmpId;


      INSERT INTO dbo.tmpSickLeaveBalance (EmpId, RequestId, TotalDays, [Month], [Year], [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.[Month], tmp.[Year], tmp.[Status]
FROM CabintechHRM.dbo.tmpSickLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.tmpSickLeaveBalance AS tmpsb WITH (NOLOCK)
        WHERE e.EmpId = tmpsb.EmpId
            AND rq.RequestId = tmpsb.RequestId
    )

INSERT INTO dbo.tmpLeaveBalance (EmpId, RequestId, TotalDays, InYear, InMonth, [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.InYear, tmp.InMonth, tmp.[Status]
FROM CabintechHRM.dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.tmpLeaveBalance AS tmplb WITH (NOLOCK)
        WHERE e.EmpId = tmplb.EmpId
            AND rq.RequestId = tmplb.RequestId
    )

INSERT INTO dbo.tmpKIVLeaveBalance (EmpId, RequestId, TotalDays, InYear, [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.InYear, tmp.[Status]
FROM CabintechHRM.dbo.tmpKIVLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.tmpKIVLeaveBalance AS tmpkb WITH (NOLOCK)
        WHERE e.EmpId = tmpkb.EmpId
            AND rq.RequestId = tmpkb.RequestId
    )

INSERT INTO dbo.tmpHospitalizationLeaveBalance (EmpId, RequestId, TotalDays, [Month], [Year], [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.[Month], tmp.[Year], tmp.[Status]
FROM CabintechHRM.dbo.tmpHospitalizationLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.tmpHospitalizationLeaveBalance AS tmphb WITH (NOLOCK)
        WHERE e.EmpId = tmphb.EmpId
            AND rq.RequestId = tmphb.RequestId
    )

INSERT INTO dbo.tmpEmployeeCalendar(EmpId, WorkDate, RequestId, RequestTypeId, ShiftId, IsOffDay, IsHoliday, IsOvertime, IsKeepInView,
    IsLeaveDay, IsLeaveOffDay, LeaveDay, LeaveTypeId, FromTime, ToTime, LeaveTypeId2, FromTime2, ToTime2, ChangeShiftTypeId, MoveOffFromDate, MoveOffToDate, ModifiedDate)
SELECT e.EmpId, tmp.WorkDate, rq.RequestId, tmp.RequestTypeId, s.ShiftId, tmp.IsOffDay, tmp.IsHoliday, tmp.IsOvertime, tmp.IsKeepInView,
    tmp.IsLeaveDay, tmp.IsLeaveOffDay, tmp.LeaveDay, tmp.LeaveTypeId,
    tmp.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    tmp.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    tmp.LeaveTypeId2,
    tmp.FromTime2 AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    tmp.ToTime2 AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    tmp.ChangeShiftTypeId, tmp.MoveOffFromDate, tmp.MoveOffToDate,
    tmp.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM CabintechHRM.dbo.tmpEmployeeCalendar AS tmp WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    LEFT JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON tmp.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId
WHERE ce.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.tmpEmployeeCalendar AS tmpempca WITH (NOLOCK)
        WHERE e.EmpId = tmpempca.EmpId
            AND tmp.WorkDate = tmpempca.WorkDate
    )

INSERT INTO dbo.tmpEmployeeAttendace(EmpId, WorkDate, InsertedDate)
SELECT e.EmpId, tmp.WorkDate, tmp.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM CabintechHRM.dbo.tmpEmployeeAttendace AS tmp WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE ce.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.tmpEmployeeAttendace AS tmpatt WITH (NOLOCK)
        WHERE e.EmpId = tmpatt.EmpId
            AND tmp.WorkDate = tmpatt.WorkDate
    )

INSERT INTO dbo.TimeRecord(EmpId, RecordTime, InOutType, InsertDate, ModifiedBy, ModifiedDate, CompanyId, OldId)
SELECT e.EmpId, tc.RecordTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, tc.InOutType,
    tc.InsertDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, NULL, NULL, @CompanyId, tc.Id
FROM CabintechHRM.dbo.TimeRecord AS tc WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tc.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE ce.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.TimeRecord AS t WITH (NOLOCK)
        WHERE t.CompanyId = @CompanyId
            AND t.OldId = tc.Id
    )

INSERT INTO dbo.TimeRecordExt(Id, IPAddress, [Platform])
SELECT tc.Id, ext.IPAddress, ext.[Platform]
FROM CabintechHRM.dbo.TimeRecordExt AS ext WITH (NOLOCK)
    INNER JOIN dbo.TimeRecord AS tc WITH (NOLOCK) ON ext.Id = tc.OldId
WHERE tc.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.TimeRecordExt AS tc_ext WITH (NOLOCK)
        WHERE tc.Id = tc_ext.Id
    )

INSERT INTO dbo.SickLeaveTrans(EmpId, RequestId, [Description], FromDate, ToDate, DeductDays, CreditDays, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
SELECT e.EmpId, rq.RequestId, st.[Description], st.FromDate, st.ToDate, st.DeductDays, st.CreditDays, st.IsDeleted, cr.EmpId,
    st.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    md.EmpId, st.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM CabintechHRM.dbo.SickLeaveTrans AS st WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON st.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    LEFT JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON st.RequestId = rq.OldRequestId
    LEFT JOIN dbo.Employee AS cr WITH (NOLOCK) ON st.CreatedBy = cr.OldEmpId
    LEFT JOIN dbo.CompanyEmployee AS cr_ce WITH (NOLOCK) ON cr.EmpId = cr_ce.EmpId
    AND cr_ce.CompanyId = @CompanyId
    LEFT JOIN dbo.Employee AS md WITH (NOLOCK) ON st.ModifiedBy = md.OldEmpId
    LEFT JOIN dbo.CompanyEmployee AS md_ce WITH (NOLOCK) ON md.EmpId = md_ce.EmpId
    AND md_ce.CompanyId = @CompanyId
WHERE ce.CompanyId = @CompanyId
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.SickLeaveTrans AS sicktrans WITH (NOLOCK)
        WHERE e.EmpId = sicktrans.EmpId
            AND rq.RequestId = sicktrans.RequestId
    )

INSERT INTO dbo.RoleFunction(CompanyId, RoleId, FunctionId, IsRead, IsHost)
SELECT @CompanyId, RoleId, FunctionId, IsRead, IsHost
FROM CabintechHRM.dbo.RoleFunction AS rf WITH (NOLOCK)
WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.RoleFunction AS nrf WITH (NOLOCK)
        WHERE nrf.CompanyId = @CompanyId
            AND rf.RoleId = nrf.RoleId
            AND rf.FunctionId = nrf.FunctionId
    )


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
	FROM CabintechHRM.dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
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
	FROM CabintechHRM.dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK)
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
	FROM CabintechHRM.dbo.ChangeShiftRequestDetailHistory AS csdh WITH (NOLOCK)
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
	FROM CabintechHRM.dbo.ChangeShiftRequestHistory AS csh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON csh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON csh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON csh.EmpId = emp.OldEmpId


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
           ,cio.RequestTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone --Actual Request time
           ,cio.ReasonId
           ,cio.RefNo
	FROM CabintechHRM.dbo.CheckInOutRequest AS cio WITH (NOLOCK)
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
           ,cioh.RequestTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,cioh.ReasonId
           ,cioh.RefNo
           ,wkrh.HistoryId
	FROM CabintechHRM.dbo.CheckInOutRequestHistory AS cioh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON cioh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON cioh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON cioh.EmpId = emp.OldEmpId

-- #region DISCIPLINE TABLE
INSERT INTO dbo.Discipline (
    EmpId, WorkDate, DisciplineScore, IsOutOfControlReason, EmployeeComment, ApproverComment, 
    IsMissingCheckInOut, IsLateIn, IsEarlyOut, IsWorkingUnderTime, IsChangeShift, IsAbsent, 
    IsUnpaidLeave, IsUnpaidLeaveAbsent, IsUnplannedLeave, IsWeekendLeave, IsDeleted, 
    ModifiedBy, ModifiedDate, IsSevenDaysLeave
)
SELECT 
    em.EmpId, 
    d.WorkDate, 
    d.DisciplineScore, 
    d.IsOutOfControlReason, 
    d.EmployeeComment, 
    d.ApproverComment, 
    d.IsMissingCheckInOut, 
    d.IsLateIn, 
    d.IsEarlyOut, 
    d.IsWorkingUnderTime, 
    d.IsChangeShift, 
    d.IsAbsent, 
    d.IsUnpaidLeave, 
    d.IsUnpaidLeaveAbsent, 
    d.IsUnplannedLeave, 
    d.IsWeekendLeave, 
    d.IsDeleted, 
    em_modified.EmpId, 
    d.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    d.IsSevenDaysLeave
FROM CabintechHRM.dbo.Discipline d
LEFT JOIN @EmployeeMapping em ON d.EmpId = em.OldEmpId
LEFT JOIN @EmployeeMapping em_modified ON d.ModifiedBy = em_modified.OldEmpId
WHERE d.IsDeleted != 1 and em.EmpId IS NOT NULL;
-- #endregion

-- #region DISCIPLINE GROUP RULE TABLE
INSERT INTO dbo.DisciplineGroupRule (
    GroupId, DisciplineTypeId, IsLocal, Value
)
SELECT 
    g.GroupId, 
    dgr.DisciplineTypeId, 
    dgr.IsLocal, 
    dgr.Value
FROM CabintechHRM.dbo.DisciplineGroupRule dgr
LEFT JOIN dbo.[Group] g ON dgr.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId;

-- #endregion

-- #region DISCIPLINE IGNORE TABLE
INSERT INTO dbo.DisciplineIgnore (
    EmpId, WorkDate, IsIgnoredMissingCheckInOut, IsIgnoredLateIn, IsIgnoredEarlyOut, 
    IsIgnoredWorkingUnderTime, IsIgnoredChangeShift, IsIgnoredAbsent, 
    IsIgnoredUnpaidLeave, IsIgnoredUnpaidLeaveAbsent, IsIgnoredUnplannedLeave, 
    IsIgnoredWeekendLeave, IsIgnoredSevenDaysLeave
)
SELECT 
    em.EmpId, 
    di.WorkDate, 
    di.IsIgnoredMissingCheckInOut, 
    di.IsIgnoredLateIn, 
    di.IsIgnoredEarlyOut, 
    di.IsIgnoredWorkingUnderTime, 
    di.IsIgnoredChangeShift, 
    di.IsIgnoredAbsent, 
    di.IsIgnoredUnpaidLeave, 
    di.IsIgnoredUnpaidLeaveAbsent, 
    di.IsIgnoredUnplannedLeave, 
    di.IsIgnoredWeekendLeave, 
    di.IsIgnoredSevenDaysLeave
FROM CabintechHRM.dbo.DisciplineIgnore di
LEFT JOIN @EmployeeMapping em ON di.EmpId = em.OldEmpId
WHERE em.EmpId IS NOT NULL;

-- #endregion

-- #region DISCIPLINE IGNORE DETAIL TABLE
INSERT INTO dbo.DisciplineIgnoreDetail (
    WorkDate, EmpId, DisciplineTypeId, IgnoreBy, IgnoreDate
)
SELECT 
    di.WorkDate, 
    em.EmpId, 
    di.DisciplineTypeId, 
    em_ignore.EmpId, 
    di.IgnoreDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM CabintechHRM.dbo.DisciplineIgnoreDetail di
LEFT JOIN @EmployeeMapping em ON di.EmpId = em.OldEmpId
LEFT JOIN @EmployeeMapping em_ignore ON di.IgnoreBy = em_ignore.OldEmpId
WHERE em.EmpId IS NOT NULL AND em_ignore.EmpId IS NOT NULL;

-- #endregion

-- #region DISCIPLINE OUT OF CONTROL TABLE
INSERT INTO dbo.DisciplineOutOfControl (
    EmpId, WorkDate, IsOutOfControlMissingCheckInOut, IsOutOfControlLateIn, 
    IsOutOfControlEarlyOut, IsOutOfControlWorkingUnderTime, IsOutOfControlChangeShift, 
    IsOutOfControlAbsent, IsOutOfControlUnpaidLeave, IsOutOfControlUnpaidLeaveAbsent, 
    IsOutOfControlUnplannedLeave, IsOutOfControlWeekendLeave, IsOutOfControlSevenDaysLeave
)
SELECT 
    em.EmpId, 
    doc.WorkDate, 
    doc.IsOutOfControlMissingCheckInOut, 
    doc.IsOutOfControlLateIn, 
    doc.IsOutOfControlEarlyOut, 
    doc.IsOutOfControlWorkingUnderTime, 
    doc.IsOutOfControlChangeShift, 
    doc.IsOutOfControlAbsent, 
    doc.IsOutOfControlUnpaidLeave, 
    doc.IsOutOfControlUnpaidLeaveAbsent, 
    doc.IsOutOfControlUnplannedLeave, 
    doc.IsOutOfControlWeekendLeave, 
    doc.IsOutOfControlSevenDaysLeave
FROM CabintechHRM.dbo.DisciplineOutOfControl doc
LEFT JOIN @EmployeeMapping em ON doc.EmpId = em.OldEmpId
WHERE em.EmpId IS NOT NULL;

-- #endregion

-- #region DISCIPLINE REQUEST TRANS TABLE

INSERT INTO dbo.DisciplineRequestTrans (
    EmpId, WorkDate, RequestId, DisciplineTypeId, IsIgnored, 
    IsOutOfControl, ModifiedDate, ModifiedBy
)
SELECT 
    em.EmpId, 
    drt.WorkDate, 
    drt.RequestId, 
    drt.DisciplineTypeId, 
    drt.IsIgnored, 
    drt.IsOutOfControl, 
    drt.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    em_modified.EmpId
FROM CabintechHRM.dbo.DisciplineRequestTrans drt
LEFT JOIN @EmployeeMapping em ON drt.EmpId = em.OldEmpId
LEFT JOIN @EmployeeMapping em_modified ON drt.ModifiedBy = em_modified.OldEmpId
WHERE em.EmpId IS NOT NULL;

-- #endregion

INSERT INTO dbo.OtherDiscipline
           (EmpId
           ,WorkDate
           ,DisciplineTypeId
           ,Score
           ,Comment
           ,IsDeleted
           ,ModifiedBy
           ,ModifiedDate)
     SELECT
           em.EmpId
           ,od.WorkDate
           ,od.DisciplineTypeId
           ,od.Score
           ,od.Comment
           ,od.IsDeleted
           ,em_modified.EmpId
           ,od.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone 
	FROM CabintechHRM.dbo.OtherDiscipline od
	LEFT JOIN @EmployeeMapping em ON od.EmpId = em.OldEmpId
	LEFT JOIN @EmployeeMapping em_modified ON od.ModifiedBy = em_modified.OldEmpId;

-- #region EMPLOYEE ATTENDANCE TABLE
INSERT INTO dbo.EmployeeAttendance (
    AttendanceDate, EmpId, ShiftId, InFixed, OutFixed, 
    ExpectedInTime, ExpectedOutTime, LateIn, EarlyOut, 
    LeaveTypeId, Absence, Notes, TotalWorkHours, 
    IsRightShift, IsLocked, LeaveDay, InsertDate, LeaveTypeId2
)
SELECT 
    ea.AttendanceDate, 
    em.EmpId, 
    s_new.ShiftId, 
    ea.InFixed AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ea.OutFixed AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ea.ExpectedInTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ea.ExpectedOutTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ea.LateIn, 
    ea.EarlyOut, 
    ea.LeaveTypeId, 
    ea.Absence, 
    ea.Notes, 
    ea.TotalWorkHours, 
    ea.IsRightShift, 
    ea.IsLocked, 
    ea.LeaveDay, 
    ea.InsertDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    ea.LeaveTypeId2
FROM CabintechHRM.dbo.EmployeeAttendance ea
    INNER JOIN @EmployeeMapping em ON ea.EmpId = em.OldEmpId
    LEFT JOIN dbo.Shift s_new ON ea.ShiftId = s_new.OldShiftId AND s_new.CompanyId = @CompanyId
-- #endregion

-- #region EMPLOYEE CALENDAR TABLE
INSERT INTO dbo.EmployeeCalendar (
    WorkDate, EmpId, ShiftId, IsHoliday, IsOffDay, IsLeaveDay, LeaveTypeId, 
    LateIn, EarlyOut, RequestedCheckinTime, RequestedCheckoutTime, ChangeShiftId, 
    LeaveDay, ModifiedDate, ModifiedBy, IsKeepInView, LeaveTypeId2, 
    IsPublic, IsFixedOffDay, OWPModifiedDate, OWPSyncDate
)
SELECT ec.WorkDate, 
    em.EmpId, 
    s.ShiftId, 
    ec.IsHoliday, 
    ec.IsOffDay, 
    ec.IsLeaveDay, 
    ec.LeaveTypeId, 
    ec.LateIn, 
    ec.EarlyOut, 
    ec.RequestedCheckinTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ec.RequestedCheckoutTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    s_cs.ShiftId,
    ec.LeaveDay, 
    ec.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    em_modified.EmpId, 
    ec.IsKeepInView, 
    ec.LeaveTypeId2, 
    ec.IsPublic, 
    ec.IsFixedOffDay, 
    ec.OWPModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,  
    ec.OWPSyncDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM CabintechHRM.dbo.EmployeeCalendar ec
    INNER JOIN @EmployeeMapping em ON ec.EmpId = em.OldEmpId
    LEFT JOIN dbo.Shift s ON ec.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId
    LEFT JOIN dbo.Shift s_cs ON ec.ChangeShiftId = s_cs.OldShiftId AND s_cs.CompanyId = @CompanyId
    LEFT JOIN @EmployeeMapping em_modified ON ec.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE CONTRACT TABLE

INSERT INTO dbo.EmployeeContract (
    EmpID, BankAccount, TaxCode, SocialInsuranceNo, RegisteredHospital, 
    Contract1, FromDate1, ToDate1, Contract2, FromDate2, ToDate2, 
    Contract3, FromDate3, ToDate3, Contract4, FromDate4, ToDate4, 
    Contract5, FromDate5, ToDate5, History
)
SELECT em.EmpId, 
    ec.BankAccount, 
    ec.TaxCode, 
    ec.SocialInsuranceNo, 
    ec.RegisteredHospital, 
    ec.Contract1, 
    ec.FromDate1, 
    ec.ToDate1, 
    ec.Contract2, 
    ec.FromDate2, 
    ec.ToDate2, 
    ec.Contract3, 
    ec.FromDate3, 
    ec.ToDate3, 
    ec.Contract4, 
    ec.FromDate4, 
    ec.ToDate4, 
    ec.Contract5, 
    ec.FromDate5, 
    ec.ToDate5, 
    ec.History
FROM CabintechHRM.dbo.EmployeeContract ec
    INNER JOIN @EmployeeMapping em ON ec.EmpID = em.OldEmpId
-- #endregion

-- #region EMPLOYEE DEFAULT SHIFT TABLE
INSERT INTO dbo.EmployeeDefaultShift (
    EmpID, MonShift, TueShift, WedShift, ThuShift, FriShift, SatShift, SunShift
)
SELECT em.EmpId,
    s_mon.ShiftId, 
    s_tue.ShiftId, 
    s_wed.ShiftId, 
    s_thu.ShiftId, 
    s_fri.ShiftId, 
    s_sat.ShiftId, 
    s_sun.ShiftId
FROM CabintechHRM.dbo.EmployeeDefaultShift eds
    INNER JOIN @EmployeeMapping em ON eds.EmpID = em.OldEmpId 
    LEFT JOIN dbo.Shift s_mon ON eds.MonShift = s_mon.OldShiftId AND s_mon.CompanyId = @CompanyId
    LEFT JOIN dbo.Shift s_tue ON eds.TueShift = s_tue.OldShiftId AND s_tue.CompanyId = @CompanyId
    LEFT JOIN dbo.Shift s_wed ON eds.WedShift = s_wed.OldShiftId AND s_wed.CompanyId = @CompanyId
    LEFT JOIN dbo.Shift s_thu ON eds.ThuShift = s_thu.OldShiftId AND s_thu.CompanyId = @CompanyId
    LEFT JOIN dbo.Shift s_fri ON eds.FriShift = s_fri.OldShiftId AND s_fri.CompanyId = @CompanyId
    LEFT JOIN dbo.Shift s_sat ON eds.SatShift = s_sat.OldShiftId AND s_sat.CompanyId = @CompanyId
    LEFT JOIN dbo.Shift s_sun ON eds.SunShift = s_sun.OldShiftId AND s_sun.CompanyId = @CompanyId
-- #endregion

-- #region EMPLOYEE PATERNITY TABLE
INSERT INTO dbo.EmployeePaternity (
    EmpId, ChildBornDate, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, 
    LeaveDay, Remark, BalanceDay, OldPaternityId
)
SELECT em.EmpId, 
    ep.ChildBornDate, 
    em_created.EmpId, 
    ep.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    em_modified.EmpId, 
    ep.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ep.LeaveDay, 
    ep.Remark, 
    ep.BalanceDay, 
    ep.PaternityId
FROM CabintechHRM.dbo.EmployeePaternity ep
    INNER JOIN @EmployeeMapping em ON ep.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_created ON ep.CreatedBy = em_created.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON ep.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE POSTNATAL TABLE
INSERT INTO dbo.EmployeePostnatal (
    EmpId, FromDate, ToDate, WorkingHours, NormalWorkingHours, Remark, 
    CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, OldPostnatalId
)
SELECT em.EmpId, 
    ep.FromDate, 
    ep.ToDate, 
    ep.WorkingHours, 
    ep.NormalWorkingHours, 
    ep.Remark, 
    em_created.EmpId, 
    ep.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    em_modified.EmpId, 
    ep.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ep.PostnatalId
FROM CabintechHRM.dbo.EmployeePostnatal ep
    INNER JOIN @EmployeeMapping em ON ep.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_created ON ep.CreatedBy = em_created.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON ep.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE RELATIONSHIP TABLE
INSERT INTO dbo.EmployeeRelationship (
    EmpId, FullName, Phone, Relationship, DateOfBirth, Gender, IsEmergency, 
    CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, OldId
)
SELECT em.EmpId, 
    er.FullName, 
    er.Phone, 
    er.Relationship, 
    er.DateOfBirth, 
    er.Gender, 
    er.IsEmergency, 
    er.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    em_created.EmpId, 
    er.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    em_modified.EmpId,
    er.Id 
FROM CabintechHRM.dbo.EmployeeRelationship er
    INNER JOIN @EmployeeMapping em ON er.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_created ON er.CreatedBy = em_created.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON er.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE ROLE TABLE
INSERT INTO dbo.EmployeeRole (
    EmployeeId, RoleId, ModifiedBy, ModifiedDate
)
SELECT em.EmpId, 
    er.RoleId, 
    em_modified.EmpId, 
    er.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM CabintechHRM.dbo.EmployeeRole er
    INNER JOIN @EmployeeMapping em ON er.EmployeeId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON er.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE SUMMARY TABLE
INSERT INTO dbo.EmployeeSummary (
    EmpId, AnnualLeaveBalance, KeepInViewBalance, CanOT, IsLocal, WorkingDays, 
    WorkingHours, IsDefaultSchedule, CompanyDate, CountryCode, IsTopManager, 
    OffDaysbyWeek, Unit, IsExpatUseHoliday, MilitaryFromDate, MilitaryToDate, 
    Remark, SpecialOT, HospitalizationLeaveBalance, SickLeaveBalance, WorkingHoursByWeek
)
SELECT em.EmpId,
    es.AnnualLeaveBalance, 
    es.KeepInViewBalance, 
    es.CanOT, 
    es.IsLocal, 
    es.WorkingDays, 
    es.WorkingHours, 
    es.IsDefaultSchedule, 
    es.CompanyDate, 
    es.CountryCode, 
    es.IsTopManager, 
    es.OffDaysbyWeek, 
    es.Unit, 
    es.IsExpatUseHoliday, 
    es.MilitaryFromDate, 
    es.MilitaryToDate, 
    es.Remark, 
    es.SpecialOT, 
    es.HospitalizationLeaveBalance, 
    es.SickLeaveBalance, 
    es.WorkingHoursByWeek
FROM CabintechHRM.dbo.EmployeeSummary es
    INNER JOIN @EmployeeMapping em ON es.EmpId = em.OldEmpId
-- TODO: CHECK UNIT ?
-- #endregion

-- #region EMPLOYEE SUPERVISOR TABLE
INSERT INTO dbo.EmployeeSupervisor (
    OwnerId, EmpId, ActionType, RequestType, ModifiedBy, ModifiedDate, 
    OrderNo, OrderCode, IsDeleted
)
SELECT em_owner.EmpId,
    em.EmpId,
    es.ActionType, 
    es.RequestType, 
    em_modified.EmpId,
    es.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    es.OrderNo, 
    es.OrderCode, 
    es.IsDeleted
FROM CabintechHRM.dbo.EmployeeSupervisor es
    INNER JOIN @EmployeeMapping em ON es.EmpId = em.OldEmpId
    INNER JOIN @EmployeeMapping em_owner ON es.OwnerId = em_owner.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON es.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE WORK FROM HOME TABLE
INSERT INTO dbo.EmployeeWorkFromHome (
    EmpId, FromDate, ToDate, Remark, ModifiedBy, ModifiedDate, OldEmployeeWorkFromHomeId
)
SELECT em.EmpId, 
    ewfh.FromDate, 
    ewfh.ToDate, 
    ewfh.Remark, 
    em_modified.EmpId, 
    ewfh.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    ewfh.EmployeeWorkFromHomeId
FROM CabintechHRM.dbo.EmployeeWorkFromHome ewfh
    INNER JOIN @EmployeeMapping em ON ewfh.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON ewfh.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE GROUP TABLE
INSERT INTO dbo.EmployeeGroup (GroupId, EmpId, isMainGroup)
SELECT g.GroupId,       
    em.EmpId,        
    eg.isMainGroup    
FROM CabintechHRM.dbo.EmployeeGroup AS eg
    INNER JOIN dbo.[Group] AS g ON eg.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId
    INNER JOIN @EmployeeMapping AS em ON eg.EmpID = em.OldEmpId
-- #endregion

-- #region GROUP MANAGER TABLE
INSERT INTO dbo.GroupManager (GroupId, EmpId, RoleId)
SELECT g.GroupId,  
    em.EmpId,   
    gm.RoleId 
FROM CabintechHRM.dbo.GroupManager AS gm
    INNER JOIN dbo.[Group] AS g ON gm.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId
    INNER JOIN @EmployeeMapping AS em ON gm.EmpID = em.OldEmpId
-- #endregion

-- #region GROUP SUPERVISOR TABLE
INSERT INTO dbo.GroupSupervisor (OwnerId, GroupId, ActionType, RequestType, ModifiedBy, ModifiedDate, IsDeleted, DisplayOrder)
SELECT em.EmpId,  
    g.GroupId, 
    gs.ActionType,
    gs.RequestType,
    em_mod.EmpId, -- Lấy ModifiedBy từ Employee Mapping
    gs.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, 
    gs.IsDeleted,
    gs.DisplayOrder
FROM CabintechHRM.dbo.GroupSupervisor AS gs
    INNER JOIN dbo.[Group] AS g ON gs.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId
    INNER JOIN @EmployeeMapping AS em ON gs.OwnerId = em.OldEmpId
    LEFT JOIN @EmployeeMapping AS em_mod ON gs.ModifiedBy = em_mod.OldEmpId
-- #endregion

-- #region EXTENSION NUMBER TABLE
INSERT INTO dbo.ExtensionNumbers (FullName, NickName, ExtensionNo, IsInternal, IsGroup, EmpId, GroupId, OrderNo, CompanyId, OldExtID)
SELECT en.FullName, 
    en.NickName, 
    en.ExtensionNo, 
    en.IsInternal, 
    en.IsGroup, 
    em.EmpId, 
    CASE WHEN en.IsInternal = 1 THEN g.GroupId ELSE  en.GroupID END,
    en.OrderNo,
	@CompanyId,
	en.ExtID
FROM CabintechHRM.dbo.ExtensionNumbers AS en
    LEFT JOIN @EmployeeMapping AS em ON en.EmpID = em.OldEmpId
    LEFT JOIN dbo.[Group] AS g ON en.GroupID = g.OldGroupId AND g.CompanyId = @CompanyId;


UPDATE en
SET en.GroupId = exm_1.ExtID
FROM dbo.ExtensionNumbers en
LEFT JOIN dbo.ExtensionNumbers exm_1 ON en.GroupID = exm_1.OldExtID
WHERE en.IsInternal = 0 AND en.CompanyId = @CompanyId
-- #endregion

-- #region MAIL SETTINGS TABLE
INSERT INTO dbo.MailSettings (GroupId, Action, AllowSendUser, AllowSendVerifier, AllowSendApprover, AllowSendHR, AllowSendMailGroup)
SELECT 
    CASE WHEN g.GroupId IS NOT NULL THEN g.GroupId ELSE ms.GroupId END, 
    ms.Action,
    ms.AllowSendUser,
    ms.AllowSendVerifier,
    ms.AllowSendApprover,
    ms.AllowSendHR,
    ms.AllowSendMailGroup
FROM CabintechHRM.dbo.MailSettings AS ms
    LEFT JOIN dbo.[Group] AS g ON ms.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId
WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.MailSettings AS setting WITH (NOLOCK)
        WHERE setting.GroupId = ms.GroupId
            AND setting.Action = ms.Action
			AND ms.GroupId = 0
    )
-- #endregion


INSERT INTO [dbo].[HospitalizationLeaveTrans]
           (EmpId
           ,RequestId
           ,Description
           ,FromDate
           ,ToDate
           ,DeductDays
           ,CreditDays
           ,IsDeleted
           ,CreatedDate
           ,CreatedBy
           ,ModifiedDate
           ,ModifiedBy
		   ,OldTransId)
     SELECT
           emp.EmpId
           ,wkr.RequestId
           ,hpl.Description
           ,hpl.FromDate
           ,hpl.ToDate
           ,hpl.DeductDays
           ,hpl.CreditDays
           ,hpl.IsDeleted
           ,hpl.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empCreated.EmpId
           ,hpl.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empModified.EmpId
		   ,hpl.TransId
	FROM CabintechHRM.dbo.[HospitalizationLeaveTrans] AS hpl WITH (NOLOCK)
    INNER JOIN @EmployeeMapping AS emp ON hpl.EmpId = emp.OldEmpId
	LEFT JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON hpl.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN @EmployeeMapping AS empCreated ON hpl.CreatedBy = empCreated.OldEmpId
	LEFT JOIN @EmployeeMapping AS empModified ON hpl.ModifiedBy = empModified.OldEmpId;


INSERT INTO [dbo].[HospitalLeave]
           (RequestId
           ,IsHospitalApplication)
     SELECT
           wkr.RequestId
           ,IsHospitalApplication
	FROM CabintechHRM.dbo.[HospitalLeave] AS hl WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON hl.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId


INSERT INTO [dbo].[WeekendLeaveTrans]
           (EmpId
           ,WorkDate
           ,LeaveTypeId
           ,LeaveDay
           ,RequestId
           ,IsDiscipline
           ,InsertedDate)
     SELECT
          emp.EmpId
           ,wl.WorkDate
           ,wl.LeaveTypeId
           ,wl.LeaveDay
           ,wkr.RequestId
           ,wl.IsDiscipline
           ,wl.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM CabintechHRM.dbo.[WeekendLeaveTrans] AS wl WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON wl.EmpId = emp.OldEmpId
	LEFT JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON wl.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	


INSERT INTO [dbo].[KeepInViewByDayTrans]
           (EmpId
           ,RequestId
           ,CreditDays
           ,DeductDays
           ,InYear
           ,InsertedDate)
     SELECT
           emp.EmpId
           ,wkr.RequestId
           ,kivd.CreditDays
           ,kivd.DeductDays
           ,kivd.InYear
           ,kivd.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM CabintechHRM.dbo.[KeepInViewByDayTrans] AS kivd WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON kivd.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON kivd.EmpId = emp.OldEmpId



INSERT INTO [dbo].[KeepInViewByHourTrans]
           (EmpId
           ,WorkDate
           ,RequestId
           ,CreditMinutes
           ,DeductMinutes
           ,InsertedDate
           ,MinutesBalance)
     SELECT
           emp.EmpId
           ,kivh.WorkDate
           ,wkr.RequestId
           ,kivh.CreditMinutes
           ,kivh.DeductMinutes
           ,kivh.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,kivh.MinutesBalance
	FROM CabintechHRM.dbo.[KeepInViewByHourTrans] AS kivh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON kivh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON kivh.EmpId = emp.OldEmpId


INSERT INTO [dbo].[KeepInViewRequest]
           (RequestId
           ,EmpId
           ,IsHalfDay
           ,FromTime
           ,ToTime
           ,RefNo
           ,OnDate
           ,KeepInViewType
           ,ShiftId)
     SELECT
          wkr.RequestId
           ,emp.EmpId
           ,kiv.IsHalfDay
           ,kiv.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,kiv.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,kiv.RefNo
           ,kiv.OnDate
           ,kiv.KeepInViewType
           ,s.ShiftId
	FROM CabintechHRM.dbo.[KeepInViewRequest] AS kiv WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON kiv.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON kiv.EmpId = emp.OldEmpId
	LEFT JOIN dbo.Shift AS s WITH (NOLOCK) ON kiv.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId



INSERT INTO [dbo].[KeepInViewRequestHistory]
           (RequestId
           ,EmpId
           ,OnDate
           ,IsHalfDay
           ,FromTime
           ,ToTime
           ,HistoryId
           ,KeepInViewType)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,kivh.OnDate
           ,kivh.IsHalfDay
           ,kivh.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,kivh.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,wkrh.HistoryId
           ,kivh.KeepInViewType
	FROM  CabintechHRM.dbo.[KeepInViewRequestHistory] AS kivh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON kivh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON kivh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON kivh.EmpId = emp.OldEmpId
	
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
	FROM CabintechHRM.dbo.[LateInEarlyOutRequest] AS lieo WITH (NOLOCK)
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
	FROM CabintechHRM.dbo.[LateInEarlyOutRequestHistory] AS lieoh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lieoh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON lieoh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON lieoh.EmpId = emp.OldEmpId


INSERT INTO [dbo].[LeaveRequest]
           (RequestId
           ,EmpId
           ,FromDate
           ,ToDate
           ,LeaveType
           ,TotalDays
           ,RefNo
           ,ReworkCount)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lr.FromDate
           ,lr.ToDate
           ,lr.LeaveType
           ,lr.TotalDays
           ,lr.RefNo
           ,lr.ReworkCount
	FROM CabintechHRM.dbo.[LeaveRequest] AS lr WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lr.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON lr.EmpId = emp.OldEmpId



INSERT INTO [dbo].LeaveRequestDetail
           (RequestId
           ,EmpId
           ,OnDate
           ,ShiftId
           ,LeaveType
           ,IsHalfDay
           ,FromTime
           ,ToTime
           ,WorkType)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lrd.OnDate
           ,s.ShiftId
           ,lrd.LeaveType
           ,lrd.IsHalfDay
           ,lrd.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,lrd.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,lrd.WorkType
	FROM CabintechHRM.dbo.[LeaveRequestDetail] AS lrd WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lrd.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON lrd.EmpId = emp.OldEmpId 
	LEFT JOIN dbo.Shift AS s WITH (NOLOCK) ON lrd.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId


INSERT INTO [dbo].[LeaveRequestDetailHistory]
           (RequestId
           ,EmpId
           ,OnDate
           ,ShiftId
           ,LeaveType
           ,IsHalfDay
           ,FromTime
           ,ToTime
           ,WorkType
           ,HistoryId)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lrdh.OnDate
           ,s.ShiftId
           ,lrdh.LeaveType
           ,lrdh.IsHalfDay
           ,lrdh.FromTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,lrdh.ToTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,lrdh.WorkType
           ,wkrh.HistoryId
	FROM CabintechHRM.dbo.[LeaveRequestDetailHistory] AS lrdh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lrdh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON lrdh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON lrdh.EmpId = emp.OldEmpId 
	LEFT JOIN dbo.Shift AS s WITH (NOLOCK) ON lrdh.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId


INSERT INTO [dbo].[LeaveRequestHistory]
           (RequestId
           ,EmpId
           ,FromDate
           ,ToDate
           ,LeaveType
           ,TotalDays
           ,HistoryId)
     SELECT
           wkr.RequestId
           ,emp.EmpId
           ,lrh.FromDate
           ,lrh.ToDate
           ,lrh.LeaveType
           ,lrh.TotalDays
           ,wkrh.HistoryId
	FROM CabintechHRM.dbo.[LeaveRequestHistory] AS lrh WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lrh.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	LEFT JOIN dbo.WorkingTimeRequestHistory AS wkrh WITH (NOLOCK) ON lrh.HistoryId = wkrh.OldHistoryId AND wkr.RequestId = wkrh.RequestId
	INNER JOIN @EmployeeMapping AS emp ON lrh.EmpId = emp.OldEmpId 


INSERT INTO [dbo].[LeaveTrans]
           (EmpId
           ,RequestId
           ,Description
           ,FromDate
           ,ToDate
           ,DeductDays
           ,CreditDays
           ,Deleted
           ,CreatedDate
           ,CreatedBy
           ,ModifiedDate
           ,ModifiedBy
           ,OldLeaveTransId)
     SELECT
           emp.EmpId
           ,wkr.RequestId
           ,lt.Description
           ,lt.FromDate
           ,lt.ToDate
           ,lt.DeductDays
           ,lt.CreditDays
           ,lt.Deleted
           ,lt.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone 
           ,empCreated.EmpId
           ,lt.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empModified.EmpId
           ,lt.LeaveTransId
	FROM CabintechHRM.dbo.[LeaveTrans] AS lt WITH (NOLOCK)
	LEFT JOIN dbo.WorkingTimeRequest AS wkr WITH (NOLOCK) ON lt.RequestId = wkr.OldRequestId AND wkr.CompanyId = @companyId
	INNER JOIN @EmployeeMapping AS emp ON lt.EmpId = emp.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empCreated ON lt.CreatedBy = empCreated.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified ON lt.ModifiedBy = empModified.OldEmpId;

-- #region MESSAGE TABLE
INSERT INTO dbo.[Message] (
    [Subject], Contents, Category, FromDate, ToDate, 
    IsDisabled, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, CompanyId, OldMessageId
)
SELECT 
    m.Subject,
    m.Contents,
    m.Category,
    m.FromDate,
    m.ToDate,
    m.IsDisabled,
    e_created.EmpId,
    m.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    e_modified.EmpId,
    m.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    @CompanyId,
    m.MessageId
FROM CabintechHRM.dbo.Message AS m
LEFT JOIN dbo.Employee AS e_created ON m.CreatedBy = e_created.OldEmpId
LEFT JOIN dbo.Employee AS e_modified ON m.ModifiedBy = e_modified.OldEmpId;
-- #endregion

-- #region MESSAGE EMPLOYEE TABLE
INSERT INTO dbo.MessageEmployee (
    MessageId, EmployeeId, Email, IsDisabled, IsRead
)
SELECT 
    m.MessageId,  
    em.EmpId,  
    me.Email,
    me.IsDisabled,
    me.IsRead
FROM CabintechHRM.dbo.MessageEmployee AS me
INNER JOIN dbo.[Message] AS m ON me.MessageId = m.OldMessageId AND m.CompanyId = @CompanyId
INNER JOIN dbo.Employee AS em ON me.EmployeeId = em.OldEmpId
WHERE em.EmpId IS NOT NULL;
-- #endregion

-- #region MESSAGE GROUP TABLE
INSERT INTO dbo.MessageGroup (
    MessageId, GroupId, Email
)
SELECT 
    m.MessageId,
    g.GroupId, 
    mg.Email
FROM CabintechHRM.dbo.MessageGroup AS mg
INNER JOIN dbo.[Group] AS g ON mg.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId
INNER JOIN dbo.[Message] AS m ON mg.MessageId = m.OldMessageId AND m.CompanyId = @CompanyId;
-- #endregion


INSERT INTO [dbo].[OTMonthlyRequest]
           (Month
           ,EmpId
           ,NormalHours
           ,OffHours
           ,PublicHours
           ,SpecialHours
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
           ,ModifiedBy
           ,ModifiedDate
           ,CreatedDate
           ,CreatedBy
		   ,OldRequestId)
     SELECT
           otm.[Month]
           ,emp.EmpId
           ,otm.NormalHours
           ,otm.OffHours
           ,otm.PublicHours
           ,otm.SpecialHours
           ,otm.CurrentStatus
           ,empVerify.EmpId
           ,empApprove.EmpId
           ,empHr.EmpId
           ,otm.VerifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,otm.ApprovedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,otm.HRDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,otm.VerifiedStatus
           ,otm.ApprovedStatus
           ,otm.HRStatus
           ,empModified.EmpId
           ,otm.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,otm.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,empCreated.EmpId
		   ,otm.RequestId
	FROM CabintechHRM.dbo.[OTMonthlyRequest] as otm  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON otm.EmpId = emp.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empVerify ON otm.VerifierId = empVerify.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empApprove  ON otm.ApproverId = empApprove.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empHr  ON otm.HRId = empHr.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empCreated ON otm.CreatedBy = empCreated.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified  ON otm.ModifiedBy = empModified.OldEmpId;


	
INSERT INTO [dbo].[OTDailyRequest]
           (OvertimeDate
           ,EmpId
           ,RequestId
           ,Schedule
           ,TimeIn
           ,TimeOut
           ,TotalHours
           ,NormalHours
           ,OffHours
           ,PublicHours
           ,SpecialHours
           ,Remark
           ,Status
           ,CreatedBy
           ,CreatedDate
           ,IsUpdated)
     SELECT
           otd.OvertimeDate
           ,emp.EmpId
           ,otm.RequestId
           ,s.ShiftID
           ,otd.TimeIn AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,otd.TimeOut AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,otd.TotalHours
           ,otd.NormalHours
           ,otd.OffHours
           ,otd.PublicHours
           ,otd.SpecialHours
           ,otd.Remark
           ,otd.Status
           ,empCreated.EmpId
           ,otd.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
           ,otd.IsUpdated
	FROM CabintechHRM.dbo.[OTDailyRequest] as otd  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON otd.EmpId = emp.OldEmpId 
	LEFT JOIN dbo.OTMonthlyRequest AS otm WITH (NOLOCK) ON otd.RequestId = otm.OldRequestId 
	LEFT JOIN dbo.Shift AS s ON otd.Schedule = s.OldShiftId AND s.CompanyId = @CompanyId
	LEFT JOIN @EmployeeMapping AS empCreated ON otd.CreatedBy = empCreated.OldEmpId 


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
           ,sa.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM CabintechHRM.dbo.[ScheduleArrangement] AS sa  WITH (NOLOCK)
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
           ,sas.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM CabintechHRM.dbo.[ScheduleArrangementDefaultShift] AS sas  WITH (NOLOCK)
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
           ,sag.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
	FROM CabintechHRM.dbo.[ScheduleArrangementGroupOrder] AS sag  WITH (NOLOCK)
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
	FROM CabintechHRM.dbo.[ScheduleArrangementOffDayReplacement] AS sar  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON sar.EmployeeId = emp.OldEmpId 


INSERT INTO [dbo].[RefResource]
           (RefName
           ,ResourceId
           ,[Value]
           ,[Description]
           ,IsActive
		   ,CompanyId)
     SELECT
           RefName
           ,ResourceId
           ,[Value]
           ,[Description]
           ,IsActive
		   ,@CompanyId
	FROM [HRM].[dbo].[RefResource] 



select* from Department
select* from [Group] g where g.CompanyId = 9 order by Code
selecT* from Employee e 
inner join CompanyEmployee c on c.EmpId = e.EmpId
where c.CompanyId = 9


declare @TeamId INT = NULL
	,@keyWord varchar(20) = null
	,@isDeleted BIT = NULL
	DECLARE @tblGroup TABLE (
		GroupId INT
		,NoOfMembers INT
		,TotalLocal INT
		,TotalExpat INT
		)

	INSERT INTO @tblGroup (
		GroupId
		,NoOfMembers
		,TotalLocal
		,TotalExpat
		)
	SELECT g.GroupId
		,SUM(CASE 
				WHEN esum.IsLocal IS NOT NULL THEN 1
				ELSE 0
				END) AS NoOfMembers
		,SUM(CASE 
				WHEN esum.IsLocal = 1 THEN 1
				ELSE 0
				END) TotalLocal
		,SUM(CASE 
				WHEN esum.IsLocal = 0 THEN 1
				ELSE 0
				END) TotalExpat
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.GroupId = g.GroupId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
	GROUP BY g.GroupId

	SELECT g.groupId AS TeamId
	,mng.EmpId
	,emng.NickName
		,g.[Name]
		,g.Code
				,dept.Code as DepartmentCode
				,g.IsDeleted
		,g.[Rank]
		,g.MailGroup
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,tbl.NoOfMembers
		,tbl.TotalLocal
		,tbl.TotalExpat
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		LEFT JOIN @tblGroup AS tbl ON g.GroupId = tbl.GroupId
		LEFT JOIN dbo.GroupManager AS mng WITH (NOLOCK) ON mng.GroupId = g.GroupId AND mng.RoleId = 3 -- TeamLeader
		LEFT JOIN dbo.Employee AS emng WITH (NOLOCK) ON emng.EmpId = mng.EmpId

	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		AND (
			 @keyWord IS NULL
			 OR LOWER(g.name) like LOWER('%' + @keyWord + '%') 
			 OR LOWER(g.Code) like LOWER('%' + @keyWord + '%') 
			)
		AND CompanyId = 9
	ORDER BY g.[Code]





ROLLBACK;
GO




