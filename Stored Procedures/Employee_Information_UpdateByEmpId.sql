/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Information_UpdateByEmpId]
(
    @EmpId INT
    ,@DOB DATE = NULL
    ,@Email VARCHAR(50) = NULL
    ,@Phone VARCHAR(50) = NULL
    ,@Gender TINYINT = NULL
    ,@LetsTalk VARCHAR(100) = ''
    ,@Marriage TINYINT = 1
    ,@PermanentAddress NVARCHAR(250) = ''
    ,@CurrentAddress NVARCHAR(250) = ''
    ,@IdCardNumber VARCHAR(20) = ''
    ,@PassportNo VARCHAR(35) = ''
    ,@PassportExp DATE = NULL
    ,@ChineseName NVARCHAR(200) = NULL
    ,@ModifiedBy INT
    ,@CountryCode VARCHAR(5) = NULL
    ,@PlaceOfbirth NVARCHAR(250) = ''
    ,@Ethnic NVARCHAR(250) = ''
    ,@Native NVARCHAR(250) = ''
    ,@Religion NVARCHAR(250) = ''
    ,@DateOfIDCard DATE = NULL
    ,@PlaceOfIDCard NVARCHAR(250) = ''
    ,@HomePhone NVARCHAR(250) = ''
    ,@Qualification NVARCHAR(300) = ''
    ,@Major NVARCHAR(300) = ''
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom
    Task: update an employee information
    DB: bodb_HRM

    Revisions:
        20250722@Tim: remove skype
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)
	
	SET @xml = (
		SELECT DOB AS '@DOB'
			,Email AS '@Email'
			,Phone AS '@Phone'
			,Gender AS '@Gender'
			,LetsTalk AS '@LetsTalk'
			,Marriage AS '@Marriage'
			,PermanentAddress AS '@PermanentAddress'
			,CurrentAddress AS '@CurrentAddress'
			,IdCardNumber AS '@IdCardNumber'
			,PassportNo AS '@PassportNo'
			,PassportExp AS '@PassportExp'
			,ChineseName AS '@ChineseName'
			,PlaceOfbirth AS '@PlaceOfbirth'
			,Ethnic AS '@Ethnic'
			,[Native] AS '@Native'
			,Religion AS '@Religion'
			,DateOfIDCard AS '@DateOfIDCard'
			,PlaceOfIDCard AS '@PlaceOfIDCard'
			,HomePhone AS '@HomePhone'
			,Qualification AS '@Qualification'
			,Major AS '@Major'
			,CountryCode AS '@CountryCode'
		FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		WHERE emp.EmpId = @EmpId
		FOR XML PATH('Row')
			,TYPE
		)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	UPDATE dbo.Employee WITH (ROWLOCK)
	SET DOB = @DOB
		,Email = @Email
		,Phone = @Phone
		,Gender = @Gender
		,LetsTalk = @LetsTalk
		,Marriage = @Marriage
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
		,PermanentAddress = @PermanentAddress
		,CurrentAddress = @CurrentAddress
		,IdCardNumber = @IdCardNumber
		,PassportNo = @PassportNo
		,PassportExp = @PassportExp
		,ChineseName = @ChineseName
		,PlaceOfbirth = @PlaceOfbirth
		,Ethnic = @Ethnic
		,[Native] = @Native
		,Religion = @Religion
		,DateOfIDCard = @DateOfIDCard
		,PlaceOfIDCard = @PlaceOfIDCard
		,HomePhone = @HomePhone
		,Qualification = @Qualification
		,Major = @Major
	WHERE EmpId = @EmpId

	UPDATE dbo.EmployeeSummary WITH (ROWLOCK)
	SET CountryCode = @CountryCode
	WHERE EmpId = @EmpId
	
	SET @xml = (
		SELECT DOB AS '@DOB'
			,Email AS '@Email'
			,Phone AS '@Phone'
			,Gender AS '@Gender'
			,LetsTalk AS '@LetsTalk'
			,Marriage AS '@Marriage'
			,PermanentAddress AS '@PermanentAddress'
			,CurrentAddress AS '@CurrentAddress'
			,IdCardNumber AS '@IdCardNumber'
			,PassportNo AS '@PassportNo'
			,PassportExp AS '@PassportExp'
			,ChineseName AS '@ChineseName'
			,PlaceOfbirth AS '@PlaceOfbirth'
			,Ethnic AS '@Ethnic'
			,[Native] AS '@Native'
			,Religion AS '@Religion'
			,DateOfIDCard AS '@DateOfIDCard'
			,PlaceOfIDCard AS '@PlaceOfIDCard'
			,HomePhone AS '@HomePhone'
			,Qualification AS '@Qualification'
			,Major AS '@Major'
			,CountryCode AS '@CountryCode'
		FROM dbo.Employee AS emp WITH (NOLOCK)
			INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
		WHERE emp.EmpId = @EmpId
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