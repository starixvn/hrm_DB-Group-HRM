/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetNumberOfRequest] @EmployeeId INT
	,@FromDate DATE
	,@ToDate DATE
AS
/*
Created: Tim.Trinh@2019-09-18
Task: get number of request.
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	-- request status
	DECLARE @PendingStatusId TINYINT = 1
		,@VerifiedStatusId TINYINT = 2
		,@NotVerifiedStatusId TINYINT = 3
		,@ApprovedStatusId TINYINT = 4
		,@RejectedStatusId TINYINT = 5
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7

	SELECT COUNT(1)
	FROM dbo.WorkingTimeRequest AS wk WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON wk.RequestId = cs.RequestId
		AND wk.EmpId = cs.EmpId
	WHERE wk.EmpId = @EmployeeId
		AND CurrentStatus NOT IN (@NotVerifiedStatusId, @RejectedStatusId, @VoidStatusId)
		AND (
			cs.FromDate BETWEEN @FromDate
				AND @ToDate
			OR cs.ToDate BETWEEN @FromDate
				AND @ToDate
			)
END