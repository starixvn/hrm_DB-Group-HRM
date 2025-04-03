/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CompanySite_GetByDomain] @Domain VARCHAR(100)
/*
Created: 20250305@Tim
Task : Get site by domain
DB: HRM

Revisions:
*/
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CompanyId
        ,SiteId
        ,AccessToken
        ,Domain
    FROM dbo.CompanySite WITH (NOLOCK)
    WHERE REPLACE(Domain, 'https://', '') = REPLACE(@Domain, 'https://', '')
        OR REPLACE(Domain, 'http://', '') = REPLACE(@Domain, 'http://', '')
END