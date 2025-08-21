/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_UpdateDiscipline] @RequestId BIGINT
	,@ActorId INT
	,@RequestStatusId TINYINT
	,@DisciplineXml NVARCHAR(MAX) = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20191202@Tim.Trinh
Task: update discipline.
DB: HRM

Revisions:
	20250812@Mira: change DB structure [Redmine: #235678]
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

	-- reset/reject request
	IF @RequestStatusId = @PendingStatusId
		OR @RequestStatusId = @NotVerifiedStatusId
		OR @RequestStatusId = @RejectedStatusId
		OR @RequestStatusId = @VoidStatusId
	BEGIN
		DELETE d1
		FROM dbo.DisciplineIgnoreDetail d1 WITH (NOLOCK)
		INNER JOIN DisciplineRequestTrans d2 ON d2.RequestId = @RequestId AND d1.EmpId = d2.EmpId AND d1.DisciplineTypeId = d2.DisciplineTypeId AND d1.WorkDate = d2.WorkDate

		EXEC dbo.DisciplineRequestTrans_Delete @RequestId = @RequestId

		UPDATE dis
		SET dis.IsChangeShift = CASE 
				WHEN @RequestStatusId = @PendingStatusId THEN 1
				ELSE 0
				END
			,dis.IsDeleted = CASE 
				WHEN @RequestStatusId = @PendingStatusId THEN 1
				ELSE dis.IsDeleted
				END
			,dis.ModifiedBy = @ActorId
			,dis.ModifiedDate = @ModifiedDate
		FROM dbo.Discipline AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON cs.RequestId = @RequestId
			AND dis.EmpId = cs.EmpId
			AND cs.TypeId = 1 -- change shift
			INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
			AND dis.WorkDate = csdt.OnDate
		WHERE EXISTS (
				SELECT 1
				FROM dbo.CompanyEmployee AS emp WITH (NOLOCK)
					INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
					INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON emp.GroupId = drule.GroupId
					AND drule.DisciplineTypeId = 1
					AND empsum.IsLocal = drule.IsLocal
					AND drule.Value = 1
				WHERE dis.EmpId = emp.EmpId
				)

		UPDATE dis
		SET dis.IsIgnoredChangeShift = 0
		FROM dbo.DisciplineIgnore AS dis WITH (ROWLOCK, UPDLOCK)
			INNER JOIN dbo.ChangeShiftRequest AS cs WITH (NOLOCK) ON cs.RequestId = @RequestId
			AND dis.EmpId = cs.EmpId
			AND cs.TypeId = 1 -- change shift
			INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
			AND dis.WorkDate = csdt.OnDate
		WHERE EXISTS (
				SELECT 1
				FROM dbo.CompanyEmployee AS emp WITH (NOLOCK)
					INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
					INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON emp.GroupId = drule.GroupId
					AND drule.DisciplineTypeId = 1
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

			-- update
			UPDATE dis
			SET dis.IsChangeShift = 1
				,dis.IsDeleted = 0
				,dis.ModifiedBy = @ActorId
				,dis.ModifiedDate = @ModifiedDate
			FROM dbo.Discipline AS dis WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
				AND dis.EmpId = tbl.EmpId
				AND tbl.DisciplineTypeId = 1

			UPDATE dis
			SET dis.IsIgnoredChangeShift = tbl.IsIgnored
			FROM dbo.DisciplineIgnore AS dis WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tblDiscipline AS tbl ON dis.WorkDate = tbl.WorkDate
				AND dis.EmpId = tbl.EmpId
				AND tbl.DisciplineTypeId = 1

			-- insert
			INSERT INTO dbo.Discipline (
				EmpId
				,WorkDate
				,IsChangeShift
				,ModifiedBy
				,ModifiedDate
				)
			SELECT EmpId
				,WorkDate
				,1
				,@ActorId
				,@ModifiedDate
			FROM @tblDiscipline AS tbl
			WHERE tbl.DisciplineTypeId = 1
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.Discipline AS dis WITH (NOLOCK)
					WHERE dis.EmpId = tbl.EmpId
						AND dis.WorkDate = tbl.WorkDate
					)

			INSERT INTO dbo.DisciplineIgnore (
				EmpId
				,WorkDate
				,IsIgnoredChangeShift
				)
			SELECT EmpId
				,WorkDate
				,IsIgnored
			FROM @tblDiscipline AS tbl
			WHERE tbl.DisciplineTypeId = 1
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.DisciplineIgnore AS dis WITH (NOLOCK)
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