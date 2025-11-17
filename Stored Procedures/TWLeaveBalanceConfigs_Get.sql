/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[TWLeaveBalanceConfigs_Get]
AS
/*
    Created: Jay.Do@2025-11-10
    Task: Get TW Leave Configs
    DB: bodb_HRM

    Revisions:
		20251110@Jay.Do: change DB structure [Redmine: #235678]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		[Year],
		LaborBalance,
		CompanyLeave
	FROM TWLeaveBalanceConfig
END