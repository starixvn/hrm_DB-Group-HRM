/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[HospitalLeave_Insert] @RequestId BIGINT
	,@IsHospitalApplication BIT = NULL
AS
/*
Created: 20230929@Lilac.Nguyen
Task: Insert Hospital Leave.
DB: HRM
Original:

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @HospitalizationLeaveTypeId INT = 39
		,@GeneralLeaveTypeId INT = 0
		,@LeaveTypeId INT

	SELECT @LeaveTypeId = lr.LeaveType
	FROM dbo.LeaveRequest AS lr WITH (NOLOCK)
	WHERE lr.RequestId = @RequestId

	IF EXISTS (
			SELECT 1
			FROM dbo.HospitalLeave WITH (NOLOCK)
			WHERE RequestId = @RequestId
			)
	BEGIN
		DELETE
		FROM dbo.HospitalLeave WITH (ROWLOCK, UPDLOCK)
		WHERE RequestId = @RequestId
	END

	IF @LeaveTypeId = @GeneralLeaveTypeId
	BEGIN
		IF EXISTS (
				SELECT lrd.LeaveType
				FROM LeaveRequest AS lr WITH (NOLOCK)
					INNER JOIN dbo.LeaveRequestDetail AS lrd WITH (NOLOCK) ON lrd.RequestId = lr.RequestId
				WHERE lr.RequestId = @RequestId
					AND lrd.LeaveType = @HospitalizationLeaveTypeId
				)
		BEGIN
			INSERT INTO dbo.HospitalLeave (
				[RequestId]
				,[IsHospitalApplication]
				)
			VALUES (
				@RequestId
				,0
				)
		END
	END
	ELSE
	BEGIN
		IF @LeaveTypeId = @HospitalizationLeaveTypeId
		BEGIN
			INSERT INTO dbo.HospitalLeave (
				[RequestId]
				,[IsHospitalApplication]
				)
			VALUES (
				@RequestId
				,@IsHospitalApplication
				)
		END
	END
END

