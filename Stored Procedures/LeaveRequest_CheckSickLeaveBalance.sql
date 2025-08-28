/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_CheckSickLeaveBalance]
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
    Task: check sick leave balance
    DB: bodb_HRM

    Revisions:
        20250429@Tim: get RefResource by CompanyId
        20250813@Jay: change db structure [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT @LeaveDays = ISNULL(@LeaveDays, 0)

	DECLARE @CompanyId SMALLINT
        ,@EnableSickLeaveBalance BIT = 0

    SELECT @CompanyId = CompanyId
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId

	SELECT @EnableSickLeaveBalance = CAST(Value AS BIT)
	FROM dbo.RefResource WITH (NOLOCK)
	WHERE CompanyId = @CompanyId
        AND RefName = 'EnableSickLeaveBalance'

	IF @EnableSickLeaveBalance = 1
		AND @LeaveDays > 0
		AND @LeaveDays > dbo.fnc_GetSickLeaveBalance(@EmpId, @Year, NULL)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'You have not enough sick leave days to request.'
	END
END
