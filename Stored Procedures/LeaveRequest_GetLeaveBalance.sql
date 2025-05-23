/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_GetLeaveBalance]
(
    @EmpId INT
    ,@RequestId BIGINT = NULL
    ,@EffectedDay DATE = NULL
)
AS
/*
    Created: Quinn.Vo@20190417
    Task: Get Avaible Balance Leave From RequestId
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @EffectedDay IS NULL
	BEGIN
		SELECT @EffectedDay = CONVERT(DATETIME, CONVERT(NVARCHAR(10), YEAR(GETDATE())) + '/01/01')
	END

	DECLARE @KIVBalance NUMERIC(18, 2)
		,@KIVByHourBalance NUMERIC(18, 2)
		,@LeaveBalanceDay NUMERIC(18, 2)
		,@CurrenLeaveDay NUMERIC(18, 2)
		,@WeekedLeaveDayTaken NUMERIC(18, 2)
		,@HospitalizationLeaveBalance NUMERIC(18, 2)
		,@SickLeaveBalance NUMERIC(18, 2)

	SELECT @KIVBalance = dbo.fnc_GetKIVByDayBalance(@EmpId, @EffectedDay, @RequestId)
		,@KIVByHourBalance = dbo.fnc_GetKIVByHourBalance(@EmpId, @EffectedDay, @RequestId)
		,@LeaveBalanceDay = dbo.fnc_GetAnnualLeaveBalance(@EmpId, @EffectedDay, @RequestId)
		,@CurrenLeaveDay = dbo.fnc_GetAnnualLeaveBalanceByDate(@EmpId, @EffectedDay, @RequestId)
		,@WeekedLeaveDayTaken = dbo.fnc_GetWeekendLeaveTaken(@EmpId, @EffectedDay, @RequestId)
		,@HospitalizationLeaveBalance = dbo.fnc_GetHospitalizationLeaveBalance(@EmpId, YEAR(@EffectedDay), @RequestId)
		,@SickLeaveBalance = dbo.fnc_GetSickLeaveBalance(@EmpId, YEAR(@EffectedDay), @RequestId)

	SELECT @EmpId AS EmployeeId
		,@LeaveBalanceDay AS AnnualBalance
		,@KIVBalance AS KeepInViewBalance
		,@KIVByHourBalance AS KeepInViewByHourBalance
		,@CurrenLeaveDay AS CurrentLeaveBalanceDay
		,@WeekedLeaveDayTaken AS WeekedLeaveDayTaken
		,@HospitalizationLeaveBalance AS HospitalizationLeaveBalance
		,@SickLeaveBalance AS SickLeaveBalance
END