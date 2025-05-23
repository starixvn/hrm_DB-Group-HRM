/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SystemSetting_Get]
(
    @CompanyId SMALLINT
)
AS
/*
    Created: Tim.Trinh@2021-08-24
    Task: get system setting
    DB: bodb_HRM

    Revisions:
        20250429@Tim: add param @CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EnableHospitalizationLeaveBalance BIT = 0
		,@EnableSickLeaveBalance BIT = 0
        ,@EnableLimitUseAnnualLeaveBalance BIT = 0

	SELECT @EnableHospitalizationLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableHospitalizationLeaveBalance'

	SELECT @EnableSickLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableSickLeaveBalance'

    SELECT @EnableLimitUseAnnualLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'LimitUseAnnualLeaveBalance'

	SELECT @EnableHospitalizationLeaveBalance AS EnableHospitalizationLeaveBalance
		,@EnableSickLeaveBalance AS EnableSickLeaveBalance
        ,@EnableLimitUseAnnualLeaveBalance AS EnableLimitUseAnnualLeaveBalance
END