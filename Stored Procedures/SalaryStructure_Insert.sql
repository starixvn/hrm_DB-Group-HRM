/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SalaryStructure_Insert]
(
    @CompanyId SMALLINT
	,@Name NVARCHAR(255)
	,@JobLevelId INT
    ,@LocalSalary VARCHAR(100)
    ,@ExpatSalary VARCHAR(100)
	,@CreatedBy INT
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
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @SalaryStructureId INT
		,@xml XML
		,@logData NVARCHAR(MAX)

	IF EXISTS (
		SELECT 1
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE CompanyId = @CompanyId
            AND [Name] = @Name
            AND JobLevelId = @JobLevelId
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The salary structure already exists.'

		RETURN
	END
	
	INSERT INTO dbo.SalaryStructure (
		CompanyId
		,[Name]
		,JobLevelId
		,LocalSalary
		,ExpatSalary
		,[IsActive]
		,CreatedBy
		,CreatedDate
		)
	VALUES (
		@CompanyId
		,@Name
		,@JobLevelId
		,@LocalSalary
		,@ExpatSalary
		,1
		,@CreatedBy
		,GETDATE()
		)

    SELECT @SalaryStructureId = SCOPE_IDENTITY()

    SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
		    ,JobLevelId AS '@JobLevelId'
		    ,LocalSalary AS '@LocalSalary'
		    ,ExpatSalary AS '@ExpatSalary'
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		FOR XML PATH('Row')
			,TYPE
		)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 4
		,@ObjectId = @SalaryStructureId
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END