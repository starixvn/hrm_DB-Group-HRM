/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Transfer_HistoryWork_Get]
(
    @EmpId INT,
	@CompanyId INT = NULL
)
AS
/*
    Created: 20251013@Jay
    Task: get transfer history work
    DB: bodb_HRM

    Revisions:
		20251013@Jay: tranfer employee [Redmine: #233310]
		20251028@Jay: tranfer employee p3 [Redmine: #242668]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT LogDate,
		OldValue AS OldData,
		[Value] AS [Data],
		Field,
		CASE
			WHEN ce.CompanyId != @CompanyId 
				THEN ce.NickName + ' (' + c.[Name] + ')' 
			ELSE ce.NickName
		END AS NickName
	FROM dbo.HistoryWork AS hw (NOLOCK)
	    LEFT JOIN dbo.CompanyEmployee AS ce (NOLOCK) ON ce.EmpId = hw.ModifiedBy
		LEFT JOIN dbo.Company c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE hw.EmpId = @EmpId
	ORDER BY LogDate DESC
END