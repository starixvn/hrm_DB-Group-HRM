USE [bodb_HRM]
GO
/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[AllowanceItem_Create] (
	@PayrollItemSettingId INT,
	@ItemName NVARCHAR(255),
	@Amount NVARCHAR(255),
	@IsPercent BIT,
	@IsActive BIT,
	@ModifiedBy INT
)
AS
/*
Created: 20251021@Jay.Do
Task: create allowance item
DB: HRM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	INSERT INTO [dbo].[AllowanceItemSetting] 
			(PayrollItemSettingId, ItemName, Amount, IsPercent, CreatedBy, CreatedDate, IsActive, IsDeleted)
	VALUES	(@PayrollItemSettingId, @ItemName, @Amount, @IsPercent, @ModifiedBy, GETDATE(), @IsActive, 0)
END