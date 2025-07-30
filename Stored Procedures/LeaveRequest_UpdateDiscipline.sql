/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[LeaveRequest_UpdateDiscipline] @RequestId BIGINT
	,@ActorId INT
	,@RequestStatusId TINYINT
	,@DisciplineXml NVARCHAR(MAX) = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20191203@Tim.Trinh
Task: update discipline
DB: HRM
Original: 

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
	DECLARE @tblDisciplineDetail TABLE (
		EmpId INT
		,WorkDate DATE
		,IsUnpaidLeaveAbsent BIT
		,IsUnpaidLeave BIT
		,IsAbsent BIT
		,IsUnplannedLeave BIT
		,IsWeekendLeave BIT
		,IsSevenDaysLeave BIT
		)

	INSERT INTO @tblDisciplineDetail (
		EmpId
		,WorkDate
		,IsUnpaidLeaveAbsent
		,IsUnpaidLeave
		,IsAbsent
		,IsUnplannedLeave
		,IsWeekendLeave
		,IsSevenDaysLeave
		)
	SELECT EmployeeId
		,WorkDate
		,IsUnpaidLeaveAbsent
		,IsUnpaidLeave
		,IsAbsent
		,IsUnplannedLeave
		,IsWeekendLeave
		,IsSevenDaysLeave
	FROM dbo.fnc_GetDisciplineDetailByLeaveRequestId(@RequestId)

	-- reset/reject request
	IF @RequestStatusId = @PendingStatusId
		OR @RequestStatusId = @NotVerifiedStatusId
		OR @RequestStatusId = @RejectedStatusId
		OR @RequestStatusId = @VoidStatusId
	BEGIN
		DELETE d1
		FROM dbo.DisciplineIgnoreDetail AS d1 WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.DisciplineRequestTrans AS d2 ON d2.RequestId = @RequestId
			AND d1.EmpId = d2.EmpId
			AND d1.DisciplineTypeId = d2.DisciplineTypeId
			AND d1.WorkDate = d2.WorkDate

		EXEC dbo.DisciplineRequestTrans_Delete @RequestId = @RequestId

		UPDATE dis
		SET dis.IsAbsent = 0
			,dis.IsUnpaidLeave = 0
			,dis.IsUnpaidLeaveAbsent = 0
			,dis.IsUnplannedLeave = 0
			,dis.IsWeekendLeave = 0
			,dis.IsSevenDaysLeave = 0
			,dis.IsDeleted = CASE 
				WHEN @RequestStatusId = @PendingStatusId THEN 1
				ELSE dis.IsDeleted
				END
			,dis.ModifiedBy = @ActorId
			,dis.ModifiedDate = @ModifiedDate
		FROM dbo.Discipline AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tblDisciplineDetail AS tbl ON dis.EmpId = tbl.EmpId
			AND dis.WorkDate = tbl.WorkDate

		UPDATE dis
		SET dis.IsIgnoredAbsent = 0
			,dis.IsIgnoredUnpaidLeave = 0
			,dis.IsIgnoredUnpaidLeaveAbsent = 0
			,dis.IsIgnoredUnplannedLeave = 0
			,dis.IsIgnoredWeekendLeave = 0
			,dis.IsIgnoredSevenDaysLeave = 0
		FROM dbo.DisciplineIgnore AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tblDisciplineDetail AS tbl ON dis.EmpId = tbl.EmpId
			AND dis.WorkDate = tbl.WorkDate

		RETURN
	END

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
				,@ErrMsg = N'Parameter invalid.'

			RETURN
		END CATCH
	END

	IF EXISTS (
			SELECT 1
			FROM @tblDiscipline
			)
	BEGIN
		INSERT INTO dbo.DisciplineRequestTrans (
			EmpId
			,WorkDate
			,RequestId
			,DisciplineTypeId
			,IsIgnored
			,IsOutOfControl
			,ModifiedDate
			)
		SELECT EmpId
			,WorkDate
			,@RequestId
			,DisciplineTypeId
			,IsIgnored
			,0
			,@ModifiedDate
		FROM @tblDiscipline

		-- insert
		INSERT INTO dbo.Discipline (EmpId, WorkDate)
		SELECT DISTINCT EmpId, WorkDate
		FROM @tblDiscipline AS tbl
		WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.Discipline AS dis WITH (NOLOCK)
				WHERE dis.EmpId = tbl.EmpId
					AND dis.WorkDate = tbl.WorkDate
				)

		INSERT INTO dbo.DisciplineIgnore (EmpId, WorkDate)
		SELECT DISTINCT EmpId, WorkDate
		FROM @tblDiscipline AS tbl
		WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.DisciplineIgnore AS dis WITH (NOLOCK)
				WHERE dis.EmpId = tbl.EmpId
					AND dis.WorkDate = tbl.WorkDate
				)

		-- update
		UPDATE dis
		SET dis.IsAbsent = CASE 
				WHEN tbl.DisciplineTypeId = 5 THEN 1
				ELSE dis.IsAbsent
				END
			,dis.IsUnpaidLeave = CASE 
				WHEN tbl.DisciplineTypeId = 6 THEN 1
				ELSE dis.IsUnpaidLeave
				END
			,dis.IsUnpaidLeaveAbsent = CASE 
				WHEN tbl.DisciplineTypeId = 8 THEN 1
				ELSE dis.IsUnpaidLeaveAbsent
				END
			,dis.IsUnplannedLeave = CASE 
				WHEN tbl.DisciplineTypeId = 9 THEN 1
				ELSE dis.IsUnplannedLeave
				END
			,dis.IsWeekendLeave = CASE 
				WHEN tbl.DisciplineTypeId = 10 THEN 1
				ELSE dis.IsWeekendLeave
				END
			,dis.IsSevenDaysLeave = CASE 
				WHEN tbl.DisciplineTypeId = 11 THEN 1
				ELSE dis.IsSevenDaysLeave
				END
			,dis.IsDeleted = 0
			,dis.ModifiedBy = @ActorId
			,dis.ModifiedDate = @ModifiedDate
		FROM dbo.Discipline AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
			AND dis.EmpId = tbl.EmpId

		UPDATE dis
		SET dis.IsIgnoredAbsent = CASE 
				WHEN tbl.DisciplineTypeId = 5 THEN tbl.IsIgnored
				ELSE dis.IsIgnoredAbsent
				END
			,dis.IsIgnoredUnpaidLeave = CASE 
				WHEN tbl.DisciplineTypeId = 6 THEN tbl.IsIgnored
				ELSE dis.IsIgnoredUnpaidLeave
				END
			,dis.IsIgnoredUnpaidLeaveAbsent = CASE 
				WHEN tbl.DisciplineTypeId = 8 THEN tbl.IsIgnored
				ELSE dis.IsIgnoredUnpaidLeaveAbsent
				END
			,dis.IsIgnoredUnplannedLeave = CASE 
				WHEN tbl.DisciplineTypeId = 9 THEN tbl.IsIgnored
				ELSE dis.IsIgnoredUnplannedLeave
				END
			,dis.IsIgnoredWeekendLeave = CASE 
				WHEN tbl.DisciplineTypeId = 10 THEN tbl.IsIgnored
				ELSE dis.IsIgnoredWeekendLeave
				END
			,dis.IsIgnoredSevenDaysLeave = CASE 
				WHEN tbl.DisciplineTypeId = 11 THEN tbl.IsIgnored
				ELSE dis.IsIgnoredSevenDaysLeave
				END
		FROM dbo.DisciplineIgnore AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
			AND dis.EmpId = tbl.EmpId
	END
END