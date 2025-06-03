USE NitgenAccessManager
GO

ALTER PROCEDURE API_TimeRecord_Get
(
	@FromDate DATETIME,
    @ToDate DATETIME
)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT u.EmployeeNum AS EmpNo
        ,CASE WHEN trans.FunctionKey = 1 THEN 0 ELSE 1 END AS InOutType
        ,trans.ServerRecordTime AS RecordTime
    FROM dbo.NGAC_AUTHLOG AS trans WITH (NOLOCK)
        INNER JOIN dbo.NGAC_USERINFO AS u WITH (NOLOCK) ON trans.UserID = u.ID
    WHERE trans.ServerRecordTime BETWEEN @FromDate AND @ToDate
    ORDER BY trans.ServerRecordTime DESC
END