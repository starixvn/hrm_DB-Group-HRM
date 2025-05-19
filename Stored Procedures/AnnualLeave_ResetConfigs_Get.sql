/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[AnnualLeave_ResetConfigs_Get]
AS
/*
    Created: Jay.Do@2025-05-15
    Task: Get all annual leave reset configs
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT sc.CompanyId,
		sc.[Value] AS Timeline,
		rr.[Value] AS EnableAdditionalAnnualLeaveBalance
	FROM dbo.[SystemConfigs] sc
	LEFT JOIN dbo.[RefResource] rr ON sc.CompanyId = rr.CompanyId 
		AND RefName = 'EnableAdditionalAnnualLeaveBalance'
	WHERE [Key] = 'AnnualLeaveResetTimeLine'
END