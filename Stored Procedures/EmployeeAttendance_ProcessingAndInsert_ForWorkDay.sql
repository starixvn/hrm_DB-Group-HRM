/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsert_ForWorkDay] @empId INT
	,@fromTime DATETIME
	,@toTime DATETIME
AS
/*
Created:
Task:
DB: HRM

Revisions:

*/
BEGIN
	UPDATE att
	SET att.ShiftId = c.ShiftID
		,att.InFixed = c.CheckIn
		,att.OutFixed = c.CheckOut
		,att.ExpectedInTime = c.ExpectedInTime
		,att.ExpectedOutTime = c.ExpectedOutTime
		,att.LateIn = CASE 
			WHEN c.LateIn <= 0 THEN 0
			ELSE c.LateIn
			END
		,att.EarlyOut = CASE 
			WHEN c.EarlyOut <= 0 THEN 0
			ELSE c.EarlyOut
			END
		,att.LeaveTypeId = NULL
		,att.Absence = c.Absence
		,att.TotalWorkHours = CASE 
			WHEN c.IsValid = 1 THEN (CASE 
					WHEN c.CheckIn < c.ExpectedInTime THEN ((DATEDIFF(mi, c.ExpectedInTime, c.CheckOut) - ISNULL(c.BreakTimeMins, 0)) / 60.0)
					ELSE (DATEDIFF(mi, c.CheckIn, c.CheckOut) - ISNULL(c.BreakTimeMins, 0)) / 60.0 END
					)
			ELSE NULL
			END
		,att.LeaveDay = NULL
		,att.InsertDate = GETDATE()
		,att.LeaveTypeId2 = NULL
	FROM (
		SELECT b.EmpId
			,b.WorkDate
			,b.Code
			,b.ShiftID
			,b.CheckIn
			,b.CheckOut
			,CASE 
				WHEN (
						b.CheckIn IS NOT NULL
						AND b.CheckOut IS NOT NULL
						AND b.CheckIn < b.CheckOut
						) THEN 1
				ELSE 0
				END AS IsValid
			,CASE 
				WHEN b.CheckIn IS NULL THEN 0
				ELSE DATEDIFF(MINUTE, b.ExpectedInTime, b.CheckIn)
				END AS LateIn
			,CASE 
				WHEN b.CheckOut IS NULL THEN 0
				ELSE DATEDIFF(MINUTE, b.CheckOut, b.ExpectedOutTime)
				END AS EarlyOut
			,b.ExpectedInTime
			,b.ExpectedOutTime
			,b.BreakTimeMins
			,b.Absence
		FROM (
			SELECT a.EmpId
				,a.WorkDate
				,a.Code
				,a.ShiftID
				,(CASE 
					WHEN a.RequestedCheckinTime IS NULL THEN a.CheckIn
					ELSE a.RequestedCheckinTime END
					) CheckIn
				,(CASE 
					WHEN a.RequestedCheckoutTime IS NULL THEN a.CheckOut
					ELSE a.RequestedCheckoutTime END
					) CheckOut
				,a.ExpectedInTime
				,a.ExpectedOutTime
				,a.BreakTimeMins
				,CASE 
					WHEN (
							a.IsOffDay = 1
							OR a.IsHoliday = 1
							OR (
								a.IsLeaveDay = 1
								AND a.LeaveDay = 1
								)
							OR (
								a.CheckIn IS NULL
								AND a.CheckOut IS NULL
								)
							) THEN 1
					ELSE 0
					END AS Absence
			FROM (
				SELECT cl.EmpId
					,cl.WorkDate
					,sh.ShiftID
					,sh.Code
					,sh.BeginCheckInTime
					,sh.BeginCheckOutTime
					,sh.IsInAfterDay
					,sh.IsOutAfterDay
					,cl.RequestedCheckinTime
					,cl.RequestedCheckoutTime
					,cl.LateIn
					,cl.EarlyOut
					,cl.IsHoliday
					,cl.IsOffDay
					,cl.IsLeaveDay
					,cl.LeaveTypeId
					,cl.IsKeepInView
					,cl.LeaveDay
					,sh.BreakTimeMins
					,CASE 
						WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
						ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111)
						END + ' ' + sh.BeginCheckInTime AS ExpectedInTime
					,CASE 
						WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
						ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111)
						END + ' ' + sh.BeginCheckOutTime AS ExpectedOutTime
					,(
						SELECT MIN(RecordTime)
						FROM dbo.TimeRecord WITH (NOLOCK)
						WHERE InOutType = 0
							AND EmpID = cl.EmpId
							AND RecordTime BETWEEN DATEADD(mi, - 480, (CASE 
											WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
											ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckInTime
											))
								AND (CASE 
										WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
										ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckOutTime
										)
						) AS CheckIn
					,(
						SELECT MAX(RecordTime)
						FROM dbo.TimeRecord WITH (NOLOCK)
						WHERE InOutType = 1
							AND EmpID = cl.EmpId
							AND RecordTime BETWEEN (CASE 
										WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
										ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckInTime
										)
								AND DATEADD(mi, 480, (CASE 
											WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
											ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckOutTime
											))
						) AS CheckOut
				FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
					INNER JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
				WHERE cl.EmpId = @empId
                    AND ISNULL(cl.LeaveDay, 0) = 0
					AND DATEDIFF(DD, @fromTime, WorkDate) >= 0
					AND DATEDIFF(DD, WorkDate, @toTime) >= 0
				) AS a
			) AS b
		) AS c
		INNER JOIN dbo.EmployeeAttendance AS att WITH (ROWLOCK) ON c.EmpId = att.EmpId
		AND c.WorkDate = att.AttendanceDate

	INSERT INTO dbo.EmployeeAttendance (
		[EmpId]
		,[AttendanceDate]
		,[ShiftId]
		,[InFixed]
		,[OutFixed]
		,[ExpectedInTime]
		,[ExpectedOutTime]
		,[LateIn]
		,[EarlyOut]
		,[Absence]
		,[TotalWorkHours]
		,[InsertDate]
		)
	SELECT c.EmpId
		,c.WorkDate
		,c.ShiftID
		,c.CheckIn
		,c.CheckOut
		,c.ExpectedInTime
		,c.ExpectedOutTime
		,CASE 
			WHEN c.LateIn <= 0 THEN 0
			ELSE c.LateIn
			END AS LateIn
		,CASE 
			WHEN c.EarlyOut <= 0 THEN 0
			ELSE c.EarlyOut
			END AS EarlyOut
		,c.Absence
		,CAST((CASE 
				WHEN c.IsValid = 1 THEN (CASE 
						WHEN c.CheckIn < c.ExpectedInTime THEN ((DATEDIFF(mi, c.ExpectedInTime, c.CheckOut) - ISNULL(c.BreakTimeMins, 0)) / 60.0)
						ELSE (DATEDIFF(mi, c.CheckIn, c.CheckOut) - ISNULL(c.BreakTimeMins, 0)) / 60.0 END
						)
				ELSE NULL END
				) AS DECIMAL(18, 2)) TotalHours
		,GETDATE()
	FROM (
		SELECT b.EmpId
			,b.WorkDate
			,b.Code
			,b.ShiftID
			,b.CheckIn
			,b.CheckOut
			,CASE 
				WHEN (
						b.CheckIn IS NOT NULL
						AND b.CheckOut IS NOT NULL
						AND b.CheckIn < b.CheckOut
						) THEN 1
				ELSE 0
				END AS IsValid
			,CASE 
				WHEN b.CheckIn IS NULL THEN 0
				ELSE DATEDIFF(MINUTE, b.ExpectedInTime, b.CheckIn)
				END AS LateIn
			,CASE 
				WHEN b.CheckOut IS NULL THEN 0
				ELSE DATEDIFF(MINUTE, b.CheckOut, b.ExpectedOutTime)
				END AS EarlyOut
			,b.ExpectedInTime
			,b.ExpectedOutTime
			,b.BreakTimeMins
			,b.Absence
		FROM (
			SELECT a.EmpId
				,a.WorkDate
				,a.Code
				,a.ShiftID
				,(CASE 
					WHEN a.RequestedCheckinTime IS NULL THEN a.CheckIn
					ELSE a.RequestedCheckinTime END
					) CheckIn
				,(CASE 
					WHEN a.RequestedCheckoutTime IS NULL THEN a.CheckOut
					ELSE a.RequestedCheckoutTime END
					) CheckOut
				,a.ExpectedInTime
				,a.ExpectedOutTime
				,a.BreakTimeMins
				,CASE 
					WHEN (
							a.IsOffDay = 1
							OR a.IsHoliday = 1
							OR (
								a.IsLeaveDay = 1
								AND a.LeaveDay = 1
								)
							OR (
								a.CheckIn IS NULL
								AND a.CheckOut IS NULL
								)
							) THEN 1
					ELSE 0
					END AS Absence
			FROM (
				SELECT cl.EmpId
					,cl.WorkDate
					,sh.ShiftID
					,sh.Code
					,sh.BeginCheckInTime
					,sh.BeginCheckOutTime
					,sh.IsInAfterDay
					,sh.IsOutAfterDay
					,cl.RequestedCheckinTime
					,cl.RequestedCheckoutTime
					,cl.LateIn
					,cl.EarlyOut
					,cl.IsHoliday
					,cl.IsOffDay
					,cl.IsLeaveDay
					,cl.LeaveTypeId
					,cl.IsKeepInView
					,cl.LeaveDay
					,sh.BreakTimeMins
					,CASE 
						WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
						ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111)
						END + ' ' + sh.BeginCheckInTime AS ExpectedInTime
					,CASE 
						WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
						ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111)
						END + ' ' + sh.BeginCheckOutTime AS ExpectedOutTime
					,(
						SELECT MIN(RecordTime)
						FROM dbo.TimeRecord WITH (NOLOCK)
						WHERE InOutType = 0
							AND EmpID = cl.EmpId
							AND RecordTime BETWEEN DATEADD(mi, - 480, (CASE 
											WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
											ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckInTime
											))
								AND (CASE 
										WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
										ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckOutTime
										)
						) AS CheckIn
					,(
						SELECT MAX(RecordTime)
						FROM dbo.TimeRecord WITH (NOLOCK)
						WHERE InOutType = 1
							AND EmpID = cl.EmpId
							AND RecordTime BETWEEN (CASE 
										WHEN sh.IsInAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
										ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckInTime
										)
								AND DATEADD(mi, 480, (CASE 
											WHEN sh.IsOutAfterDay = 0 THEN CONVERT(VARCHAR(10), cl.WorkDate, 111)
											ELSE CONVERT(VARCHAR(10), DATEADD(DD, 1, cl.WorkDate), 111) END + ' ' + sh.BeginCheckOutTime
											))
						) AS CheckOut
				FROM dbo.EmployeeCalendar AS cl WITH (NOLOCK)
					INNER JOIN dbo.[Shift] AS sh WITH (NOLOCK) ON cl.ShiftId = sh.ShiftID
				WHERE cl.EmpId = @empId
                    AND ISNULL(cl.LeaveDay, 0) = 0
					AND DATEDIFF(DD, @fromTime, WorkDate) >= 0
					AND DATEDIFF(DD, WorkDate, @toTime) >= 0
				) AS a
			) AS b
		) AS c
	WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
        WHERE c.EmpId = att.EmpId
		    AND c.WorkDate = att.AttendanceDate
        )
END