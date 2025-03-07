/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CompanySite_GetByDomain] @Domain VARCHAR(100)
/*
Created: 20250305@Tim
Task : Get site by domain
DB: bodb_HRM

Revisions:
	20250305@Tim: initial - [Redmine: #217976]
*/
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CompanyId
        ,SiteId
        ,AccessToken
        ,Domain
    FROM dbo.CompanySite WITH (NOLOCK)
    WHERE Domain = @Domain
END