/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_Delete] @RequestId BIGINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20190611@Quinn.Vo
Task: Delete keep in view request.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @PendingStatusId TINYINT = 1
		,@EmpId INT
		,@OnDate DATE

	IF NOT EXISTS (
			SELECT 1
			FROM dbo.WorkingTimeRequest WITH (NOLOCK)
			WHERE RequestId = @RequestId
				AND CurrentStatus = @PendingStatusId
			)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = 'Status is not pending, you can not delete this request.'

		RETURN;
	END

	SELECT @EmpId = EmpId
		,@OnDate = OnDate
	FROM dbo.KeepInViewRequest WITH (NOLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.WorkingTimeRequestHistory WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.KeepInViewRequestHistory WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	DELETE dbo.KeepInViewRequest WITH (ROWLOCK, UPDLOCK)
	WHERE RequestId = @RequestId

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @OnDate
		,@toDate = @OnDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1
END
