/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SalaryStructure_Delete]
(
    @SalaryStructureId INT
	,@DeletedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 202507040@Tim
    Task: delete salary structure
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
		20251020@Lilac: rename LocalSalary to BasicSalary [Redmine: #241810]
		20251028@Henry: move salary structure to employee payroll [Redmine: #241812]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @xml XML
        ,@logOldData NVARCHAR(MAX)

	IF EXISTS (
		SELECT 1
		FROM dbo.CompanyEmployee AS ce WITH (NOLOCK) 
		INNER JOIN EmployeePayroll AS ep ON ep.EmpId = ce.EmpId
		WHERE ep.SalaryStructureId = @SalaryStructureId
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The salary structure cannot be deleted because it is already in use.'

		RETURN
	END

    SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
            ,(
                SELECT JobLevelId AS '@JobLevelId'
		            ,BasicSalary AS '@BasicSalary'
		            ,ExpatSalary AS '@ExpatSalary'
		            ,JobLevelAddOn AS '@JobLevelAddOn'
                FROM dbo.SalaryStructureDetail WITH (NOLOCK)
                WHERE SalaryStructureId = @SalaryStructureId
                FOR XML PATH('Row'), TYPE
            ) AS Details
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		FOR XML PATH('Row'), TYPE
		)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	
	DELETE dbo.SalaryStructure WITH (ROWLOCK)
    WHERE SalaryStructureId = @SalaryStructureId

	EXEC dbo.ActivityLog_Insert @UserId = @DeletedBy
		,@ObjectTypeId = 4
		,@ObjectId = @SalaryStructureId
		,@OldData = @logOldData
		,@Data = NULL
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END