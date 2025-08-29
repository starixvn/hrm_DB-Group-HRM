/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[FnB_EmployeeCalendar_GetByLastModifiedDate]
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
	Created: 20141002@Quinn.Vo
	Task: Get employee calendar from change date
	DB: NexEPA
	Original: 

	Revisions:  
		- 20250813@Henry.Dinh: migrate data transfer feature id: #233310 
		- 20250829@Jay.Do: restructure: #233310 
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpEmployeeCalendarChange
	(
		EmpId INT,
		WorkDate DATE
	)

	INSERT INTO #tmpEmployeeCalendarChange(EmpId, WorkDate)
	SELECT e.EmpId
	   ,CAST([WorkDate] AS DATE)
	FROM dbo.EmployeeCalendar AS e WITH (NOLOCK)
		INNER JOIN CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR e.ModifiedDate > @LastModifiedDate)
	UNION 
	SELECT ca.[EmpId]
	   ,[WorkDate]
	FROM dbo.tmpEmployeeCalendar AS ca WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ca.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR ca.ModifiedDate > @LastModifiedDate)
	UNION
	SELECT ea.EmpId, CAST(AttendanceDate AS DATE)
	FROM dbo.EmployeeAttendance AS ea
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = ea.EmpId
	WHERE ce.CompanyId = @CompanyId 
		AND (@LastModifiedDate IS NULL OR InsertDate > @LastModifiedDate)
	UNION 
	SELECT wfh.EmpId, [WorkDate]
	FROM dbo.tmpEmployeeCalendar AS tmp WITH (NOLOCK)
		INNER JOIN dbo.EmployeeWorkFromHome AS wfh WITH (NOLOCK) ON tmp.WorkDate BETWEEN wfh.FromDate AND wfh.ToDate
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = tmp.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND (@LastModifiedDate IS NULL OR wfh.ModifiedDate > @LastModifiedDate)

	SELECT 
		a.UserId,
		a.WorkDate,
		a.[ShiftId],
		a.[IsHoliday],
		a.IsOffDay,
		a.IsLeaveDay,
		a.LeaveTypeId,
		a.LeaveDay,
	CASE WHEN a.ModifiedDate IS NULL THEN '2023-01-01' ELSE a.ModifiedDate END AS ModifiedDate,
	HasCheckIn
	FROM 
	(
	SELECT
	  tcl.[WorkDate]
      ,ce.EmpId AS UserId 
      ,CASE WHEN s.OldShiftId IS NOT NULL THEN s.OldShiftId ELSE s.ShiftID END AS ShiftID
      ,tcl.[IsHoliday]
      ,CAST(CASE WHEN (tcl.[IsOffDay] = 1 OR wfh.EmployeeWorkFromHomeId IS NOT NULL) THEN 1 ELSE 0 END AS BIT) AS IsOffDay
	   ,CASE WHEN tcl.EmpId IS NULL THEN cl.IsLeaveDay ELSE tcl.[IsLeaveDay] END AS IsLeaveDay
      ,CASE WHEN tcl.EmpId IS NULL THEN cl.[LeaveTypeId] ELSE tcl.[LeaveTypeId] END AS LeaveTypeId
      ,CASE WHEN tcl.EmpId IS NULL THEN cl.[LeaveDay] ELSE tcl.[LeaveDay] END AS LeaveDay
	  ,CASE WHEN cl.ModifiedDate > ISNULL(tcl.ModifiedDate, '2010-01-01') AND cl.ModifiedDate > ISNULL(att.InsertDate, '2010-01-01') THEN cl.ModifiedDate
		WHEN  ISNULL(tcl.ModifiedDate, '2010-01-01') > cl.ModifiedDate AND ISNULL(tcl.ModifiedDate, '2010-01-01')  > ISNULL(att.InsertDate, '2010-01-01') THEN tcl.ModifiedDate
		ELSE att.InsertDate END AS ModifiedDate
	  ,CAST(CASE WHEN att.InFixed IS NULL THEN 0 ELSE 1 END AS BIT) AS HasCheckIn

	FROM #tmpEmployeeCalendarChange AS tmp WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = tmp.EmpId
		INNER JOIN dbo.EmployeeCalendar AS cl WITH (NOLOCK) ON tmp.EmpId = cl.EmpId AND tmp.WorkDate = cl.WorkDate
		INNER JOIN dbo.tmpEmployeeCalendar as tcl  ON tcl.EmpId = tmp.EmpId AND tcl.WorkDate = tmp.WorkDate
		LEFT JOIN dbo.EmployeeAttendance AS att ON tmp.EmpId = att.EmpId AND tmp.WorkDate = att.AttendanceDate
		LEFT JOIN dbo.EmployeeWorkFromHome AS wfh ON tmp.EmpId = wfh.EmpId AND tmp.WorkDate BETWEEN wfh.FromDate AND wfh.ToDate
		LEFT JOIN dbo.Shift AS s ON tcl.ShiftId = s.ShiftID AND s.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId
	) AS a
	WHERE a.WorkDate > DATEADD(dd, -30, GETDATE())
	DROP TABLE #tmpEmployeeCalendarChange
END