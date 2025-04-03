/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[TimeRecord_InsertCheckInOutTime] @EmpId INT
	,@RecordTime DATETIME
	,@InOutType TINYINT
	,@Platform VARCHAR(255)
	,@IPAddress VARCHAR(50)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20210527@Quinn.Vo
Task: Insert Check In/Out Time.
DB: HRM

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FromDate DATETIME
	DECLARE @ToDate DATETIME
	DECLARE @TimeRecoredId INT

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
	VALUES(@TimeRecoredId, @IPAddress, @Platform)

	SET @FromDate = CONVERT(VARCHAR(10), DATEADD(d, - 2, @RecordTime), 111)
	SET @ToDate = CONVERT(VARCHAR(10), @RecordTime, 111)

	EXEC EmployeeAttendance_ProcessingAndInsert @EmpId = @EmpId
		,@fromTime = @FromDate
		,@toTime = @ToDate
		,@onlyUpdate = 0
END