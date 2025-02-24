USE bodb_HRM
GO

DECLARE @CompanyId SMALLINT = 3
    ,@CurrentTimeZone NVARCHAR(50) = 'SE Asia Standard Time'
    ,@TargetTimeZone NVARCHAR(50) = 'SE Asia Standard Time' -- hong_kong: China Standard Time 

INSERT INTO dbo.tmpSickLeaveBalance (EmpId, RequestId, TotalDays, [Month], [Year], [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.[Month], tmp.[Year], tmp.[Status]
FROM SMSHRM.dbo.tmpSickLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO dbo.tmpLeaveBalance (EmpId, RequestId, TotalDays, InYear, InMonth, [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.InYear, tmp.InMonth, tmp.[Status]
FROM SMSHRM.dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO dbo.tmpKIVLeaveBalance (EmpId, RequestId, TotalDays, InYear, [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.InYear, tmp.[Status]
FROM SMSHRM.dbo.tmpKIVLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO dbo.tmpHospitalizationLeaveBalance (EmpId, RequestId, TotalDays, [Month], [Year], [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.[Month], tmp.[Year], tmp.[Status]
FROM SMSHRM.dbo.tmpHospitalizationLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

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
FROM SMSHRM.dbo.tmpEmployeeCalendar AS tmp WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    LEFT JOIN dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    LEFT JOIN dbo.[Shift] AS s WITH (NOLOCK) ON tmp.ShiftId = s.OldShiftId
WHERE ce.CompanyId = @CompanyId
    AND s.CompanyId = @CompanyId

INSERT INTO dbo.tmpEmployeeAttendace(EmpId, WorkDate, InsertedDate)
SELECT e.EmpId, tmp.WorkDate, tmp.InsertedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM SMSHRM.dbo.tmpEmployeeAttendace AS tmp WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE ce.CompanyId = @CompanyId

INSERT INTO dbo.TimeRecord(EmpId, RecordTime, InOutType, InsertDate, ModifiedBy, ModifiedDate, CompanyId, OldId)
SELECT e.EmpId, tc.RecordTime AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, tc.InOutType,
    tc.InsertDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone, NULL, NULL, @CompanyId, tc.Id
FROM SMSHRM.dbo.TimeRecord AS tc WITH (NOLOCK)
    INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tc.EmpId = e.OldEmpId
    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE ce.CompanyId = @CompanyId

INSERT INTO dbo.TimeRecordExt(Id, IPAddress, [Platform])
SELECT tc.Id, ext.IPAddress, ext.[Platform]
FROM SMSHRM.dbo.TimeRecordExt AS ext WITH (NOLOCK)
    INNER JOIN dbo.TimeRecord AS tc WITH (NOLOCK) ON ext.Id = tc.OldId
WHERE tc.CompanyId = @CompanyId

INSERT INTO dbo.SickLeaveTrans(EmpId, RequestId, [Description], FromDate, ToDate, DeductDays, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
SELECT e.EmpId, rq.RequestId, st.[Description], st.FromDate, st.ToDate, st.DeductDays, st.IsDeleted, cr.EmpId,
    st.CreatedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone,
    md.EmpId, st.ModifiedDate AT TIME ZONE @CurrentTimeZone AT TIME ZONE @TargetTimeZone
FROM SMSHRM.dbo.SickLeaveTrans AS st WITH (NOLOCK)
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

INSERT INTO dbo.RoleFunction(CompanyId, RoleId, FunctionId, IsRead, IsHost)
SELECT @CompanyId, RoleId, FunctionId, IsRead, IsHost
FROM SMSHRM.dbo.RoleFunction WITH (NOLOCK)