/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Holiday_Insert] @HolidayName NVARCHAR(50)
	,@TypeId TINYINT
	,@FromDate DATETIME
	,@ToDate DATETIME
	,@ModifiedBy INT
	,@ModifiedDate DATETIME
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
AS
/*
Created: Tom.Vo@2013-10-23
Task: Insert Holidate
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	DECLARE @id INT

	IF @fromdate < GETDATE()
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Can not create Holiday in the past.'
			,@Id = 0
	END
	ELSE
	BEGIN
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

		UPDATE cl
		SET cl.IsHoliday = 1
			,cl.ModifiedBy = @ModifiedBy
			,cl.ModifiedDate = @ModifiedDate
		FROM dbo.EmployeeCalendar AS cl WITH (ROWLOCK, UPDLOCK)
		WHERE WorkDate BETWEEN @FromDate
				AND @ToDate
			AND EXISTS (
				SELECT 1
				FROM dbo.EmployeeSummary WITH (NOLOCK)
				WHERE EmpId = cl.EmpId
					AND (
						IsLocal = 1
						OR (
							IsLocal = 0
							AND IsExpatUseHoliday = 1
							)
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
				,ModifiedDate
				)
			SELECT EmpId
				,@WorkDate
				,1
				,GETDATE()
			FROM dbo.Employee AS e WITH (NOLOCK)
			WHERE [Enabled] = 1
				AND EXISTS (
					SELECT 1
					FROM dbo.EmployeeSummary WITH (NOLOCK)
					WHERE EmpId = e.EmpId
						AND (
							IsLocal = 1
							OR (
								IsLocal = 0
								AND IsExpatUseHoliday = 1
								)
							)
					)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.EmployeeCalendar WITH (NOLOCK)
					WHERE EmpId = e.EmpId
						AND WorkDate = @WorkDate
					)

			SET @WorkDate = DATEADD(d, 1, @WorkDate)
		END

		IF @@ERROR <> 0
		BEGIN
			SET @Id = 0

			SELECT @ErrCode = 1
				,@ErrMsg = N'Create Holiday failed.'
		END
		ELSE
		BEGIN
			SET @id = cast(SCOPE_IDENTITY() AS INT)
		END
	END

	SELECT @id
END
