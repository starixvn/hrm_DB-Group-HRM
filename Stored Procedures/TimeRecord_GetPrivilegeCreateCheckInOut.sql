/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[TimeRecord_GetPrivilegeCreateCheckInOut] @EmpId INT,
	@CurrentDate DATETIME
AS
/*
Created: 20210527@Quinn.Vo
Task: Get Privilege Create Check In/Out Record.
DB: HRM
Original: 

Revisions:  
    - 20250716@Jay: Fix check by server timezone [Redmine: #228715]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsPrivilegeCreateCheckInOut BIT = 0

	IF (EXISTS(SELECT 1 FROM dbo.EmployeeWorkFromHome WITH (NOLOCK) 
		WHERE EmpId = @EmpId 
			AND @CurrentDate > FromDate 
			AND DATEADD (DD, -2, @CurrentDate) < ToDate))
	BEGIN
		SET @IsPrivilegeCreateCheckInOut = 1
	END

	SELECT @IsPrivilegeCreateCheckInOut
END

GO