/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[FnB_Shift_GetAll]
	@CompanyId SMALLINT
AS
/*
Created: 20230220@Quinn.Vo
Task: Get last modified date
DB: FBM
Original: 

Revisions:  
Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON;

	SELECT ShiftId
	    ,Code
	    ,[Name]
	    ,BeginCheckInTime
	    ,EndCheckInTime
	    ,BeginCheckOutTime
	    ,EndCheckOutTime
	    ,IsInAfterDay
	    ,IsOutAfterDay
	    ,IsDisabled
		,OldShiftId
	FROM dbo.[Shift] WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
END


