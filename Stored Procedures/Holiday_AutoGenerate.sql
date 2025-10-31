/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Holiday_AutoGenerate]
(
    @CompanyId SMALLINT
    ,@Holidays NVARCHAR(MAX)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20190705@Oliver.Dang
    Task: Auto insert holidays at new year
    DB: bodb_HRM

    Revisions:
        20250423@Tim: update IsHoliday
		20250821@Jay: restructure for transfer [Redmine: #235678]

    Param's Explanation:
        @holidays:
            N'<Root>
	           <Row HolidayName="New Year" FromDate="2019-01-01" ToDate="2019-01-01" />
            </Root>'
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpHoliday (
        RowIndex INT IDENTITY (1, 1)
		,HolidayName NVARCHAR(50)
		,FromDate DATE
		,ToDate DATE
		)

	DECLARE @DocHandler INT

	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@Holidays

	INSERT INTO #tmpHoliday (HolidayName, FromDate, ToDate)
	SELECT HolidayName, FromDate, ToDate
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (HolidayName NVARCHAR(50), FromDate DATE, ToDate DATE) AS tmpdata

	EXEC sp_xml_removedocument @DocHandler

    DECLARE @RowIndex INT
	    ,@TotalRows INT
        ,@HolidayName NVARCHAR(50)
	    ,@FromDate DATE
	    ,@ToDate DATE
    SELECT @RowIndex = 1
	    ,@TotalRows = COUNT(1)
    FROM #tmpHoliday WITH (NOLOCK)

    WHILE @RowIndex <= @TotalRows
    BEGIN        
        SELECT @HolidayName = HolidayName
		    ,@FromDate = Fromdate
		    ,@ToDate = ToDate
	    FROM #tmpHoliday WITH (NOLOCK)
        WHERE RowIndex = @RowIndex
        
        INSERT INTO dbo.Holiday (HolidayName, TypeId, FromDate, ToDate, CompanyId)
        VALUES (@HolidayName, 1, @FromDate, @ToDate, @CompanyId)

        UPDATE cl
		SET cl.IsHoliday = 1
			,cl.ModifiedDate = GETDATE()
		FROM dbo.EmployeeCalendar AS cl WITH (ROWLOCK, UPDLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON cl.EmpId = ce.EmpId
		WHERE ce.CompanyId = @CompanyId
            AND cl.IsHoliday = 0
            AND cl.WorkDate BETWEEN @FromDate
				AND @ToDate
			AND EXISTS (
				SELECT 1
				FROM dbo.EmployeeSummary AS es WITH (NOLOCK)
				WHERE es.EmpId = cl.EmpId
					AND (
						es.IsLocal = 1
						OR (
							es.IsLocal = 0
							AND es.IsExpatUseHoliday = 1
							)
						)
				)

		DECLARE @WorkDate DATE = @FromDate

		WHILE DATEDIFF(DAY, @WorkDate, @ToDate) >= 0
		BEGIN
			INSERT INTO dbo.EmployeeCalendar (
				EmpId
				,WorkDate
				,IsHoliday
				,ModifiedDate
				)
			SELECT ce.EmpId
				,@WorkDate
				,1
				,GETDATE()
			FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
			WHERE ce.CompanyId = @CompanyId
                AND ce.[Enabled] = 1
                AND ce.IsDeleted = 0
				AND EXISTS (
					SELECT 1
					FROM dbo.EmployeeSummary AS es WITH (NOLOCK)
					WHERE es.EmpId = ce.EmpId
						AND (
							es.IsLocal = 1
							OR (
								es.IsLocal = 0
								AND es.IsExpatUseHoliday = 1
								)
							)
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
					WHERE ec.EmpId = ce.EmpId
						AND ec.WorkDate = @WorkDate
					)

			SET @WorkDate = DATEADD(DAY, 1, @WorkDate)
		END

        SET @RowIndex = @RowIndex + 1
    END

	DROP TABLE #tmpHoliday
END