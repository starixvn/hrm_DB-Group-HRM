--BEGIN TRANSACTION

USE [bodb_HRM]
GO
DECLARE @CompanyId INT;
DECLARE @CurrentTimeZone NVARCHAR(50) = 'Taipei Standard Time';  /* SE Asia Standard Time (UTC+7) / Taipei Standard Time (UTC+8)  */
DECLARE @TargetTimeZone NVARCHAR(50) = 'SA Western Standard Time'; 
SET @CompanyId = 12;

DECLARE @EmployeeMapping TABLE (
    EmpId INT,
    OldEmpId INT,
    CompanyId INT
);

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
    LetsTalk, JobLevelId, UserId, NULL, NULL, ResignedReason, 
    ExpertGradeId, EmpId AS OldEmpId  -- Keep track of old EmpId
FROM ConnectshoreHRM.dbo.Employee
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
-- GroupId sẽ map lại sau ở phần OrgChart vì hiện tại chưa có GroupId mới
-- JobTitleId sẽ map lại sau 
-- Mapping JobLevel + GradeLevel
-- #endregion

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
FROM ConnectshoreHRM.dbo.Shift s
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
FROM ConnectshoreHRM.dbo.LeaveType;
-- #endregion

-- #region HOLIDAY TABLE
INSERT INTO dbo.Holiday (HolidayName, FromDate, ToDate, TypeId, CompanyId, OldHolidayId)
SELECT HolidayName, FromDate, ToDate, TypeId, @CompanyId, Id 
FROM ConnectshoreHRM.dbo.Holiday;
-- #endregion

-- #region MEMO TABLE
INSERT INTO dbo.Memo (
    RefNo, Contents, Subject, SentTo, SentFrom, ForInfo, TotalPages, 
    SentDate, Category, Type, Enabled, CompanyId, OldId
)
SELECT RefNo, Contents, Subject, SentTo, SentFrom, ForInfo, TotalPages, 
    SentDate, Category, Type, Enabled, @CompanyId, Id 
FROM ConnectshoreHRM.dbo.Memo;
-- #endregion

-- #region SYSTEM CONFIGS TABLE
INSERT INTO dbo.SystemConfigs ([Key], [Value], CompanyId)
SELECT [Key], [Value], @CompanyId 
FROM ConnectshoreHRM.dbo.SystemConfigs;
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
FROM ConnectshoreHRM.dbo.LookupData ld;
-- update Job title
UPDATE emp
SET emp.JobTitleId = ld.Id
FROM dbo.Employee emp
INNER JOIN dbo.CompanyEmployee ce ON emp.EmpId = ce.EmpId AND ce.CompanyId = @CompanyId
LEFT JOIN dbo.LookupData ld ON emp.JobTitleId = ld.OldId and ld.CompanyId = @CompanyId

--#region NEW STRUCTURE =============================================================================================================
DECLARE @maxGroupUnitId INT = ISNULL((SELECT MAX(GroupUnitId) FROM dbo.Unit), 0);

WITH DistinctUnits AS (
    SELECT DISTINCT
        u.Code,
        u.IsActive,
        u.IsDeleted
    FROM ConnectshoreHRM.dbo.Unit u
    INNER JOIN ConnectshoreHRM.dbo.Department d WITH(NOLOCK) ON d.UnitId = u.UnitId
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.Unit newUnit
        WHERE newUnit.Code = u.Code
    )
)

INSERT INTO dbo.Unit (
        [Code]
        ,[IsActive]
        ,[IsDeleted]
        ,[ModifiedDate]
        ,[GroupUnitId])
SELECT DISTINCT
        u.Code,
        u.IsActive,
        u.IsDeleted,
        GETDATE(),
        ROW_NUMBER() OVER (ORDER BY (SELECT 1)) + @maxGroupUnitId
FROM DistinctUnits u


DECLARE @maxGroupDepartmentId INT = ISNULL((SELECT MAX(GroupDeptId) FROM dbo.Department), 0);

