/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lookup_GetLookupData]
	@lookupCode varchar(20),
	@companyId INT
AS
/*
Created: TOM@2013-10-21
Task: Retrieve data on Lookup Date
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	select l_Data.* from 
		dbo.Lookup l_up WITH(NOLOCK)
		INNER JOIN dbo.LookupData l_Data WITH(NOLOCK)
			ON l_up.Id = l_Data.[LookupId] and l_Data.CompanyId = @companyId
		where l_up.Code = @lookupCode
	order by l_Data.[Name]
END
