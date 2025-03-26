/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CheckInOutRequest_UpdateDiscipline] @RequestId BIGINT
	,@ActorId INT
	,@RequestStatusId TINYINT
	,@DisciplineXml NVARCHAR(MAX) = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20191203@Tim.Trinh
Task: update discipline.
DB: HRM

Revisions:
Param's Explanation:
    @DisciplineXml:
        <Root>
            <Row WorkDate='' EmployeeId='' DisciplineTypeId='' IsIgnored='' IsConfirmed='' />
        </Root>
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE()
		,@ReasonId TINYINT
		,@MissingCheckInOutDisciplineTypeId TINYINT = 2
		-- reason
		,@VanLateReasonId TINYINT = 1
		,@BusinessTripReasonId TINYINT = 2
		-- request status
		,@PendingStatusId TINYINT = 1
		,@NotVerifiedStatusId TINYINT = 3
		,@RejectedStatusId TINYINT = 5
		,@VoidStatusId TINYINT = 7
	DECLARE @tblDiscipline TABLE (
		WorkDate DATE
		,EmpId INT
		,DisciplineTypeId INT
		,IsIgnored BIT
		,IsConfirmed BIT
		)

	-- reset/reject request
	IF @RequestStatusId = @PendingStatusId
		OR @RequestStatusId = @NotVerifiedStatusId
		OR @RequestStatusId = @RejectedStatusId
		OR @RequestStatusId = @VoidStatusId
	BEGIN
		DELETE did
		FROM dbo.DisciplineIgnoreDetail AS did WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.DisciplineRequestTrans AS dtran WITH (NOLOCK) ON did.EmpId = dtran.EmpId
			AND did.DisciplineTypeId = dtran.DisciplineTypeId
			AND did.WorkDate = dtran.WorkDate
		WHERE dtran.RequestId = @RequestId

		EXEC dbo.DisciplineRequestTrans_Delete @RequestId = @RequestId

		UPDATE dis
		SET dis.IsMissingCheckInOut = CASE 
				WHEN @RequestStatusId = @PendingStatusId THEN 1
				ELSE 0
				END
			,dis.IsOutOfControlReason = CASE 
				WHEN outofctrl.EmpId IS NULL
					OR (
						outofctrl.IsOutOfControlChangeShift = 0
						AND outofctrl.IsOutOfControlLateIn = 0
						AND outofctrl.IsOutOfControlEarlyOut = 0
						AND outofctrl.IsOutOfControlAbsent = 0
						AND outofctrl.IsOutOfControlUnpaidLeave = 0
						AND outofctrl.IsOutOfControlWorkingUnderTime = 0
						AND outofctrl.IsOutOfControlUnpaidLeaveAbsent = 0
						AND outofctrl.IsOutOfControlUnplannedLeave = 0
						AND outofctrl.IsOutOfControlWeekendLeave = 0
						) THEN 0
				ELSE dis.IsOutOfControlReason
				END
			,dis.IsDeleted = CASE 
				WHEN @RequestStatusId = @PendingStatusId THEN 1
				ELSE dis.IsDeleted
				END
			,dis.ModifiedBy = @ActorId
			,dis.ModifiedDate = @ModifiedDate
		FROM dbo.Discipline AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.CheckInOutRequest AS cio WITH (NOLOCK) ON cio.RequestId = @RequestId
			AND dis.EmpId = cio.EmpId
			AND dis.WorkDate = cio.OnDate
			LEFT JOIN dbo.DisciplineOutOfControl AS outofctrl WITH (NOLOCK) ON dis.EmpId = outofctrl.EmpId
			AND dis.WorkDate = outofctrl.WorkDate
		WHERE EXISTS (
				SELECT 1
				FROM dbo.Employee AS emp WITH (NOLOCK)
					INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
					INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON emp.GroupId = drule.GroupId
					AND drule.DisciplineTypeId = @MissingCheckInOutDisciplineTypeId
					AND empsum.IsLocal = drule.IsLocal
					AND drule.Value = 1
				WHERE dis.EmpId = emp.EmpId
				)

		UPDATE dis
		SET dis.IsIgnoredMissingCheckInOut = 0
		FROM dbo.DisciplineIgnore AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.CheckInOutRequest AS cio WITH (NOLOCK) ON cio.RequestId = @RequestId
			AND dis.EmpId = cio.EmpId
			AND dis.WorkDate = cio.OnDate
		WHERE EXISTS (
				SELECT 1
				FROM dbo.Employee AS emp WITH (NOLOCK)
					INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
					INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON emp.GroupId = drule.GroupId
					AND drule.DisciplineTypeId = @MissingCheckInOutDisciplineTypeId
					AND empsum.IsLocal = drule.IsLocal
					AND drule.Value = 1
				WHERE dis.EmpId = emp.EmpId
				)

		UPDATE dis
		SET dis.IsOutOfControlMissingCheckInOut = 0
		FROM dbo.DisciplineOutOfControl AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.CheckInOutRequest AS cio WITH (NOLOCK) ON cio.RequestId = @RequestId
			AND dis.EmpId = cio.EmpId
			AND dis.WorkDate = cio.OnDate
		WHERE EXISTS (
				SELECT 1
				FROM dbo.Employee AS emp WITH (NOLOCK)
					INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
					INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON emp.GroupId = drule.GroupId
					AND drule.DisciplineTypeId = @MissingCheckInOutDisciplineTypeId
					AND empsum.IsLocal = drule.IsLocal
					AND drule.Value = 1
				WHERE dis.EmpId = emp.EmpId
				)

		RETURN
	END

	-- approve request
	IF ISNULL(@DisciplineXml, '') <> ''
	BEGIN
		BEGIN TRY
			DECLARE @DocHandler INT

			EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@DisciplineXml

			INSERT INTO @tblDiscipline (
				WorkDate
				,EmpId
				,DisciplineTypeId
				,IsIgnored
				,IsConfirmed
				)
			SELECT DISTINCT WorkDate
				,EmployeeId
				,DisciplineTypeId
				,IsIgnored
				,IsConfirmed
			FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (WorkDate DATE, EmployeeId INT, DisciplineTypeId INT, IsIgnored BIT, IsConfirmed BIT) AS Data

			EXEC sp_xml_removedocument @DocHandler
		END TRY

		BEGIN CATCH
			SELECT @ErrCode = 1
				,@ErrMsg = ERROR_MESSAGE()

			RETURN
		END CATCH
	END

	BEGIN TRY
		IF EXISTS (
				SELECT 1
				FROM @tblDiscipline
				)
		BEGIN
			SELECT @ReasonId = ReasonId
			FROM dbo.CheckInOutRequest WITH (NOLOCK)
			WHERE RequestId = @RequestId

			INSERT INTO dbo.DisciplineRequestTrans (
				EmpId
				,WorkDate
				,RequestId
				,DisciplineTypeId
				,IsIgnored
				,IsOutOfControl
				,ModifiedBy
				,ModifiedDate
				)
			SELECT EmpId
				,WorkDate
				,@RequestId
				,DisciplineTypeId
				,IsIgnored
				,0
				,@ActorId
				,@ModifiedDate
			FROM @tblDiscipline
			WHERE @ReasonId NOT IN (@VanLateReasonId, @BusinessTripReasonId)

			-- update
			UPDATE dis
			SET dis.IsMissingCheckInOut = 1
				,dis.IsDeleted = 0
				,dis.ModifiedBy = @ActorId
				,dis.ModifiedDate = @ModifiedDate
			FROM dbo.Discipline AS dis WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
				AND dis.EmpId = tbl.EmpId
				AND tbl.DisciplineTypeId = @MissingCheckInOutDisciplineTypeId
			WHERE @ReasonId NOT IN (@VanLateReasonId, @BusinessTripReasonId)

			UPDATE dis
			SET dis.IsIgnoredMissingCheckInOut = tbl.IsIgnored
			FROM dbo.DisciplineIgnore AS dis WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
				AND dis.EmpId = tbl.EmpId
				AND tbl.DisciplineTypeId = 2
			WHERE @ReasonId NOT IN (@VanLateReasonId, @BusinessTripReasonId)

			UPDATE dis
			SET dis.IsOutOfControlMissingCheckInOut = 0
			FROM dbo.DisciplineOutOfControl AS dis WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
				AND dis.EmpId = tbl.EmpId
				AND tbl.DisciplineTypeId = @MissingCheckInOutDisciplineTypeId
			WHERE @ReasonId NOT IN (@VanLateReasonId, @BusinessTripReasonId)

			-- insert
			INSERT INTO dbo.Discipline (
				EmpId
				,WorkDate
				,IsMissingCheckInOut
				,IsOutOfControlReason
				,ModifiedBy
				,ModifiedDate
				)
			SELECT EmpId
				,WorkDate
				,1
				,0
				,@ActorId
				,@ModifiedDate
			FROM @tblDiscipline AS tbl
			WHERE tbl.DisciplineTypeId = @MissingCheckInOutDisciplineTypeId
				AND @ReasonId NOT IN (@VanLateReasonId, @BusinessTripReasonId)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.Discipline AS dis WITH (NOLOCK)
					WHERE dis.EmpId = tbl.EmpId
						AND dis.WorkDate = tbl.WorkDate
					)

			INSERT INTO dbo.DisciplineIgnore (
				EmpId
				,WorkDate
				,IsIgnoredMissingCheckInOut
				)
			SELECT EmpId
				,WorkDate
				,IsIgnored
			FROM @tblDiscipline AS tbl
			WHERE tbl.DisciplineTypeId = @MissingCheckInOutDisciplineTypeId
				AND @ReasonId NOT IN (@VanLateReasonId, @BusinessTripReasonId)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.DisciplineIgnore AS dis WITH (NOLOCK)
					WHERE dis.EmpId = tbl.EmpId
						AND dis.WorkDate = tbl.WorkDate
					)

			INSERT INTO dbo.DisciplineOutOfControl (
				EmpId
				,WorkDate
				,IsOutOfControlMissingCheckInOut
				)
			SELECT EmpId
				,WorkDate
				,0
			FROM @tblDiscipline AS tbl
			WHERE tbl.DisciplineTypeId = @MissingCheckInOutDisciplineTypeId
				AND @ReasonId NOT IN (@VanLateReasonId, @BusinessTripReasonId)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.DisciplineOutOfControl AS dis WITH (NOLOCK)
					WHERE dis.EmpId = tbl.EmpId
						AND dis.WorkDate = tbl.WorkDate
					)
		END
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 1
			,@ErrMsg = ERROR_MESSAGE()
	END CATCH
END