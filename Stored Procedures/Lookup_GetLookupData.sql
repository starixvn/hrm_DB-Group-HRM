/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lookup_GetLookupData] @CompanyId INT = NULL
	,@LookupCode VARCHAR(20)
AS
/*
Created: TOM@2013-10-21
Task: get lookup data
DB: HRM
Original:

Revisions:
	20251013@Jay: tranfer employee [Redmine: #233310]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT l_data.Id, l_data.LookupId, l_data.Code, l_data.[Name], l_data.[Value]
    FROM dbo.[Lookup] AS l_up WITH(NOLOCK)
		INNER JOIN dbo.LookupData AS l_data WITH(NOLOCK) ON l_up.Id = l_data.[LookupId]
	WHERE (@CompanyId IS NULL OR l_data.CompanyId = @CompanyId)
        AND l_up.Code = @LookupCode
	ORDER BY l_data.[Name]
END