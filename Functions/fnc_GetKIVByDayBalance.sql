/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[fnc_GetKIVByDayBalance] (
	@EmpID INT
	,@Date DATETIME
	,@RequestId BIGINT = NULL
	,@IsGetLastYearBalance BIT = 1
	)
RETURNS NUMERIC(18, 2)
/*
	Created:
	Task: get KIV Hour balance
	DB: bodb_HRM

	Revisions:
		20251120@Mira: get default balance from last year [Redmine: #244781]
*/
AS
BEGIN
	DECLARE @KIVBalance NUMERIC(18, 2) = 0

	SELECT @KIVBalance = SUM(ISNULL(CreditDays, 0)) - SUM(CASE 
				WHEN @RequestId IS NULL THEN ISNULL(DeductDays, 0)
				ELSE CASE 
						WHEN trans.RequestId = @RequestId THEN 0
						ELSE ISNULL(DeductDays, 0)
						END
				END)
	FROM dbo.KeepInViewByDayTrans trans WITH (NOLOCK)
	INNER JOIN dbo.WorkingTimeRequest AS req WITH (NOLOCK) ON trans.RequestId = req.RequestId
	WHERE trans.EmpId = @EmpID
		AND (
				InYear = YEAR(@Date)
				OR (
					@IsGetLastYearBalance = 1 
					AND InYear = YEAR(@Date) - 1
				)
			)
		AND req.CurrentStatus NOT IN (3, 5, 7) -- NotVerified, Rejected, Void

	RETURN ISNULL(@KIVBalance, 0)
END



