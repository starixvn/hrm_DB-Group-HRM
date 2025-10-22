/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[SalaryStructure_Get]
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
		20250812@Mira: tranfer employee [Redmine: #235678]
		20251020@Lilac: rename LocalSalary to BasicSalary, add JobLevelAddOn [Redmine: #241810]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ss.SalaryStructureId, ss.[Name]
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
    WHERE ss.CompanyId = @CompanyId
    ORDER BY ss.[Name] ASC

    SELECT ss.SalaryStructureId, jl.JobLevelId, jl.[Name], dt.BasicSalary, dt.ExpatSalary, dt.JobLevelAddOn
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
        INNER JOIN dbo.SalaryStructureDetail AS dt WITH (NOLOCK) ON ss.SalaryStructureId = dt.SalaryStructureId
        INNER JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON dt.JobLevelId = jl.JobLevelId
    WHERE ss.CompanyId = @CompanyId
        AND jl.IsDeleted = 0
    ORDER BY 
		LEFT(jl.[Name], CHARINDEX('-', jl.[Name] + '-') - 1) ASC,
		SUBSTRING(jl.[Name], CHARINDEX('-', jl.[Name] + '-') + 1, LEN(jl.[Name])) DESC;
END