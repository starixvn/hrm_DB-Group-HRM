/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Auto_Discipline_ProcessWaitingCase]
AS
/*
    Created: 20250527@Tim
    Task: process discipline
    DB: bodb_HRM

    Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @i INT
		,@EmpId INT
		,@WorkDate DATE
	CREATE TABLE #tmpEmployee (Id INT PRIMARY KEY IDENTITY(1, 1), EmpId INT, WorkDate DATE)

	INSERT INTO #tmpEmployee (EmpId, WorkDate)
	SELECT TOP 50 EmpId
        ,WorkDate
	FROM dbo.tmpProcessDiscipline WITH (NOLOCK)

	DELETE tmp
	FROM dbo.tmpProcessDiscipline AS tmp WITH (ROWLOCK)
		INNER JOIN #tmpEmployee AS e WITH (NOLOCK) ON tmp.EmpId = e.EmpId
	    AND tmp.WorkDate = e.WorkDate

	SET @i = 1

	WHILE EXISTS (
			SELECT 1
			FROM #tmpEmployee
			WHERE Id = @i
			)
	BEGIN
		SELECT @EmpId = EmpId
			,@WorkDate = WorkDate
		FROM #tmpEmployee
		WHERE Id = @i

        EXEC dbo.Discipline_Insert @FromDate = @WorkDate
            ,@ToDate = @WorkDate
            ,@EmpId = @EmpId

		SET @i = @i + 1
	END

    DROP TABLE #tmpEmployee
END