WITH DistinctDepartments AS (
    SELECT DISTINCT
		d.DepartmentId,
        d.Code,
        d.Name,
        d.IsActive,
        d.IsDeleted,
        u.Code AS UnitCode
    FROM ConnectshoreHRM.dbo.Department d
    INNER JOIN ConnectshoreHRM.dbo.Unit u WITH(NOLOCK) ON u.UnitId = d.UnitId
    WHERE EXISTS (
        SELECT 1 
        FROM ConnectshoreHRM.dbo.Section s WITH(NOLOCK) 
        WHERE s.DepartmentId = d.DepartmentId
    )
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.Department newDept
        INNER JOIN dbo.Unit newUnit ON newDept.UnitId = newUnit.UnitId
        WHERE newDept.Code = d.Code AND newUnit.Code = u.Code
    )
)

INSERT INTO [dbo].[Department] (
    Code,
    Name,
    UnitId,
    IsActive,
    ModifiedDate,
    IsDeleted,
    GroupDeptId,
    AccountableArea
)
SELECT
    d.Code,
    d.Name,
    newUnit.UnitId,
    d.IsActive,
    GETDATE(),
    d.IsDeleted,
    ROW_NUMBER() OVER (ORDER BY d.Code) + @maxGroupDepartmentId,
    d.Name
FROM DistinctDepartments d
INNER JOIN dbo.Unit newUnit ON newUnit.Code = d.UnitCode


