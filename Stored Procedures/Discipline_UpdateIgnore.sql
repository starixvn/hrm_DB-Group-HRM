/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Discipline_UpdateIgnore] @ActorId INT
	,@DisciplineIgnoreXml NVARCHAR(MAX) = NULL
	,@IgnoreDetailXml NVARCHAR(MAX) = NULL
	,@HasUpdateOutOfControlReason BIT = 0
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20191204@Tim.Trinh
Task: update ignore
DB: HRM

Revisions:
Param's Explanation:
    @IgnoreDetailXml: 
        <Root>
            <Row WorkDate='{0}' EmployeeId='{1}' IsIgnoredChangeShift='{2}' IsIgnoredMissingCheckInOut='{3}' IsIgnoredLateIn='{4}'
                IsIgnoredEarlyOut='{5}' IsIgnoredAbsent='{6}' IsIgnoredUnplannedLeave='{7}' IsIgnoredUnpaidLeave='{8}'
                IsIgnoredWorkingUnderTime='{9}' IsIgnoredUnpaidLeaveAbsent='{10}' IsIgnoredWeekendLeave='{11}'
                ApproverSubtractScore='{12}' IsOutOfControlReason='{13}' />
        </Root>
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ModifiedDate DATETIME = GETDATE()

	IF ISNULL(@IgnoreDetailXml, '') <> ''
	BEGIN
		DECLARE @DocHandler INT

		CREATE TABLE #tblIgnoredDisciplineDetail (
			WorkDate DATE
			,EmpId INT
			,IsIgnoredChangeShift BIT
			,IsIgnoredMissingCheckInOut BIT
			,IsIgnoredLateIn BIT
			,IsIgnoredEarlyOut BIT
			,IsIgnoredAbsent BIT
			,IsIgnoredUnplannedLeave BIT
			,IsIgnoredUnpaidLeave BIT
			,IsIgnoredWorkingUnderTime BIT
			,IsIgnoredUnpaidLeaveAbsent BIT
			,IsIgnoredWeekendLeave BIT
			,IsIgnoredSevenDaysLeave BIT
			,ApproverSubtractScore DECIMAL(5, 2)
			,IsOutOfControlReason BIT
			)

		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@IgnoreDetailXml

		INSERT INTO #tblIgnoredDisciplineDetail (
			WorkDate
			,EmpId
			,IsIgnoredChangeShift
			,IsIgnoredMissingCheckInOut
			,IsIgnoredLateIn
			,IsIgnoredEarlyOut
			,IsIgnoredAbsent
			,IsIgnoredUnplannedLeave
			,IsIgnoredUnpaidLeave
			,IsIgnoredWorkingUnderTime
			,IsIgnoredUnpaidLeaveAbsent
			,IsIgnoredWeekendLeave
			,IsIgnoredSevenDaysLeave
			,ApproverSubtractScore
			,IsOutOfControlReason
			)
		SELECT DISTINCT WorkDate
			,EmployeeId
			,IsIgnoredChangeShift
			,IsIgnoredMissingCheckInOut
			,IsIgnoredLateIn
			,IsIgnoredEarlyOut
			,IsIgnoredAbsent
			,IsIgnoredUnplannedLeave
			,IsIgnoredUnpaidLeave
			,IsIgnoredWorkingUnderTime
			,IsIgnoredUnpaidLeaveAbsent
			,IsIgnoredWeekendLeave
			,IsIgnoredSevenDaysLeave
			,ApproverSubtractScore
			,IsOutOfControlReason
		FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (WorkDate DATE, EmployeeId INT, IsIgnoredChangeShift BIT, IsIgnoredMissingCheckInOut BIT, IsIgnoredLateIn BIT, IsIgnoredEarlyOut BIT, IsIgnoredAbsent BIT, IsIgnoredUnplannedLeave BIT, IsIgnoredUnpaidLeave BIT, IsIgnoredWorkingUnderTime BIT, IsIgnoredUnpaidLeaveAbsent BIT, IsIgnoredWeekendLeave BIT, IsIgnoredSevenDaysLeave BIT, ApproverSubtractScore DECIMAL(5, 2), IsOutOfControlReason BIT) AS Data

		EXEC sp_xml_removedocument @DocHandler

        select * from #tblIgnoredDisciplineDetail

		IF @HasUpdateOutOfControlReason = 1
		BEGIN
			UPDATE dis
			SET dis.IsOutOfControlReason = ignore.IsOutOfControlReason
				,dis.ModifiedBy = @ActorId
				,dis.ModifiedDate = @ModifiedDate
			FROM dbo.Discipline AS dis WITH (NOLOCK)
				INNER JOIN #tblIgnoredDisciplineDetail AS ignore WITH (NOLOCK) ON dis.WorkDate = ignore.WorkDate
				AND dis.EmpId = ignore.EmpId
		END

		DELETE ignore
		FROM #tblIgnoredDisciplineDetail AS ignore WITH (NOLOCK)
			INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON ignore.EmpId = emp.EmpId
			AND emp.isDeleted = 0
			AND emp.[Enabled] = 1
			LEFT JOIN dbo.[Group] AS gr WITH (NOLOCK) ON emp.GroupId = gr.GroupId
		WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
				WHERE empS.OwnerId = @ActorId
					AND empS.EmpId = emp.EmpId
					AND empS.ActionType = 8 -- edit discipline
					AND empS.EmpId <> @ActorId
					AND empS.IsDeleted = 0
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.GroupSupervisor AS grS WITH (NOLOCK)
				WHERE gr.GroupId = grS.GroupId
					AND grS.OwnerId = @ActorId
					AND grS.ActionType = 8 -- edit discipline
					-- AND emp.EmpId <> @ActorId
					AND grS.IsDeleted = 0
					AND NOT EXISTS (
						SELECT 1
						FROM dbo.EmployeeSupervisor AS empS WITH (NOLOCK)
						WHERE empS.OwnerId <> @ActorId
							AND empS.EmpId = emp.EmpId
							AND empS.ActionType = 8
							AND empS.IsDeleted = 0
						)
				)

		IF EXISTS (
				SELECT 1
				FROM #tblIgnoredDisciplineDetail WITH (NOLOCK)
				)
		BEGIN
			UPDATE dis
			SET dis.DisciplineScore = ignore.ApproverSubtractScore
				,dis.IsOutOfControlReason = ignore.IsOutOfControlReason
				,dis.ModifiedBy = @ActorId
				,dis.ModifiedDate = @ModifiedDate
			FROM dbo.Discipline AS dis WITH (NOLOCK)
				INNER JOIN #tblIgnoredDisciplineDetail AS ignore WITH (NOLOCK) ON dis.WorkDate = ignore.WorkDate
				AND dis.EmpId = ignore.EmpId

			UPDATE dis
			SET dis.IsIgnoredChangeShift = ignore.IsIgnoredChangeShift
				,dis.IsIgnoredMissingCheckInOut = ignore.IsIgnoredMissingCheckInOut
				,dis.IsIgnoredLateIn = ignore.IsIgnoredLateIn
				,dis.IsIgnoredEarlyOut = ignore.IsIgnoredEarlyOut
				,dis.IsIgnoredAbsent = ignore.IsIgnoredAbsent
				,dis.IsIgnoredUnplannedLeave = ignore.IsIgnoredUnplannedLeave
				,dis.IsIgnoredUnpaidLeave = ignore.IsIgnoredUnpaidLeave
				,dis.IsIgnoredWorkingUndertime = ignore.IsIgnoredWorkingUnderTime
				,dis.IsIgnoredUnpaidLeaveAbsent = ignore.IsIgnoredUnpaidLeaveAbsent
				,dis.IsIgnoredWeekendLeave = ignore.IsIgnoredWeekendLeave
				,dis.IsIgnoredSevenDaysLeave = ignore.IsIgnoredSevenDaysLeave
			FROM dbo.DisciplineIgnore AS dis WITH (NOLOCK)
				INNER JOIN #tblIgnoredDisciplineDetail AS ignore WITH (NOLOCK) ON dis.WorkDate = ignore.WorkDate
				AND dis.EmpId = ignore.EmpId
		END

		DROP TABLE #tblIgnoredDisciplineDetail
	END

	EXEC dbo.DisciplineIgnoreDetail_Update @ActorId = @ActorId
		,@DisciplineIgnoreXml = @DisciplineIgnoreXml
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	EXEC dbo.Log_WriteLog @LogActionId = 1010
		,@LogDate = @ModifiedDate
		,@Description = 'Discipline review'
		,@TrackingValue = @IgnoreDetailXml
		,@UserId = @ActorId

	EXEC dbo.Log_WriteLog @LogActionId = 1011
		,@LogDate = @ModifiedDate
		,@Description = 'Discipline review - log detail'
		,@TrackingValue = @DisciplineIgnoreXml
		,@UserId = @ActorId
END