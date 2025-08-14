/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsert]
(
    @empId INT = NULL
    ,@fromTime DATETIME
    ,@toTime DATETIME
    ,@onlyUpdate BIT = 0
    ,@CompanyId SMALLINT = NULL
)
AS
/*
    Created:
    Task:
    DB: bodb_HRM

    Revisions:
        20250519@Tim: remove check JoinedDate
        20250604@Tim: add attendance processing to the queue
		20250812@Mira: tranfer employee [Redmine: #235678]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @i INT
		,@TempEmpId INT
		,@tempFromDate DATE = @fromTime
		,@tempToDate DATE = @toTime
		,@today DATE = GETDATE()
        ,@serverTimeZone SMALLINT = -4
	DECLARE @tblDateRange TABLE (WorkDate DATE)
	CREATE TABLE #tmpEmployee (Id INT PRIMARY KEY IDENTITY(1, 1), EmpId INT)

	IF @tempToDate > @today
	BEGIN
		SET @tempToDate = @today
	END

	WHILE @tempFromDate <= @tempToDate
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM @tblDateRange
				WHERE WorkDate = @tempFromDate
				)
		BEGIN
			INSERT INTO @tblDateRange (WorkDate)
			VALUES (@tempFromDate)
		END

		SET @tempFromDate = DATEADD(DAY, 1, @tempFromDate)
	END

	IF EXISTS (
			SELECT EmpId
			FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
				LEFT JOIN @tblDateRange AS tbldate ON empca.WorkDate = tbldate.WorkDate
			WHERE (
					@empId IS NULL
					OR EmpId = @empId
					)
				AND tbldate.WorkDate IS NULL
			)
        BEGIN
            DECLARE @ErrCode INT = 0
                ,@ErrMsg VARCHAR(200) = ''

            EXEC dbo.EmployeeCalendar_Insert @EmpId = @empId
                ,@fromdate = @fromTime
                ,@todate = @tempToDate
                ,@ErrCode = @ErrCode OUTPUT
                ,@ErrMsg = @ErrMsg OUTPUT
        END

    INSERT INTO #tmpEmployee (EmpId)
    SELECT ce.EmpId
    FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
    WHERE ce.[Enabled] = 1
        AND ce.isDeleted = 0
        AND (
            @CompanyId IS NULL
            OR ce.CompanyId = @CompanyId
        )
        AND (
            @EmpId IS NULL
            OR ce.EmpId = @EmpId
        )

    INSERT INTO dbo.tmpEmployeeAttendace (EmpId, WorkDate, InsertedDate)
    SELECT e.EmpId, d.WorkDate, GETDATE()
    FROM #tmpEmployee AS e
        ,@tblDateRange AS d
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.tmpEmployeeAttendace AS att WITH (NOLOCK)
        WHERE e.EmpId = att.EmpId
            AND d.WorkDate = att.WorkDate
        )

	DROP TABLE #tmpEmployee
END