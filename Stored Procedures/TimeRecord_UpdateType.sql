/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[TimeRecord_UpdateType]
(
	@RecordTimeId INT
	,@InOutType TINYINT
	,@ModifiedBy INT
	,@ModifiedDate DATETIME
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20140724@Quinn.Vo
    Task: Update Time Record.
    DB: bodb_HRM

    Revisions:
        20250422@Tim: fix bug passing param to calculate attendance
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EmpId INT
        ,@FromDate DATE
        ,@ToDate DATE
        ,@RecordTime DATETIME
        ,@CompanyId SMALLINT
        ,@serverTimeZone SMALLINT = -4
        ,@clientTimeZone FLOAT

	SELECT @EmpId = EmpId
        ,@RecordTime = RecordTime
	FROM dbo.TimeRecord WITH (NOLOCK)
	WHERE ID = @RecordTimeId

    SELECT @CompanyId = CompanyId
    FROM dbo.CompanyEmployee WITH (NOLOCK)
    WHERE EmpId = @EmpId

    SELECT @clientTimeZone = config.Value
    FROM dbo.SystemConfigs AS config WITH (NOLOCK)
    WHERE config.CompanyId = @CompanyId
        AND config.[Key] = 'TimeZone'

    SET @clientTimeZone = ISNULL(@clientTimeZone, @serverTimeZone)

    SET @RecordTime = DATEADD(MINUTE, @clientTimeZone * 60, DATEADD(HOUR, ABS(@serverTimeZone), @RecordTime))
    SET @FromDate = DATEADD(DAY, -1, @RecordTime)
    SET @ToDate = @RecordTime

	UPDATE dbo.TimeRecord WITH (ROWLOCK)
	SET InOutType = @InOutType,
		ModifiedBy = @ModifiedBy,
		ModifiedDate = @ModifiedDate
	WHERE ID = @RecordTimeId

	EXEC EmployeeAttendance_ProcessingAndInsert @EmpId = @EmpId
        ,@fromTime = @FromDate
        ,@toTime = @ToDate
        ,@onlyUpdate = 1
        ,@CompanyId = @CompanyId
END