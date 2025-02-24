DECLARE @CompanyId SMALLINT = 3
    ,@Timezone SMALLINT = 0

INSERT INTO bodb_HRM.dbo.tmpSickLeaveBalance (EmpId, RequestId, TotalDays, [Month], [Year], [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.[Month], tmp.[Year], tmp.[Status]
FROM SMSHRM.dbo.tmpSickLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN bodb_HRM.dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN bodb_HRM.dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO bodb_HRM.dbo.tmpLeaveBalance (EmpId, RequestId, TotalDays, InYear, InMonth, [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.InYear, tmp.InMonth, tmp.[Status]
FROM SMSHRM.dbo.tmpLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN bodb_HRM.dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN bodb_HRM.dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO bodb_HRM.dbo.tmpKIVLeaveBalance (EmpId, RequestId, TotalDays, InYear, [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.InYear, tmp.[Status]
FROM SMSHRM.dbo.tmpKIVLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN bodb_HRM.dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN bodb_HRM.dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO bodb_HRM.dbo.tmpHospitalizationLeaveBalance (EmpId, RequestId, TotalDays, [Month], [Year], [Status])
SELECT e.EmpId, rq.RequestId, tmp.TotalDays, tmp.[Month], tmp.[Year], tmp.[Status]
FROM SMSHRM.dbo.tmpHospitalizationLeaveBalance AS tmp WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    INNER JOIN bodb_HRM.dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN bodb_HRM.dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE rq.CompanyId = @CompanyId
    AND ce.CompanyId = @CompanyId

INSERT INTO bodb_HRM.dbo.tmpEmployeeCalendar(EmpId, WorkDate, RequestId, RequestTypeId, ShiftId, IsOffDay, IsHoliday, IsOvertime, IsKeepInView,
    IsLeaveDay, IsLeaveOffDay, LeaveDay, LeaveTypeId, FromTime, ToTime, LeaveTypeId2, FromTime2, ToTime2, ChangeShiftTypeId, MoveOffFromDate, MoveOffToDate, ModifiedDate)
SELECT e.EmpId, tmp.WorkDate, rq.RequestId, tmp.RequestTypeId, s.ShiftId, tmp.IsOffDay, tmp.IsHoliday, tmp.IsOvertime, tmp.IsKeepInView,
    tmp.IsLeaveDay, tmp.IsLeaveOffDay, tmp.LeaveDay, tmp.LeaveTypeId,
    CASE WHEN tmp.FromTime IS NULL THEN NULL ELSE DATEADD(HOUR, @Timezone, tmp.FromTime) END,
    CASE WHEN tmp.ToTime IS NULL THEN NULL ELSE DATEADD(HOUR, @Timezone, tmp.ToTime) END,
    tmp.LeaveTypeId2,
    CASE WHEN tmp.FromTime2 IS NULL THEN NULL ELSE DATEADD(HOUR, @Timezone, tmp.FromTime2) END,
    CASE WHEN tmp.ToTime2 IS NULL THEN NULL ELSE DATEADD(HOUR, @Timezone, tmp.ToTime2) END,
    tmp.ChangeShiftTypeId, tmp.MoveOffFromDate, tmp.MoveOffToDate,
    CASE WHEN tmp.ModifiedDate IS NULL THEN NULL ELSE DATEADD(HOUR, @Timezone, tmp.ModifiedDate) END
FROM SMSHRM.dbo.tmpEmployeeCalendar AS tmp WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN bodb_HRM.dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    LEFT JOIN bodb_HRM.dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON tmp.RequestId = rq.OldRequestId
    LEFT JOIN bodb_HRM.dbo.[Shift] AS s WITH (NOLOCK) ON tmp.ShiftId = s.OldShiftId
WHERE ce.CompanyId = @CompanyId
    AND s.CompanyId = @CompanyId

INSERT INTO bodb_HRM.dbo.tmpEmployeeAttendace(EmpId, WorkDate, InsertedDate)
SELECT e.EmpId, tmp.WorkDate, CASE WHEN tmp.InsertedDate IS NULL THEN NULL ELSE DATEADD(HOUR, @Timezone, tmp.InsertedDate) END
FROM SMSHRM.dbo.tmpEmployeeAttendace AS tmp WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.Employee AS e WITH (NOLOCK) ON tmp.EmpId = e.OldEmpId
    INNER JOIN bodb_HRM.dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE ce.CompanyId = @CompanyId

INSERT INTO bodb_HRM.dbo.TimeRecord(EmpId, RecordTime, InOutType, InsertDate, ModifiedBy, ModifiedDate, CompanyId, OldId)
SELECT e.EmpId, DATEADD(HOUR, @Timezone, tc.RecordTime), tc.InOutType, DATEADD(HOUR, @Timezone, tc.InsertDate), NULL, NULL, @CompanyId, tc.Id
FROM SMSHRM.dbo.TimeRecord AS tc WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.Employee AS e WITH (NOLOCK) ON tc.EmpId = e.OldEmpId
    INNER JOIN bodb_HRM.dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
WHERE ce.CompanyId = @CompanyId

INSERT INTO bodb_HRM.dbo.TimeRecordExt(Id, IPAddress, [Platform])
SELECT tc.Id, ext.IPAddress, ext.[Platform]
FROM SMSHRM.dbo.TimeRecordExt AS ext WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.TimeRecord AS tc WITH (NOLOCK) ON ext.Id = tc.OldId
WHERE tc.CompanyId = @CompanyId

INSERT INTO bodb_HRM.dbo.SickLeaveTrans(EmpId, RequestId, [Description], FromDate, ToDate, DeductDays, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
SELECT e.EmpId, rq.RequestId, st.[Description], st.FromDate, st.ToDate, st.DeductDays, st.IsDeleted, cr.EmpId,
    CASE WHEN st.CreatedDate IS NULL THEN NULL ELSE DATEADD(HOUR, @Timezone, st.CreatedDate) END,
    md.EmpId, CASE WHEN st.ModifiedDate IS NULL THEN NULL ELSE DATEADD(HOUR, @Timezone, st.ModifiedDate) END
FROM SMSHRM.dbo.SickLeaveTrans AS st WITH (NOLOCK)
    INNER JOIN bodb_HRM.dbo.Employee AS e WITH (NOLOCK) ON st.EmpId = e.OldEmpId
    INNER JOIN bodb_HRM.dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    LEFT JOIN bodb_HRM.dbo.WorkingTimeRequest AS rq WITH (NOLOCK) ON st.RequestId = rq.OldRequestId
    LEFT JOIN bodb_HRM.dbo.Employee AS cr WITH (NOLOCK) ON st.CreatedBy = cr.OldEmpId
    LEFT JOIN bodb_HRM.dbo.CompanyEmployee AS cr_ce WITH (NOLOCK) ON cr.EmpId = cr_ce.EmpId
    AND cr_ce.CompanyId = @CompanyId
    LEFT JOIN bodb_HRM.dbo.Employee AS md WITH (NOLOCK) ON st.ModifiedBy = md.OldEmpId
    LEFT JOIN bodb_HRM.dbo.CompanyEmployee AS md_ce WITH (NOLOCK) ON md.EmpId = md_ce.EmpId
    AND md_ce.CompanyId = @CompanyId
WHERE ce.CompanyId = @CompanyId