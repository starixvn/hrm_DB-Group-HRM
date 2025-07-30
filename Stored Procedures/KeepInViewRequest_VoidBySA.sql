/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[KeepInViewRequest_VoidBySA] @RequestId BIGINT
	,@ActorId INT
	,@Comment NVARCHAR(500) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: 20190522@Quinn.Vo
Task: void keep in view request by SA.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @StatusId TINYINT
		,@ProcessedDate DATETIME = GETDATE()
		,@OnDate DATE
		,@EmpId INT
		-- request status
		,@ApprovedStatusId TINYINT = 4
		,@ProcessedStatusId TINYINT = 6
		,@VoidStatusId TINYINT = 7
		-- keep in view type
		,@KeepInViewByDay TINYINT = 1

	SELECT @StatusId = r.CurrentStatus
		,@OnDate = kiv.OnDate
		,@EmpId = r.EmpId
	FROM dbo.WorkingTimeRequest AS r WITH (NOLOCK)
		INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
		AND kiv.RequestId = @RequestId

	UPDATE dbo.WorkingTimeRequest WITH (ROWLOCK, UPDLOCK)
	SET CurrentStatus = @VoidStatusId
		,ModifiedBy = @ActorId
		,ModifiedDate = @ProcessedDate
	WHERE RequestId = @RequestId

	IF @StatusId IN (@ApprovedStatusId, @ProcessedStatusId)
	BEGIN
		UPDATE empca
		SET empca.IsKeepInView = 0
			,empca.ModifiedDate = @ProcessedDate
			,empca.IsOffDay = CASE WHEN kiv.KeepInViewType = @KeepInViewByDay AND empca.PreviousIsOffDay IS NOT NULL -- void request
					THEN empca.PreviousIsOffDay 
					ELSE empca.IsOffDay END
			,empca.PreviousIsOffDay = NULL
		FROM dbo.EmployeeCalendar AS empca WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.KeepInViewRequest AS kiv WITH (NOLOCK) ON empca.WorkDate = kiv.OnDate
			AND empca.EmpId = kiv.EmpId
			AND kiv.RequestId = @RequestId

		EXEC dbo.KeepInViewRequest_DeleteTrans @RequestId = @RequestId

		EXEC dbo.EmployeeAttendance_ProcessingAndInsert @EmpId
			,@OnDate
			,@OnDate
			,1
	END

	EXEC dbo.tmpEmployeeCalendar_Insert @CompanyId = @CompanyId
		,@fromDate = @OnDate
		,@toDate = @OnDate
		,@empIds = @EmpId
		,@isUpdateRequestData = 1

	EXEC dbo.KeepInViewRequest_WriteLog @RequestId = @RequestId
		,@Comment = @Comment
END

