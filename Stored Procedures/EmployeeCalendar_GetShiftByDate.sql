/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeCalendar_GetShiftByDate] @empId INT
	,@date DATE
	,@CompanyId SMALLINT
AS
/*
Created: Tom.Vo@2013-10-29
Task: get shift of employee on date
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ShiftId INT

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @date
		,@toDate = @date
		,@empIds = @empId

	SELECT @ShiftId = ISNULL(ShiftId, 0)
	FROM dbo.tmpEmployeeCalendar AS tec WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = @empId
	WHERE tec.EmpId = @empId
		AND WorkDate = @date
		AND ce.CompanyId = @CompanyId

	SELECT *
	FROM dbo.[Shift] WITH (NOLOCK)
	WHERE ShiftId = @ShiftId
END



