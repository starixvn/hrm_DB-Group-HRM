/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


ALTER PROCEDURE [dbo].[ExtensionNO_Insert_EmployeeInfo]
	@FullName nvarchar(200)=NULL,
    @NickName nvarchar(100)=NULL,
    @ExtensionNo nvarchar(200),
    @IsInternal bit,
    @EmpID int=NULL,
    @TeamId int,
    @OrderNo smallint=1,
	@CompanyId INT,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2014-01-04
Task: Insert Employee Extensions Number
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

DECLARE @IsGroup bit=0

SET @IsInternal = ISNULL(@IsInternal,1)
IF @IsInternal = 1
BEGIN
	IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.Employee WITH(NOLOCK) WHERE EmpID = @EmpID)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = N'Parameter EmpID not exists on systems.'
		RETURN
	END
END
ELSE
BEGIN
	IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE ExtID = @TeamId AND [IsGroup]=1  AND IsInternal = 0)
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = N'Parameter EmpID not exists on systems.'
		RETURN
	END
END

IF @IsInternal = 1
BEGIN
	IF NOT EXISTS(SELECT TOP 1 1 FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE [GroupID] = @TeamId AND [IsInternal] = 1)
	BEGIN
		INSERT INTO [ExtensionNumbers]
			(
			   [FullName]
			  ,[NickName]
			  ,[ExtensionNo]
			  ,IsInternal
			  ,[IsGroup]
			  ,[EmpID]
			  ,[GroupID]
			  ,[OrderNo]
			  ,[CompanyId]
			)
		SELECT  N'' [FullName]
			  ,'' [NickName]
			  ,'' [ExtensionNo]
			  ,1 IsInternal
			  ,1 [IsGroup]
			  ,NULL [EmpID]
			  ,@TeamId [GroupID]
			  ,MAX([OrderNo])
			  ,@CompanyId 
		FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK) WHERE [GroupID] <> @TeamId AND [IsInternal] = 1
	END

	INSERT INTO [dbo].[ExtensionNumbers]
			   ([FullName]
			   ,[NickName]
			   ,[ExtensionNo]
			   ,[IsInternal]
			   ,[IsGroup]
			   ,[EmpID]
			   ,[GroupID]
			   ,[OrderNo]
			   ,[CompanyId])
		 VALUES
			   (@FullName,
				@NickName,
				@ExtensionNo,
				@IsInternal,
				@IsGroup,
				@EmpID,
				@TeamId,
				@OrderNo,
				@CompanyId)

END
ELSE
BEGIN
	INSERT INTO [dbo].[ExtensionNumbers]
			   ([FullName]
			   ,[NickName]
			   ,[ExtensionNo]
			   ,[IsInternal]
			   ,[IsGroup]
			   ,[EmpID]
			   ,[GroupID]
			   ,[OrderNo]
			   ,[CompanyId])
		 VALUES
			   (@FullName,
				@NickName,
				@ExtensionNo,
				@IsInternal,
				@IsGroup,
				NULL,
				@TeamId,
				@OrderNo,
				@CompanyId)
END
SET @ErrCode=0



