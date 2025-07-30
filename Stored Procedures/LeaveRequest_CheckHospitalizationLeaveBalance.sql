/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_CheckHospitalizationLeaveBalance]
(
    @EmpId INT
	,@LeaveDays DECIMAL(18, 2) = NULL
	,@Year INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tim.Trinh@2021-08-25
    Task: check hospitalization leave balance
    DB: bodb_HRM

    Revisions:
        20250429@Tim: get RefResource by CompanyId
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT @LeaveDays = ISNULL(@LeaveDays, 0)

	DECLARE @CompanyId SMALLINT
        ,@EnableHospitalizationLeaveBalance BIT = 0

    SELECT @CompanyId = ce.CompanyId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

	SELECT @EnableHospitalizationLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableHospitalizationLeaveBalance'

	IF @EnableHospitalizationLeaveBalance = 1
		AND @LeaveDays > 0
		AND @LeaveDays > dbo.fnc_GetHospitalizationLeaveBalance(@EmpId, @Year, NULL)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'You have not enough hospitalization leave days to request.'
	END
END