DECLARE @maxGroupTeamId INT = ISNULL((SELECT MAX(GroupTeamId) FROM dbo.[Group]), 0);
INSERT INTO dbo.[Group] (
    Code, Name, Rank, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, IsDeleted, MailGroup,
    LocalBasicAnnualLeaveBalance, LocalWorkingDays, LocalWorkingHours, LocalOffDaysbyWeek,
    ExpatBasicAnnualLeaveBalance, ExpatWorkingDays, ExpatWorkingHours, ExpatOffDaysbyWeek,
    LocalWorkingHoursbyWeek, ExpatWorkingHoursbyWeek, CompanyId, OldGroupId, 
	DepartmentId, AccountableArea, GroupTeamId
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
	newDept.DepartmentId,
	g.Name,
	ROW_NUMBER() OVER (ORDER BY (SELECT 1)) + @maxGroupTeamId
FROM ConnectshoreHRM.dbo.[Group] g
INNER JOIN ConnectshoreHRM.dbo.Section s WITH(NOLOCK) ON s.SectionId = g.SectionId
INNER JOIN ConnectshoreHRM.dbo.Department dept WITH(NOLOCK) ON dept.DepartmentId = s.DepartmentId
INNER JOIN ConnectshoreHRM.dbo.Unit u WITH (NOLOCK) ON u.UnitId = dept.UnitId
INNER JOIN dbo.Unit newUnit WITH (NOLOCK) ON newUnit.Code = u.Code
INNER JOIN dbo.Department newDept WITH (NOLOCK) ON newDept.Code = dept.Code AND newDept.UnitId = newUnit.UnitId


-- Map lại GroupId của Employee
UPDATE emp
SET emp.GroupId = g_new.GroupId
FROM dbo.Employee emp
INNER JOIN dbo.CompanyEmployee ce ON emp.EmpId = ce.EmpId AND ce.CompanyId = @CompanyId
LEFT JOIN dbo.[Group] g_new ON emp.GroupId = g_new.OldGroupId AND g_new.CompanyId = @CompanyId;
-- #endregion


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
	FROM ConnectshoreHRM.dbo.WorkingTimeRequest AS wr  WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.WorkingTimeRequestHistory as wrh  WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS wr WITH (NOLOCK) ON wrh.RequestId = wr.OldRequestId AND wr.CompanyId = @CompanyId  --some requestId not exists in WR
	INNER JOIN @EmployeeMapping AS emp ON wrh.EmpId = emp.OldEmpId
	LEFT JOIN @EmployeeMapping AS empVerify ON wrh.VerifierId = empVerify.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empApprove  ON wrh.ApproverId = empApprove.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empHr  ON wrh.HRId = empHr.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empCreated ON wrh.CreatedBy = empCreated.OldEmpId 
	LEFT JOIN @EmployeeMapping AS empModified  ON wrh.ModifiedBy = empModified.OldEmpId;

INSERT INTO dbo.tmpSickLeaveBalance (EmpId, RequestId, TotalDays, [Month], [Year], [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.[Month], tmp.[Year], tmp.[Status]
FROM ConnectshoreHRM.dbo.tmpSickLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN @EmployeeMapping AS e ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId


INSERT INTO dbo.tmpLeaveBalance (EmpId, RequestId, TotalDays, InYear, InMonth, [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.InYear, tmp.InMonth, tmp.[Status]
FROM ConnectshoreHRM.dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN @EmployeeMapping AS e ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO dbo.tmpKIVLeaveBalance (EmpId, RequestId, TotalDays, InYear, [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.InYear, tmp.[Status]
FROM ConnectshoreHRM.dbo.tmpKIVLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN @EmployeeMapping AS e ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO dbo.tmpHospitalizationLeaveBalance (EmpId, RequestId, TotalDays, [Month], [Year], [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.[Month], tmp.[Year], tmp.[Status]
FROM ConnectshoreHRM.dbo.tmpHospitalizationLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN @EmployeeMapping AS e ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO dbo.tmpEmployeeAttendace(EmpId, WorkDate, InsertedDate)
SELECT e.EmpId, tmp.WorkDate, tmp.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM ConnectshoreHRM.dbo.tmpEmployeeAttendace AS tmp WITH (NOLOCK)
    INNER JOIN @EmployeeMapping AS e ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE ce.CompanyId = @CompanyId


INSERT INTO dbo.TimeRecord(EmpId, RecordTime, InOutType, InsertDate, ModifiedBy, ModifiedDate, CompanyId, OldId)
SELECT e.EmpId, tc.RecordTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, tc.InOutType,
    tc.InsertDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, NULL, NULL, @CompanyId, tc.Id
FROM ConnectshoreHRM.dbo.TimeRecord AS tc WITH (NOLOCK)
    INNER JOIN @EmployeeMapping AS e ON tc.EmpId = e.OldEmpId
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
FROM ConnectshoreHRM.dbo.TimeRecordExt AS ext WITH (NOLOCK)
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
FROM ConnectshoreHRM.dbo.SickLeaveTrans AS st WITH (NOLOCK)
    INNER JOIN @EmployeeMapping AS e ON st.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    LEFT JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON st.RequestId = rq.OldRequestId AND rq.CompanyId = @CompanyId
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
FROM ConnectshoreHRM.dbo.RoleFunction AS rf WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.ChangeShiftRequestDetail AS csd WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.ChangeShiftRequestDetailHistory AS csdh WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.ChangeShiftRequestHistory AS csh WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.CheckInOutRequest AS cio WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.CheckInOutRequestHistory AS cioh WITH (NOLOCK)
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
FROM ConnectshoreHRM.dbo.Discipline d
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
FROM ConnectshoreHRM.dbo.DisciplineGroupRule dgr
INNER JOIN dbo.[Group] g ON dgr.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId;

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
FROM ConnectshoreHRM.dbo.DisciplineIgnore di
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
FROM ConnectshoreHRM.dbo.DisciplineIgnoreDetail di
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
FROM ConnectshoreHRM.dbo.DisciplineOutOfControl doc
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
FROM ConnectshoreHRM.dbo.DisciplineRequestTrans drt
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
	FROM ConnectshoreHRM.dbo.OtherDiscipline od
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
FROM ConnectshoreHRM.dbo.EmployeeAttendance ea
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
FROM ConnectshoreHRM.dbo.EmployeeCalendar ec
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
FROM ConnectshoreHRM.dbo.EmployeeContract ec
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
FROM ConnectshoreHRM.dbo.EmployeeDefaultShift eds
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
FROM ConnectshoreHRM.dbo.EmployeePaternity ep
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
FROM ConnectshoreHRM.dbo.EmployeePostnatal ep
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
FROM ConnectshoreHRM.dbo.EmployeeRelationship er
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
FROM ConnectshoreHRM.dbo.EmployeeRole er
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
FROM ConnectshoreHRM.dbo.EmployeeSummary es
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
FROM ConnectshoreHRM.dbo.EmployeeSupervisor es
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
FROM ConnectshoreHRM.dbo.EmployeeWorkFromHome ewfh
    INNER JOIN @EmployeeMapping em ON ewfh.EmpId = em.OldEmpId
    LEFT JOIN @EmployeeMapping em_modified ON ewfh.ModifiedBy = em_modified.OldEmpId
-- #endregion

-- #region EMPLOYEE GROUP TABLE
INSERT INTO dbo.EmployeeGroup (GroupId, EmpId, isMainGroup)
SELECT g.GroupId,       
    em.EmpId,        
    eg.isMainGroup    
FROM ConnectshoreHRM.dbo.EmployeeGroup AS eg
    INNER JOIN dbo.[Group] AS g ON eg.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId
    INNER JOIN @EmployeeMapping AS em ON eg.EmpID = em.OldEmpId
-- #endregion

-- #region GROUP MANAGER TABLE
INSERT INTO dbo.GroupManager (GroupId, EmpId, RoleId)
SELECT g.GroupId,  
    em.EmpId,   
    gm.RoleId 
FROM ConnectshoreHRM.dbo.GroupManager AS gm
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
FROM ConnectshoreHRM.dbo.GroupSupervisor AS gs
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
FROM ConnectshoreHRM.dbo.ExtensionNumbers AS en
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
FROM ConnectshoreHRM.dbo.MailSettings AS ms
    INNER JOIN dbo.[Group] AS g ON ms.GroupId = g.OldGroupId AND g.CompanyId = @CompanyId
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
	FROM ConnectshoreHRM.dbo.[HospitalizationLeaveTrans] AS hpl WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[HospitalLeave] AS hl WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[WeekendLeaveTrans] AS wl WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[KeepInViewByDayTrans] AS kivd WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[KeepInViewByHourTrans] AS kivh WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[KeepInViewRequest] AS kiv WITH (NOLOCK)
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
	FROM  ConnectshoreHRM.dbo.[KeepInViewRequestHistory] AS kivh WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[LateInEarlyOutRequest] AS lieo WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[LateInEarlyOutRequestHistory] AS lieoh WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[LeaveRequest] AS lr WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[LeaveRequestDetail] AS lrd WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[LeaveRequestDetailHistory] AS lrdh WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[LeaveRequestHistory] AS lrh WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[LeaveTrans] AS lt WITH (NOLOCK)
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
FROM ConnectshoreHRM.dbo.Message AS m
LEFT JOIN @EmployeeMapping AS e_created ON m.CreatedBy = e_created.OldEmpId
LEFT JOIN @EmployeeMapping AS e_modified ON m.ModifiedBy = e_modified.OldEmpId;
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
FROM ConnectshoreHRM.dbo.MessageEmployee AS me
INNER JOIN dbo.[Message] AS m ON me.MessageId = m.OldMessageId AND m.CompanyId = @CompanyId
INNER JOIN @EmployeeMapping AS em ON me.EmployeeId = em.OldEmpId
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
FROM ConnectshoreHRM.dbo.MessageGroup AS mg
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
	FROM ConnectshoreHRM.dbo.[OTMonthlyRequest] as otm  WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[OTDailyRequest] as otd  WITH (NOLOCK)
	INNER JOIN @EmployeeMapping AS emp ON otd.EmpId = emp.OldEmpId 
	LEFT JOIN dbo.OTMonthlyRequest AS otm WITH (NOLOCK) ON otd.RequestId = otm.OldRequestId 
    INNER JOIN dbo.CompanyEmployee ce ON ce.EmpId = otm.EmpId AND ce.CompanyId = @CompanyId
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
	FROM ConnectshoreHRM.dbo.[ScheduleArrangement] AS sa  WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[ScheduleArrangementDefaultShift] AS sas  WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[ScheduleArrangementGroupOrder] AS sag  WITH (NOLOCK)
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
	FROM ConnectshoreHRM.dbo.[ScheduleArrangementOffDayReplacement] AS sar  WITH (NOLOCK)
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
	FROM ConnectshoreHRM.[dbo].[RefResource] 

-- Insert data into temporary table with optimized time zone conversion
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
FROM ConnectshoreHRM.dbo.tmpEmployeeCalendar AS tmp WITH (NOLOCK)
INNER JOIN @EmployeeMapping AS e ON tmp.EmpId = e.OldEmpId
INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
LEFT JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId AND rq.CompanyId = @CompanyId
LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON tmp.ShiftId = s.OldShiftId AND s.CompanyId = @CompanyId
WHERE ce.CompanyId = @CompanyId

GO

--ROLLBACK