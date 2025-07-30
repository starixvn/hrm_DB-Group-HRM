/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SalaryStructure_GetById]
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
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ss.SalaryStructureId,
        ss.[Name]
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
    WHERE ss.SalaryStructureId = @SalaryStructureId

    SELECT jl.JobLevelId, jl.[Name], dt.LocalSalary, dt.ExpatSalary
    FROM dbo.JobLevel AS jl WITH (NOLOCK)
        LEFT JOIN dbo.SalaryStructureDetail AS dt WITH (NOLOCK) ON jl.JobLevelId = dt.JobLevelId
        AND dt.SalaryStructureId = @SalaryStructureId
        LEFT JOIN dbo.SalaryStructure AS ss WITH (NOLOCK) ON ss.SalaryStructureId = dt.SalaryStructureId
        AND ss.SalaryStructureId = @SalaryStructureId
    WHERE jl.IsDeleted = 0
END