/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveType_GetAll] @CompanyId INT
	,@ExcludeNotShown bit = null
AS
/*
Created: Tom.Vo@2013-10-23
Task: Get Leave Type
DB: HRM
Original: 

Revisions:    
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT LeaveTypeId, Code, [Name], IsAnnualQuota, IsDefault, IsSalaryDeduction, IsALDeduction, IsHoliday, IsShown, IsLeaveDuringWorking, IsCalculateWoking, Color, OrderNo, [Description]
    FROM LeaveType WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND (@ExcludeNotShown IS NULL OR isShown=1)
	ORDER BY OrderNo , [Name] 
END