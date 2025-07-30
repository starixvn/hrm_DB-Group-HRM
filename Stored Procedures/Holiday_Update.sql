/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Holiday_Update]
(
    @Id INT
	,@TypeId TINYINT
	,@HolidayName NVARCHAR(50)
	,@FromDate DATETIME
	,@ToDate DATETIME
	,@ModifiedBy INT
	,@ModifiedDate DATETIME
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-10-23
    Task: update holiday
    DB: bodb_HRM

    Revisions:
        20250505@Tim: fix bug update holiday
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @OldFromdate DATETIME
		,@Oldtodate DATETIME
        ,@CompanyId SMALLINT

	SELECT @OldFromdate = fromdate
		,@Oldtodate = todate
        ,@CompanyId = CompanyId
	FROM dbo.Holiday WITH (NOLOCK)
	WHERE Id = @id

	BEGIN TRANSACTION;

	IF @OldFromdate = @FromDate
		AND @ToDate = @Oldtodate
	BEGIN
		UPDATE dbo.Holiday WITH (ROWLOCK)
		SET HolidayName = @HolidayName
			,TypeId = @TypeId
		WHERE Id = @Id
	END
	ELSE
	BEGIN
		UPDATE ec
		SET ec.IsHoliday = 0
            ,ec.ModifiedBy = @ModifiedBy
		    ,ec.ModifiedDate = @ModifiedDate
        FROM dbo.EmployeeCalendar AS ec WITH (ROWLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ec.EmpId = ce.EmpId
		WHERE ce.CompanyId = @CompanyId
            AND ec.WorkDate BETWEEN @OldFromdate AND @Oldtodate

		UPDATE ec
		SET ec.IsHoliday = 1
			,ec.ModifiedBy = @ModifiedBy
			,ec.ModifiedDate = @ModifiedDate
		FROM dbo.EmployeeCalendar AS ec WITH (ROWLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ec.EmpId = ce.EmpId
		WHERE ce.CompanyId = @CompanyId
            AND ec.WorkDate BETWEEN @FromDate AND @ToDate
			AND EXISTS (
				SELECT 1
				FROM dbo.EmployeeSummary AS es WITH (NOLOCK)
				WHERE es.EmpId = ec.EmpId
					AND (
						es.IsLocal = 1
						OR (es.IsLocal = 0 AND es.IsExpatUseHoliday = 1)
						)
				)

		DECLARE @WorkDate DATETIME

		SELECT @WorkDate = CONVERT(VARCHAR(10), @FromDate, 111)

		WHILE DATEDIFF(d, @WorkDate, @ToDate) >= 0
		BEGIN
			IF @WorkDate < GETDATE()
			BEGIN
				INSERT INTO dbo.tmpEmployeeAttendace (
					EmpId
					,WorkDate
					,InsertedDate
					)
				SELECT e.EmpId
					,@WorkDate
					,@ModifiedDate
				FROM dbo.Employee AS e WITH (NOLOCK)
                    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
				WHERE ce.CompanyId = @CompanyId
                    AND e.[Enabled] = 1
			END

			INSERT INTO dbo.EmployeeCalendar (
				EmpId
				,WorkDate
				,IsHoliday
				,ModifiedDate
				)
			SELECT e.EmpId
				,@WorkDate
				,1
				,@ModifiedDate
			FROM dbo.Employee AS e WITH (NOLOCK)
                INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
			WHERE ce.CompanyId = @CompanyId
                AND e.[Enabled] = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.EmployeeSummary AS es WITH (NOLOCK)
					WHERE es.EmpId = e.EmpId
						AND (
							es.IsLocal = 1
							OR (es.IsLocal = 0 AND es.IsExpatUseHoliday = 1)
							)
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
					WHERE ec.EmpId = e.EmpId
						AND ec.WorkDate = @WorkDate
					)

			SET @WorkDate = DATEADD(d, 1, @WorkDate)
		END

		UPDATE dbo.Holiday WITH (ROWLOCK)
		SET HolidayName = @HolidayName
			,TypeId = @TypeId
			,FromDate = @FromDate
			,ToDate = @ToDate
		WHERE Id = @Id

		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 1
				,@ErrMsg = N'Update Holiday failed.'
		END
	END

	COMMIT TRANSACTION;
END