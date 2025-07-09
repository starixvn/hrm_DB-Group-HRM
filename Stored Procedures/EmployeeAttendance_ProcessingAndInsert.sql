/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tempFromDate DATE = @fromTime
		,@tempToDate DATE = @toTime
		,@today DATE = GETDATE() + 1
	DECLARE @tblDateRange TABLE (WorkDate DATE)
	CREATE TABLE #tmpEmployee (EmpId INT)

	IF @tempToDate > @today
	BEGIN
		SET @tempToDate = @today
	END

	WHILE @tempFromDate <= @tempToDate
	BEGIN
		INSERT INTO @tblDateRange (WorkDate)
		VALUES (@tempFromDate)

		SET @tempFromDate = DATEADD(DAY, 1, @tempFromDate)
	END

	IF EXISTS (
		SELECT 1
		FROM @tblDateRange AS tbldate
		WHERE NOT EXISTS (
                SELECT 1
                FROM dbo.EmployeeCalendar AS empca WITH (NOLOCK)
                    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON empca.EmpId = ce.EmpId
                WHERE empca.WorkDate = CAST(tbldate.WorkDate AS DATETIME)
                    AND (@EmpId IS NULL OR empca.EmpId = @EmpId)
            )
		)
    BEGIN
        DECLARE @ErrCode INT = 0
            ,@ErrMsg VARCHAR(200) = ''

        EXEC dbo.EmployeeCalendar_Insert @EmpId = @EmpId
            ,@fromdate = @fromTime
            ,@todate = @tempToDate
            ,@ErrCode = @ErrCode OUTPUT
            ,@ErrMsg = @ErrMsg OUTPUT
    END

    INSERT INTO #tmpEmployee (EmpId)
    SELECT e.EmpId
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.[Enabled] = 1
        AND e.isDeleted = 0
        AND (@CompanyId IS NULL OR ce.CompanyId = @CompanyId)
        AND (@EmpId IS NULL OR e.EmpId = @EmpId)

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