/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GroupScope_Update]
(
    @EmpId INT
    ,@CtrId INT = NULL
    ,@ModifiedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20250809Tim
    Task: update employee info 
    DB: bodb_HRM

    Revisions:
        - 20250806@Tim: init [Remine: #235227]
		- 20250814@Lilac: restructure for transfer [Redmine: #235678]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EmpId_exist INT
        ,@Nickname_exist NVARCHAR(20)
		,@FullName_exist NVARCHAR(50)
		,@Code_exist NVARCHAR(50)
		,@xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

	SELECT TOP 1 @EmpId_exist = ce.EmpId
        ,@Nickname_exist = ce.Nickname
		,@FullName_exist = emp.FullName
        ,@Code_exist = ce.Code
	FROM dbo.Employee AS emp WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.UserId = emp.UserId
	WHERE ce.EmpId != @EmpId
        AND @CtrId IS NOT NULL
		AND emp.CtrId = @CtrId

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Ctr ID ''' + CAST(@CtrId AS VARCHAR(20)) + ''' has been assigned to ''' + @Code_exist + ' - ' + @FullName_exist + '''.'

		RETURN
	END

	SET @xml = (
			SELECT emp.CtrId AS '@CtrId'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.UserId = emp.UserId
			WHERE ce.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	UPDATE emp WITH (ROWLOCK)
	SET emp.CtrId = @CtrId
	FROM dbo.Employee AS emp
	INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK)
		ON ce.UserId = emp.UserId
	WHERE ce.EmpId = @EmpId;


	SET @xml = (
			SELECT emp.CtrId AS '@CtrId'
			FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK)
				ON ce.UserId = emp.UserId
			WHERE ce.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 1
		,@ObjectId = @EmpId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END