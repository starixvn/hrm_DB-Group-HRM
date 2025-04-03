/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Shift_GetShifts] @CompanyId SMALLINT
AS
/*
Created: Tom.Vo@2013-10-23
Task: get all shifts
DB: HRM
Original:

Revisions:
*/
BEGIN
    SET NOCOUNT ON;

    SELECT [ShiftId]
        ,[Code]
        ,[Name]
        ,[BeginCheckInTime]
        ,[EndCheckInTime]
        ,[BeginCheckOutTime]
        ,[EndCheckOutTime]
        ,[BreakTimeMins]
        ,[OrderNo]
        ,[BeginBreakTime]
        ,[EndBreakTime]
	    ,CrossDay
	    ,Color
	    ,TotalHours
	    ,IsDisabled
	    ,IsInAfterDay
	    ,IsOutAfterDay
    FROM dbo.[Shift] WITH(NOLOCK)
    WHERE CompanyId = @CompanyId
    ORDER BY [Code]
END