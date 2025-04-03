/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ScheduleArrangement_SyncShift] @CompanyId SMALLINT
    ,@ActorId INT
	,@ShiftXml NVARCHAR(MAX) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: Tim@20250327
Task: sync shift from OWP
DB: HRM

Revisions:
Param's Explanation:
    @ShiftXml: "<Root>
		<Row ShiftCode={1} CheckInTime={2} CheckOutTime={3} IsInAfterDay={3} IsOutAfterDay={4} IsCrossDay={5} TotalHours={6} ModifiedDate={7} />
	</Root>"
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SyncDate DATETIME = GETDATE()
		,@DocHandler INT

    CREATE TABLE #tmpShiftId (RowIndex INT PRIMARY KEY IDENTITY(1, 1), ShiftId INT)

	CREATE TABLE #tmpShift (
		ShiftCode VARCHAR(20)
		,CheckInTime NCHAR(5) NULL
		,CheckOutTime NCHAR(5) NULL
		,IsInAfterDay BIT
		,IsOutAfterDay BIT
		,IsCrossDay BIT
		,TotalHours DECIMAL(10, 2)
		,ModifiedDate DATETIME
		)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT
		,@ShiftXml

	INSERT INTO #tmpShift (
		ShiftCode
		,CheckInTime
		,CheckOutTime
		,IsInAfterDay
		,IsOutAfterDay
		,IsCrossDay
		,TotalHours
		,ModifiedDate
		)
	SELECT ShiftCode
		,CheckInTime
		,CheckOutTime
		,IsInAfterDay
		,IsOutAfterDay
		,IsCrossDay
		,TotalHours
		,ModifiedDate
	FROM OPENXML(@DocHandler, '/Root/Row', 1) WITH (ShiftCode VARCHAR(20), CheckInTime NCHAR(5), CheckOutTime NCHAR(5), IsInAfterDay BIT, IsOutAfterDay BIT, IsCrossDay BIT, TotalHours DECIMAL(10, 2), ModifiedDate DATETIME) AS Data

	EXEC sp_xml_removedocument @DocHandler

	INSERT INTO dbo.[Shift] (
		Code
		,[Name]
		,BeginCheckInTime
		,EndCheckInTime
		,BeginCheckOutTime
		,EndCheckOutTime
		,BreakTimeMins
		,TotalHours
		,CrossDay
		,IsInAfterDay
		,IsOutAfterDay
		,OWPModifiedDate
		,OWPSyncDate
		,CreatedDate
		,IsDisabled
        ,CompanyId
        ,OldShiftId
		)
    OUTPUT inserted.ShiftID
    INTO #tmpShiftId(ShiftId)
	SELECT DISTINCT tmpws.ShiftCode
		,tmpws.ShiftCode
		,tmpws.CheckInTime
		,tmpws.CheckInTime
		,tmpws.CheckOutTime
		,tmpws.CheckOutTime
		,0
		,tmpws.TotalHours
		,tmpws.IsCrossDay
		,tmpws.IsInAfterDay
		,tmpws.IsOutAfterDay
		,tmpws.ModifiedDate
		,@SyncDate
		,@SyncDate
		,0
        ,@CompanyId
        ,0
	FROM #tmpShift AS tmpws WITH (NOLOCK)
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.[Shift] AS s WITH (NOLOCK)
			WHERE s.CompanyId = @CompanyId
                AND s.Code = tmpws.ShiftCode
			)

    DECLARE @RowIndex INT = 1
        ,@ShiftId INT
        ,@OldShiftId INT

    WHILE EXISTS (
			SELECT 1
			FROM #tmpShiftId WITH (NOLOCK)
			WHERE RowIndex = @RowIndex
			)
	BEGIN
		SELECT @ShiftId = ShiftId
		FROM #tmpShiftId WITH (NOLOCK)
		WHERE RowIndex = @RowIndex

        SELECT @OldShiftId = MAX(OldShiftId)
        FROM dbo.[Shift] WITH (NOLOCK)
        WHERE CompanyId = @CompanyId

        SET @OldShiftId = ISNULL(@OldShiftId, 0) + 1

		UPDATE dbo.[Shift] WITH (ROWLOCK)
        SET OldShiftId = @OldShiftId
        WHERE ShiftID = @ShiftId

		SET @RowIndex = @RowIndex + 1
	END

    DROP TABLE #tmpShiftId
	DROP TABLE #tmpShift
END