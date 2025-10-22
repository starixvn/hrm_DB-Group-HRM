/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[SalaryStructure_GetById]
(
    @SalaryStructureId INT
)
AS
/*
    Created: 202507040@Tim
    Task: get salary structure by id
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
		20251020@Lilac: rename LocalSalary to BasicSalary [Redmine: #241810]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ss.SalaryStructureId,
        ss.[Name]
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
    WHERE ss.SalaryStructureId = @SalaryStructureId

    SELECT jl.JobLevelId, jl.[Name], dt.BasicSalary, dt.ExpatSalary, dt.JobLevelAddOn
    FROM dbo.JobLevel AS jl WITH (NOLOCK)
        LEFT JOIN dbo.SalaryStructureDetail AS dt WITH (NOLOCK) ON jl.JobLevelId = dt.JobLevelId
        AND dt.SalaryStructureId = @SalaryStructureId
        LEFT JOIN dbo.SalaryStructure AS ss WITH (NOLOCK) ON ss.SalaryStructureId = dt.SalaryStructureId
        AND ss.SalaryStructureId = @SalaryStructureId
    WHERE jl.IsDeleted = 0
    ORDER BY 
		LEFT(jl.[Name], CHARINDEX('-', jl.[Name] + '-') - 1) ASC,
		SUBSTRING(jl.[Name], CHARINDEX('-', jl.[Name] + '-') + 1, LEN(jl.[Name])) DESC;
END