USE NitgenAccessManager
GO

ALTER PROCEDURE [NitgenAdmin].[API_TimeRecord_Get]
(
	@FromDate DATETIME,
    @ToDate DATETIME
)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT u.EmployeeNum AS EmpNo
        ,CASE WHEN trans.FunctionKey = 1 THEN 0 ELSE 1 END AS InOutType
        ,trans.TransactionTime AS RecordTime
    FROM dbo.NGAC_AUTHLOG AS trans WITH (NOLOCK)
        INNER JOIN dbo.NGAC_USERINFO AS u WITH (NOLOCK) ON trans.UserID = u.ID
    WHERE trans.TransactionTime BETWEEN @FromDate AND @ToDate
        AND ISNULL(u.EmployeeNum, '') != ''
    ORDER BY trans.TransactionTime DESC
END