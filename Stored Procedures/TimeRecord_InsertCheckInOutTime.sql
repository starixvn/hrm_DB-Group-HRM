/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[TimeRecord_InsertCheckInOutTime]
(
    @EmpId INT
	,@RecordTime DATETIME
    ,@ClientRecordTime DATETIME
	,@InOutType TINYINT
	,@Platform VARCHAR(255)
	,@IPAddress VARCHAR(50)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20210527@Quinn.Vo
    Task: Insert Check In/Out Time.
    DB: bodb_HRM

    Revisions:
        20250408@Tim: fix bug failed to retrieve the Attendance Report data [Redmine: #222721]
    Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FromDate DATETIME
        ,@ToDate DATETIME
        ,@TimeRecoredId INT

	INSERT INTO [dbo].[TimeRecord] (
		EmpId
		,RecordTime
		,InOutType
		,InsertDate
		)
	VALUES (
		@EmpId
		,@RecordTime
		,CASE WHEN @InOutType = 0 THEN 0 ELSE 1 END
		,GETDATE()
		)

	SELECT @TimeRecoredId = CAST(SCOPE_IDENTITY() AS INT)

	INSERT INTO dbo.TimeRecordExt(ID, IPAddress, [Platform])
	VALUES (@TimeRecoredId, @IPAddress, @Platform)

	SET @FromDate = CONVERT(VARCHAR(10), DATEADD(d, - 2, @ClientRecordTime), 111)
	SET @ToDate = CONVERT(VARCHAR(10), @ClientRecordTime, 111)

	EXEC EmployeeAttendance_ProcessingAndInsert @EmpId = @EmpId
		,@fromTime = @FromDate
		,@toTime = @ToDate
		,@onlyUpdate = 0
END