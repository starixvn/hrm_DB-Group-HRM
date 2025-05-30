USE [FBM]
GO
    ---------------Update EmpId For SMS----------
ALTER TABLE Employee 
ADD IsSecondment BIT NULL;

GO 

CREATE OR ALTER PROCEDURE [dbo].[API_SYN_Employee_Secondment]	
	@UserXML NVARCHAR(MAX)

	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
EXEC [dbo].[API_SYN_Employee]	
	@UserXML ='<ROOT>
	"<User UserId='{0}' EmpId='{1}' Password='{2}' Code='{3}' "
            + "NickName='{4}' FullName='{5}' DomainName='{6}' CompanyId='{7}' IsEnabled='{8}' "
            + " IsDeleted='{9}' JoinedDate='{10}' ModifiedDate='{11}' TeamId='{12}' IsLocal='{13}' "
            + " CardNumber='{14}' CostCenter='{15}'></User>"
</ROOT>'

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Password NVARCHAR(500)=N'hI/qAKGkHXu7UAzKE1t5p1n9xp0/koiy2W5L1g=='

	-- For write log
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogTraderData				NVARCHAR(MAX),	
		@LogTraderOldData			NVARCHAR(MAX),	
		@Xml						XML		 

	SET @StartRun = GETDATE()
	
	DECLARE @DocHandler INT

	SELECT @UserXML = REPLACE(ISNULL(@UserXML,''),'&','&amp;')
	
	PRINT LEN(@UserXML)

	IF OBJECT_ID('tempdb..#EmpRegister') IS NOT NULL
	BEGIN
		DROP TABLE #EmpRegister
	END

	CREATE TABLE #EmpRegister (		
		[EmpId] [int]  NULL,
		[UserId] [int]  NULL,
		[CompanyID] [smallint]  NULL,
		[DomainUsername] [varchar](50) NULL,
		[Code] [nvarchar](20)  NULL,
		[FullName] [nvarchar](150)  NULL,
		[NickName] [nvarchar](20) NULL,
		[CardNumber] [nvarchar](20) NULL,
		[Enabled] [bit]  NULL,
		[Password] [nvarchar](100) NULL,
		[isDeleted] [bit] NULL,
		[EmpCategoryID] [smallint] NULL,
		[IsLocal] [bit] NULL,
		[Roles] [varchar](20) NULL,
		[JoinedDate] [datetime] NULL,
		[DisableSync] [bit] NULL,
		[TeamID] [int] NULL,
		[ModifiedDate] [datetime] NULL,
		[CostCenter] [nvarchar](150) NULL,
		[IsSecondment] [bit] NULL,
		SynDate datetime NULL
	)
 
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@UserXML

		INSERT INTO #EmpRegister ([EmpId]
			,[UserId]
			  ,[CompanyID]
			  ,[DomainUsername]
			  ,[Code]
			  ,[FullName]
			  ,[NickName]
			  ,[Enabled]
			  ,[Password]
			  ,[isDeleted]
			  ,[EmpCategoryID]
			  ,[IsLocal]
			  ,[Roles]
			  ,[JoinedDate]
			  ,[DisableSync]
			  ,[TeamID]
			  ,[ModifiedDate]
			  ,SynDate
			  ,[CardNumber]
			  ,CostCenter
			  ,IsSecondment)
		SELECT [EmpId]
			,UserId
			  ,CompanyId
			  ,DomainName
			  ,[Code]
			  ,REPLACE([FullName],'&amp;','&') [FullName]
			  ,REPLACE([NickName],'&amp;','&') [NickName]
			  ,ISNULL(IsEnabled,1) IsEnabled
			  ,CASE WHEN LEN(ISNULL([Password],''))<3 THEN @Password ELSE [Password] END [Password]
			  ,ISNULL(IsDeleted,0) IsDeleted
			  ,NULL [EmpCategoryID]
			  ,[IsLocal]
			  ,'' [Roles]
			  ,CASE WHEN ISDATE([JoinedDate])=1 THEN [JoinedDate] ELSE NULL END [JoinedDate]
			  ,0 [DisableSync]
			  ,TeamId
			  ,CASE WHEN ISDATE(ModifiedDate)=1 THEN ModifiedDate ELSE NULL END ModifiedDate
			  ,GETDATE() SynDate
			  ,CardNumber
			  ,CostCenter
			  ,IsSecondment
		FROM OPENXML(@DocHandler, '/ROOT/User', 1) WITH (
				UserId [int],
				EmpId [int],
				CompanyId [smallint],
				DomainName varchar(50),
				Code [nvarchar](20),
				FullName [nvarchar](150),
				NickName [nvarchar](20),
				IsEnabled [bit],
				Password [nvarchar](100),
				IsDeleted [bit],
				IsLocal [bit],
				JoinedDate [nvarchar](100),
				TeamId [int],
				ModifiedDate [datetime],
				CardNumber [nvarchar](20),
				CostCenter [nvarchar](150),
				IsSecondment [bit]
				) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = N'Paramter invalid.'
		PRINT 1
		RETURN
	END CATCH;
	 
	INSERT INTO [dbo].[Employee] (
		UserId
		,[EmpId]
		,[CompanyID]
		,[DomainUsername]
		,[Code]
		,[FullName]
		,[NickName]
		,[Enabled]
		,[Password]
		,[isDeleted]
		,[IsLocal]
		,[Roles]
		,[JoinedDate]
		,EmpCategoryID
		,TeamID
		,SynDate
		,CardNumber
		,CostCenter
		,IsSecondment
		,IsFreeOrder
		)
	SELECT HM.UserId
		,HM.[EmpId]
		,HM.[CompanyID]
		,HM.[DomainUsername]
		,HM.[Code]
		,HM.[FullName]
		,HM.[NickName]
		,HM.[Enabled]
		,HM.[Password]
		,ISNULL(HM.[isDeleted], 0) [isDeleted]
		,CASE WHEN HM.[CompanyID] = 1 AND LTRIM(RTRIM(g.Name)) = 'Expat'  THEN 0 ELSE HM.[IsLocal] END
		,'' [Roles]
		,HM.[JoinedDate]	
		,CASE WHEN HM.[CompanyID] = 1 AND LTRIM(RTRIM(g.Name)) = 'Expat'  THEN 4
			WHEN HM.[CompanyID] IN (1,3, 4) THEN 5
			WHEN HM.[IsLocal]=0 THEN 1 
			WHEN HM.[IsLocal]=1 AND LTRIM(RTRIM(g.Code)) = 'UNIT 7' THEN 3
			ELSE 2  END EmpCategoryID 
		,HM.TeamID
		,HM.SynDate
		,HM.CardNumber
		,CASE WHEN HM.[CompanyID] = 1 THEN 'Nexcel' ELSE
		CASE WHEN HM.[CompanyID] = 4 THEN 'Luminet' ELSE
		CASE WHEN HM.[CompanyID] = 3 THEN 'Hong Ma' ELSE HM.CostCenter END END END
		,HM.IsSecondment
		,1
	FROM #EmpRegister HM WITH (NOLOCK)
		LEFT JOIN  [dbo].[Employee] FB ON
			HM.[EmpId] = FB.EmpId AND FB.[CompanyID] = HM.[CompanyID]
		LEFT JOIN [dbo].[EmpTeam] g WITH (NOLOCK) ON HM.TeamID = g.EmpTeamId  AND g.[CompanyID] = HM.[CompanyID]
	WHERE FB.EmpId IS NULL 

	UPDATE FB  
	SET FB.UserId = HM.UserId
		,FB.DomainUsername= ISNULL(HM.DomainUsername,'') 
		, FB.Code = ISNULL(HM.Code,'')	
		, FB.FullName = ISNULL(HM.FullName,'')	
		, FB.NickName = ISNULL(HM.NickName,'')	
		, FB.Enabled = ISNULL(HM.Enabled,'')	
		, FB.Password= CASE WHEN HM.[CompanyID] = 1 THEN FB.Password ELSE ISNULL(HM.Password,'') END
		, FB.isDeleted =ISNULL(HM.isDeleted,0)	
		, FB.JoinedDate = ISNULL(HM.JoinedDate,'2011-01-01') 
		, FB.TeamID= ISNULL(HM.TeamID,0)
		
		, FB.IsLocal = CASE WHEN HM.[CompanyID] = 1 AND LTRIM(RTRIM(g.Name)) = 'Expat'  THEN 0 ELSE HM.[IsLocal] END
		, FB.EmpCategoryID	=CASE 
			WHEN HM.[CompanyID] = 1 AND LTRIM(RTRIM(g.Name)) = 'Expat'  THEN 4
			WHEN HM.[CompanyID] IN (1,3, 4) THEN 5
			WHEN HM.[IsLocal]=0 THEN 1 
			WHEN HM.[IsLocal]=1 AND LTRIM(RTRIM(g.Code)) = 'UNIT 7' THEN 3
			ELSE 2 END
		,FB.SynDate = HM.SynDate
		,FB.CardNumber = HM.CardNumber
		,FB.CostCenter = CASE WHEN HM.[CompanyID] = 1 THEN 'Nexcel' ELSE
		CASE WHEN HM.[CompanyID] = 4 THEN 'Luminet' ELSE
		CASE WHEN HM.[CompanyID] = 3 THEN 'Hong Ma' ELSE HM.CostCenter END END END
	FROM [dbo].[Employee] FB
			INNER JOIN  #EmpRegister HM WITH (NOLOCK) ON HM.[EmpId] = FB.EmpId AND FB.[CompanyID] = HM.[CompanyID]
			LEFT JOIN [dbo].[EmpTeam] g WITH (NOLOCK) ON HM.TeamID = g.EmpTeamId  AND g.[CompanyID] = HM.[CompanyID]

	UPDATE FB
	SET FB.isDeleted = 1
	FROM [dbo].[Employee] FB
	LEFT JOIN  #EmpRegister ER WITH (NOLOCK) ON FB.EmpId = ER.EmpId
	WHERE FB.IsSecondment = 1 AND ISNULL(FB.isDeleted, 0) = 0 AND ER.EmpId IS NULL


	INSERT INTO [dbo].[EmpRole](SysID,RoleId)
	SELECT FB.SysID, 4  RoleId
	FROM [dbo].[Employee] FB 
	LEFT JOIN [dbo].[EmpRole] ER
		ON FB.SysID = ER.SysId
				AND ER.RoleId = 4
	WHERE ER.SysId IS NULL 

	SELECT @ErrCode = 0, @ErrMsg = ''

	DECLARE @Departments VARCHAR(100)=''
		
	SELECT @Departments = tbl.[CompanyID]
			FROM #EmpRegister tbl 


	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 

	EXEC	dbo.SYS_WriteLog_RunSp
			@UserId		= NULL,
			@SPName		= 'API_SYN_Employee_Secondment',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @Departments,
			@Data		= @LogTraderData,
			@OldData	= @LogTraderOldData

END

GO

