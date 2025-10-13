/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[SalaryStructure_Get]
(
    @CompanyId SMALLINT = NULL
)
AS
/*
    Created: 202507040@Tim
    Task: get salary structure
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
		20250812@Mira: tranfer employee [Redmine: #235678]
		20251013@Jay: tranfer employee [Redmine: #233310]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ss.SalaryStructureId, ss.[Name]
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
    WHERE (@CompanyId IS NULL OR ss.CompanyId = @CompanyId)
    ORDER BY ss.[Name]

    SELECT ss.SalaryStructureId, jl.JobLevelId, jl.[Name], dt.LocalSalary, dt.ExpatSalary
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
        INNER JOIN dbo.SalaryStructureDetail AS dt WITH (NOLOCK) ON ss.SalaryStructureId = dt.SalaryStructureId
        INNER JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON dt.JobLevelId = jl.JobLevelId
    WHERE (@CompanyId IS NULL OR ss.CompanyId = @CompanyId)
        AND jl.IsDeleted = 0
    ORDER BY ss.SalaryStructureId, jl.[Name]
END