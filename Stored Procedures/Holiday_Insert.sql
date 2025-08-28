/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Holiday_Insert]
(
	@CompanyId SMALLINT
    ,@HolidayName NVARCHAR(50)
	,@TypeId TINYINT
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
    Task: Insert Holidate
    DB: bodb_HRM

    Revisions:
        20250505@Tim: fix bug create holiday
		20250821@Jay: restructure for transfer [Redmine: #235678]
    Param's Explanation:

*/
BEGIN
	DECLARE @id INT

	DECLARE @OldHolidayId INT

	SELECT @OldHolidayId = MAX(OldHolidayId)
	FROM dbo.Holiday WITH (NOLOCK)
	WHERE CompanyId = @CompanyId

	SET @OldHolidayId = ISNULL(@OldHolidayId, 0) + 1

	INSERT INTO [dbo].[Holiday] (
		HolidayName
		,TypeId
		,FromDate
		,ToDate
		,CompanyId
		,OldHolidayId
		)
	VALUES (
		@HolidayName
		,@TypeId
		,@FromDate
		,@ToDate
		,@CompanyId
		,@OldHolidayId
		)

	UPDATE ec
	SET ec.IsHoliday = 1
		,ec.ModifiedBy = @ModifiedBy
		,ec.ModifiedDate = @ModifiedDate
	FROM dbo.EmployeeCalendar AS ec WITH (ROWLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ec.EmpId = ce.EmpId
	WHERE ce.CompanyId = @CompanyId
        AND ec.WorkDate BETWEEN @FromDate
				AND @ToDate
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
		INSERT INTO dbo.EmployeeCalendar (
			EmpId
			,WorkDate
			,IsHoliday
            ,ModifiedBy
			,ModifiedDate
			)
		SELECT ce.EmpId
			,@WorkDate
			,1
            ,@ModifiedBy
			,GETDATE()
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		WHERE ce.CompanyId = @CompanyId
            AND ce.[Enabled] = 1
			AND EXISTS (
				SELECT 1
				FROM dbo.EmployeeSummary AS es WITH (NOLOCK)
				WHERE es.EmpId = ce.EmpId
					AND (
						es.IsLocal = 1
						OR (es.IsLocal = 0 AND es.IsExpatUseHoliday = 1)
						)
				)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.EmployeeCalendar AS ec WITH (NOLOCK)
				WHERE ec.EmpId = ce.EmpId
					AND ec.WorkDate = @WorkDate
				)

		SET @WorkDate = DATEADD(d, 1, @WorkDate)
	END

	SET @id = CAST(SCOPE_IDENTITY() AS INT)
END
