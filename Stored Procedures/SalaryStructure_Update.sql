/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SalaryStructure_Update]
(
    @SalaryStructureId INT
    ,@CompanyId SMALLINT
	,@Name NVARCHAR(255)
	,@Details VARCHAR(MAX)
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 202507040@Tim
    Task: create salary structure
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
		20251020@Lilac: rename LocalSalary to BasicSalary [Redmine: #241810]

    Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @xml XML
		,@logData NVARCHAR(MAX)
        ,@logOldData NVARCHAR(MAX)

	IF EXISTS (
		SELECT 1
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE CompanyId = @CompanyId
            AND [Name] = @Name
            AND SalaryStructureId != @SalaryStructureId
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The salary structure already exists.'

		RETURN
	END

    CREATE TABLE #tmpDetail (JobLevelId INT, BasicSalary VARCHAR(100), ExpatSalary VARCHAR(100))

    SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
            ,(
                SELECT JobLevelId AS '@JobLevelId'
		            ,BasicSalary AS '@BasicSalary'
		            ,ExpatSalary AS '@ExpatSalary'
                FROM dbo.SalaryStructureDetail WITH (NOLOCK)
                WHERE SalaryStructureId = @SalaryStructureId
                FOR XML PATH('Row'), TYPE
            ) AS Details
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		FOR XML PATH('Row'), TYPE
		)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

    INSERT INTO #tmpDetail (JobLevelId, BasicSalary, ExpatSalary)
    SELECT JobLevelId, BasicSalary, ExpatSalary
    FROM OPENJSON(@Details)
    WITH (JobLevelId INT, BasicSalary VARCHAR(100), ExpatSalary VARCHAR(100))
	
	UPDATE dbo.SalaryStructure WITH (ROWLOCK)
    SET CompanyId = @CompanyId
		,[Name] = @Name
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = GETDATE()
    WHERE SalaryStructureId = @SalaryStructureId

    DELETE FROM dbo.SalaryStructureDetail
    WHERE SalaryStructureId = @SalaryStructureId

    INSERT INTO dbo.SalaryStructureDetail (SalaryStructureId, JobLevelId, BasicSalary, ExpatSalary)
    SELECT @SalaryStructureId, JobLevelId, BasicSalary, ExpatSalary
    FROM #tmpDetail

    SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
            ,(
                SELECT JobLevelId AS '@JobLevelId'
		            ,BasicSalary AS '@BasicSalary'
		            ,ExpatSalary AS '@ExpatSalary'
                FROM dbo.SalaryStructureDetail WITH (NOLOCK)
                WHERE SalaryStructureId = @SalaryStructureId
                FOR XML PATH('Row'), TYPE
            ) AS Details
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		FOR XML PATH('Row'), TYPE
		)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 4
		,@ObjectId = @SalaryStructureId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

    DROP TABLE #tmpDetail
END