/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[TimeRecord_Insert]
(
    @EmpId INT
	,@RecordTime DATETIME
	,@InOutType BIT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20160701@Quinn.Vo
    Task: insert time record.
    DB: bodb_HRM

    Revisions:
        20250428@Tim: fix bug passing param to calculate attendance
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FromDate DATETIME
        ,@ToDate DATETIME
        ,@CompanyId SMALLINT
        ,@serverTimeZone SMALLINT = -4
        ,@clientTimeZone FLOAT
        ,@clientRecordTime DATETIME

    SELECT @CompanyId = CompanyId
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId

    SELECT @clientTimeZone = config.Value
    FROM dbo.SystemConfigs AS config WITH (NOLOCK)
    WHERE config.CompanyId = @CompanyId
        AND config.[Key] = 'TimeZone'

    SET @clientTimeZone = ISNULL(@clientTimeZone, @serverTimeZone)

    SET @clientRecordTime = DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), @RecordTime))
    SET @FromDate = DATEADD(DAY, -2, @clientRecordTime)
    SET @ToDate = @clientRecordTime

	INSERT INTO [dbo].[TimeRecord] (
		EmpId
		,RecordTime
		,InOutType
		,InsertDate
		)
	VALUES (
		@EmpId
		,@RecordTime
		,@InOutType
		,GETDATE()
		)

	EXEC EmployeeAttendance_ProcessingAndInsert @EmpId = @EmpId
        ,@fromTime = @FromDate
        ,@toTime = @ToDate
        ,@onlyUpdate = 0
        ,@CompanyId = @CompanyId
END