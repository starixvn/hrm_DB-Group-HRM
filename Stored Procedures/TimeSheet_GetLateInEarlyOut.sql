/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[TimeSheet_GetLateInEarlyOut]
	@EmployeeId INT
	,@workDate DATETIME
AS
/*
Created: 20151027@Quinn.Vo
Task: Get late in/ early out of employee by a date.
DB: NexEPA
Original: 

Revisions:  
        20250813@Jay: change db structure [Redmine: #235678]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		att.AttendanceDate AS WorkDate
		,att.LateIn
		,att.EarlyOut
		,ce.EmpId
		,ce.NickName
		,e.FullName
	FROM dbo.EmployeeAttendance AS att WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON att.EmpId = ce.EmpId
		INNER JOIN dbo.Employee e (NOLOCK) ON e.UserId = ce.UserId
	WHERE att.EmpId = @EmployeeId 
		AND DATEDIFF(DD, AttendanceDate, @workDate) = 0
END

