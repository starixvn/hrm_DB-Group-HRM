/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Shift_Update]
(
    @ShiftId INT
	,@Name VARCHAR(20)
	,@CheckInTime VARCHAR(5)
	,@CheckOutTime VARCHAR(5)
	,@IsInAfterDay BIT
	,@IsOutAfterDay BIT
	,@IsDisabled BIT
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20140630@Quinn.Vo
    Task: Update Shift.
    DB: bodb_HRM

    Revisions:
        20250515@Tim: fix bug check exists
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FromDate DATETIME = CAST((CONVERT(VARCHAR(10), GETDATE(), 111) + ' ' + @CheckInTime) AS DATETIME)
		,@ToDate DATETIME = CAST((CONVERT(VARCHAR(10), GETDATE(), 111) + ' ' + @CheckOutTime) AS DATETIME)
		,@TotalHours DECIMAL(10, 2)
		,@IsCrossDay BIT
        ,@CompanyId SMALLINT

    SELECT @CompanyId = CompanyId
    FROM dbo.[Shift] WITH (NOLOCK)
    WHERE ShiftId = @ShiftId

	IF @IsInAfterDay = 1
	BEGIN
		SET @FromDate = DATEADD(d, 1, @FromDate)
	END

	IF @IsOutAfterDay = 1
	BEGIN
		SET @ToDate = DATEADD(d, 1, @ToDate)
	END

	IF @IsInAfterDay = 0
		AND @IsOutAfterDay = 1
	BEGIN
		SET @IsCrossDay = 1
	END
	ELSE
	BEGIN
		SET @IsCrossDay = 0
	END

	SET @TotalHours = DATEDIFF(MI, @FromDate, @ToDate) / 60.0

	IF EXISTS (
			SELECT 1
			FROM dbo.[Shift] WITH (NOLOCK)
			WHERE [Name] = @Name
				AND ShiftId != @ShiftId
                AND CompanyId = @CompanyId
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Shift ' + @Name + ' already exists.'

		RETURN
	END

	IF @FromDate >= @ToDate
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Time in & time out is invalid.'

		RETURN
	END

	UPDATE dbo.[Shift] WITH (ROWLOCK, UPDLOCK)
	SET Code = @Name
		,[Name] = @Name
		,BeginCheckInTime = @CheckInTime
		,EndCheckInTime = @CheckInTime
		,BeginCheckOutTime = @CheckOutTime
		,EndCheckOutTime = @CheckOutTime
		,BreakTimeMins = 0
		,OrderNo = 100
		,CrossDay = @IsCrossDay
		,TotalHours = @TotalHours
		,IsInAfterDay = @IsInAfterDay
		,IsOutAfterDay = @IsOutAfterDay
		,IsDisabled = @IsDisabled
		,ModifiedBy = @ActorId
		,ModifiedDate = GETDATE()
	WHERE ShiftID = @ShiftId
END