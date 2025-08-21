/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LateInEarlyOutRequest_UpdateDiscipline] @RequestId BIGINT
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
		- 20250821@Jay: restructure for transfer [Redmine: #235678]
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
		-- late in/early out reason
		,@ManagementAllowReasonId TINYINT = 1
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
			INNER JOIN DisciplineRequestTrans AS dtran WITH (NOLOCK) ON did.EmpId = dtran.EmpId
			AND did.DisciplineTypeId = dtran.DisciplineTypeId
			AND did.WorkDate = dtran.WorkDate
		WHERE dtran.RequestId = @RequestId

		EXEC dbo.DisciplineRequestTrans_Delete @RequestId = @RequestId

		UPDATE dis
		SET dis.IsLateIn = CASE 
				WHEN r.RequestType = 3 THEN CASE 
						WHEN @RequestStatusId = @PendingStatusId THEN 1
						ELSE 0
						END
				ELSE dis.IsLateIn
				END
			,dis.IsEarlyOut = CASE 
				WHEN r.RequestType = 4 THEN CASE 
						WHEN @RequestStatusId = @PendingStatusId THEN 1
						ELSE 0
						END
				ELSE dis.IsEarlyOut
				END
			,dis.IsOutOfControlReason = CASE 
				WHEN outofctrl.EmpId IS NULL
					OR (
						outofctrl.IsOutOfControlChangeShift = 0
						AND outofctrl.IsOutOfControlMissingCheckInOut = 0
						AND (
							(
								r.RequestType = 3
								AND outofctrl.IsOutOfControlEarlyOut = 0
								)
							OR (
								r.RequestType = 4
								AND outofctrl.IsOutOfControlLateIn = 0
								)
							)
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
			INNER JOIN dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK) ON lieo.RequestId = @RequestId
			AND dis.EmpId = lieo.EmpId
			AND dis.WorkDate = lieo.OnDate
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lieo.RequestId = r.RequestId
			LEFT JOIN dbo.DisciplineOutOfControl AS outofctrl WITH (NOLOCK) ON dis.EmpId = outofctrl.EmpId
			AND dis.WorkDate = outofctrl.WorkDate
		WHERE EXISTS (
				SELECT 1
				FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
					INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
					INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON ce.GroupId = drule.GroupId
					AND (
						(
							drule.DisciplineTypeId = 3
							AND r.RequestType = 3
							)
						OR (
							drule.DisciplineTypeId = 4
							AND r.RequestType = 4
							)
						)
					AND empsum.IsLocal = drule.IsLocal
					AND drule.Value = 1
				WHERE dis.EmpId = ce.EmpId
				)

		UPDATE dis
		SET dis.IsIgnoredLateIn = CASE 
				WHEN r.RequestType = 3 THEN 0
				ELSE dis.IsIgnoredLateIn
				END
			,dis.IsIgnoredEarlyOut = CASE 
				WHEN r.RequestType = 4 THEN 0
				ELSE dis.IsIgnoredEarlyOut
				END
		FROM dbo.DisciplineIgnore AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK) ON lieo.RequestId = @RequestId
			AND dis.EmpId = lieo.EmpId
			AND dis.WorkDate = lieo.OnDate
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lieo.RequestId = r.RequestId
		WHERE EXISTS (
				SELECT 1
				FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
					INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
					INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON ce.GroupId = drule.GroupId
					AND (
						(
							drule.DisciplineTypeId = 3
							AND r.RequestType = 3
							)
						OR (
							drule.DisciplineTypeId = 4
							AND r.RequestType = 4
							)
						)
					AND empsum.IsLocal = drule.IsLocal
					AND drule.Value = 1
				WHERE dis.EmpId = ce.EmpId
				)

		UPDATE dis
		SET dis.IsOutOfControlLateIn = CASE 
				WHEN r.RequestType = 3 THEN 0
				ELSE dis.IsOutOfControlLateIn
				END
			,dis.IsOutOfControlEarlyOut = CASE 
				WHEN r.RequestType = 4 THEN 0
				ELSE dis.IsOutOfControlEarlyOut
				END
		FROM dbo.DisciplineOutOfControl AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.LateInEarlyOutRequest AS lieo WITH (NOLOCK) ON lieo.RequestId = @RequestId
			AND dis.EmpId = lieo.EmpId
			AND dis.WorkDate = lieo.OnDate
			INNER JOIN dbo.WorkingTimeRequest AS r WITH (NOLOCK) ON lieo.RequestId = r.RequestId
		WHERE EXISTS (
				SELECT 1
				FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
					INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
					INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON ce.GroupId = drule.GroupId
					AND (
						(
							drule.DisciplineTypeId = 3
							AND r.RequestType = 3
							)
						OR (
							drule.DisciplineTypeId = 4
							AND r.RequestType = 4
							)
						)
					AND empsum.IsLocal = drule.IsLocal
					AND drule.Value = 1
				WHERE dis.EmpId = ce.EmpId
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
			FROM dbo.LateInEarlyOutRequest WITH (NOLOCK)
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
			WHERE @ReasonId != @ManagementAllowReasonId

			-- update
			UPDATE dis
			SET dis.IsLateIn = CASE 
					WHEN tbl.DisciplineTypeId = 3 THEN 1
					ELSE 0
					END
				,dis.IsEarlyOut = CASE 
					WHEN tbl.DisciplineTypeId = 4 THEN 1
					ELSE 0
					END
				,dis.IsDeleted = 0
				,dis.ModifiedBy = @ActorId
				,dis.ModifiedDate = @ModifiedDate
			FROM dbo.Discipline AS dis WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
				AND dis.EmpId = tbl.EmpId
			WHERE @ReasonId != @ManagementAllowReasonId

			UPDATE dis
			SET dis.IsIgnoredLateIn = CASE 
					WHEN tbl.DisciplineTypeId = 3 THEN tbl.IsIgnored
					ELSE 0
					END
				,dis.IsIgnoredEarlyOut = CASE 
					WHEN tbl.DisciplineTypeId = 4 THEN tbl.IsIgnored
					ELSE 0
					END
			FROM dbo.DisciplineIgnore AS dis WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
				AND dis.EmpId = tbl.EmpId
			WHERE @ReasonId != @ManagementAllowReasonId

			UPDATE dis
			SET dis.IsOutOfControlLateIn = CASE 
					WHEN tbl.DisciplineTypeId = 3
						AND @ReasonId = @ManagementAllowReasonId
						AND IsIgnored = 1 THEN 1
					ELSE 0
					END
				,dis.IsOutOfControlEarlyOut = CASE 
					WHEN tbl.DisciplineTypeId = 4
						AND @ReasonId = @ManagementAllowReasonId
						AND IsIgnored = 1 THEN 1
					ELSE 0
					END
			FROM dbo.DisciplineOutOfControl AS dis WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
				AND dis.EmpId = tbl.EmpId
			WHERE @ReasonId != @ManagementAllowReasonId

			-- insert
			INSERT INTO dbo.Discipline (
				EmpId
				,WorkDate
				,IsLateIn
				,IsEarlyOut
				,IsOutOfControlReason
				,ModifiedBy
				,ModifiedDate
				)
			SELECT EmpId
				,WorkDate
				,CASE 
					WHEN tbl.DisciplineTypeId = 3 THEN 1
					ELSE 0
					END
				,CASE 
					WHEN tbl.DisciplineTypeId = 4 THEN 1
					ELSE 0
					END
				,0
				,@ActorId
				,@ModifiedDate
			FROM @tblDiscipline AS tbl
			WHERE @ReasonId != @ManagementAllowReasonId
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.Discipline AS dis WITH (NOLOCK)
					WHERE dis.EmpId = tbl.EmpId
						AND dis.WorkDate = tbl.WorkDate
					)

			INSERT INTO dbo.DisciplineIgnore (
				EmpId
				,WorkDate
				,IsIgnoredLateIn
				,IsIgnoredEarlyOut
				)
			SELECT EmpId
				,WorkDate
				,CASE 
					WHEN tbl.DisciplineTypeId = 3 THEN IsIgnored
					ELSE 0
					END
				,CASE 
					WHEN tbl.DisciplineTypeId = 4 THEN IsIgnored
					ELSE 0
					END
			FROM @tblDiscipline AS tbl
			WHERE @ReasonId != @ManagementAllowReasonId
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.DisciplineIgnore AS dis WITH (NOLOCK)
					WHERE dis.EmpId = tbl.EmpId
						AND dis.WorkDate = tbl.WorkDate
					)

			INSERT INTO dbo.DisciplineOutOfControl (
				EmpId
				,WorkDate
				,IsOutOfControlLateIn
				,IsOutOfControlEarlyOut
				)
			SELECT EmpId
				,WorkDate
				,0
				,0
			FROM @tblDiscipline AS tbl
			WHERE @ReasonId != @ManagementAllowReasonId
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
