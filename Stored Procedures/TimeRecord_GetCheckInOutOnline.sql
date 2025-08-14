/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[TimeRecord_GetCheckInOutOnline] @CompanyId SMALLINT
    ,@Date DATE
AS
/*
Created: Tim@21-10-2024
Task: Get check in/out online
DB: HRM

Revisions:
	20250812@Mira: tranfer employee [Redmine: #235678]

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FromTime DATETIME = @Date
		,@ToTime DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, @Date), '23:59:59.99')

	SELECT TOP 500 t.Id AS RecordTimeId
		,t.RecordTime
		,t.InOutType
		,ce.EmpId
		,ce.Code
		,ce.NickName
		,e.FullName
	FROM dbo.TimeRecord AS t WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON t.EmpID = ce.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.TimeRecordExt AS tex WITH (NOLOCK) ON t.ID = tex.ID
	WHERE ce.CompanyId = @CompanyId
        AND t.RecordTime BETWEEN @FromTime
			AND @ToTime
	ORDER BY t.RecordTime DESC
END