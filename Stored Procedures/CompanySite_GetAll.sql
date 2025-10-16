/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[CompanySite_GetAll]
/*
    Created: 20251016@Tim
    Task : Get all company site
    DB: bodb_HRM

    Revisions:
        20251016@Tim: init
*/
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CompanyId
        ,SiteId
        ,AccessToken
        ,Domain
    FROM dbo.CompanySite WITH (NOLOCK)
END