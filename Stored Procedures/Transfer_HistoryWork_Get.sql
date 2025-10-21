/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Transfer_HistoryWork_Get]
(
    @EmpId INT
)
AS
/*
    Created: 20251013@Jay
    Task: get transfer history work
    DB: bodb_HRM

    Revisions:
		20251013@Jay: tranfer employee [Redmine: #233310]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT LogDate,
		OldValue AS OldData,
		[Value] AS [Data],
		Field,
		ce.Nickname
	FROM dbo.HistoryWork AS hw (NOLOCK)
	    LEFT JOIN dbo.CompanyEmployee AS ce (NOLOCK) ON ce.EmpId = hw.ModifiedBy
	WHERE hw.EmpId = @EmpId
	ORDER BY LogDate DESC
END