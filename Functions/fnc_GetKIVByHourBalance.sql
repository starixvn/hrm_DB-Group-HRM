/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[fnc_GetKIVByHourBalance] (
	@EmpId INT
	,@Date DATETIME
	,@RequestId BIGINT = NULL
	)
RETURNS NUMERIC(18, 2)
/*
	Created:
	Task: get KIV Hour balance
	DB: bodb_HRM

	Revisions:
*/
AS
BEGIN
	DECLARE @KIVBalance NUMERIC(18, 2) = 0

	SELECT @KIVBalance = SUM(ISNULL(trans.CreditMinutes, 0)) - SUM(CASE 
			WHEN @RequestId IS NULL THEN ISNULL(trans.DeductMinutes, 0)
			ELSE CASE WHEN trans.RequestId = @RequestId THEN 0 ELSE ISNULL(DeductMinutes, 0) END
			END
        )
	FROM dbo.KeepInViewByHourTrans AS trans WITH (NOLOCK)
        INNER JOIN dbo.WorkingTimeRequest AS req WITH (NOLOCK) ON trans.RequestId = req.RequestId
	WHERE req.EmpId = @EmpId
		AND YEAR(trans.WorkDate) = YEAR(@Date)
        AND req.CurrentStatus NOT IN (3, 5, 7) -- NotVerified, Rejected, Void

	RETURN ISNULL(@KIVBalance, 0)
END