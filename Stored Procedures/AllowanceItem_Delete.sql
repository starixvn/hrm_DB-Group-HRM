/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE   PROCEDURE [dbo].[AllowanceItem_Delete] (
	@AllowanceItemSettingId INT,
	@ModifiedBy INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
Created: 20251021@Jay.Do
Task: delete allowance item
DB: HRM
Original: 

Revisions:  
		20251029@Jay.Do: allowance item [Redmine: #241812]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	IF EXISTS(SELECT 1 
		FROM EmployeePayrollAllowance
		WHERE @AllowanceItemSettingId = AllowanceItemSettingId) 
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Cannot delete an allowance item that is in use'

		RETURN
	END

	DECLARE @xml XML,
		@logData NVARCHAR(MAX),
		@logOldData NVARCHAR(MAX) = NULL;

	SET @xml = (
			SELECT PayrollItemSettingId AS '@PayrollItemSettingId',
				ItemName AS '@ItemName',
				Amount AS '@Amount',
				IsPercent AS '@IsPercent',
				CreatedBy AS '@CreatedBy',
				CreatedDate AS '@CreatedDate',
				IsActive AS '@IsActive',
				IsDeleted AS '@IsDeleted'
			FROM dbo.[AllowanceItemSetting] WITH (NOLOCK)
			WHERE AllowanceItemSettingId = @AllowanceItemSettingId
			FOR XML PATH('Row')
				,TYPE
			)

	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')


	UPDATE AllowanceItemSetting
	SET IsDeleted = 1, IsActive = 0
	WHERE @AllowanceItemSettingId = AllowanceItemSettingId

	SET @xml = (
			SELECT PayrollItemSettingId AS '@PayrollItemSettingId',
				ItemName AS '@ItemName',
				Amount AS '@Amount',
				IsPercent AS '@IsPercent',
				CreatedBy AS '@CreatedBy',
				CreatedDate AS '@CreatedDate',
				IsActive AS '@IsActive',
				IsDeleted AS '@IsDeleted'
			FROM dbo.[AllowanceItemSetting] WITH (NOLOCK)
			WHERE AllowanceItemSettingId = @AllowanceItemSettingId
			FOR XML PATH('Row')
				,TYPE
			)

	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 8
		,@ActionId = 20
		,@ObjectId = @AllowanceItemSettingId
		,@OldData = @logOldData
		,@Data = @logData
END