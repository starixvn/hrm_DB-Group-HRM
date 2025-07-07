/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SalaryStructure_Get]
(
    @CompanyId SMALLINT
)
AS
/*
    Created: 202507040@Tim
    Task: get salary structure
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ss.SalaryStructureId, ss.[Name], ss.JobLevelId, jl.[Name] AS JobLevelName, ss.LocalSalary, ss.ExpatSalary
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
        INNER JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON ss.JobLevelId = jl.JobLevelId
    WHERE ss.CompanyId = @CompanyId
        AND jl.IsDeleted = 0
END