/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ExtensionNO_GetGroupInfo]
	@isInternal BIT = NULL,
	@TeamId INT = NULL,
	@CompanyId INT
AS
/*
Created: Tom.Vo@2014-01-04
Task: Get list group Extensions Number
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON
IF @isInternal IS NULL
	SELECT exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) TeamID		
		  ,ISNULL(g.Code,'') Team
		  ,COALESCE(g.Name,exg.[FullName]) TeamName
		  ,SUM(CASE WHEN exm.[ExtID] IS NOT NULL THEN 1 ELSE 0 END ) TotalMember
		  ,exg.IsInternal
		  ,exg.[OrderNo] 
	  FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK)
		LEFT JOIN dbo.[Group] g WITH(NOLOCK)
			ON exg.GroupID = g.GroupID AND exg.IsInternal = 1 AND exg.IsGroup =1
		LEFT JOIN dbo.ExtensionNumbers exm WITH(NOLOCK)
			ON exm.IsGroup = 0 AND (
				(exg.GroupID  = exm.GroupID AND exm.IsInternal = 1)
				OR (exg.[ExtID]  = exm.GroupID AND exm.IsInternal = 0)
			)
	 WHERE exg.IsGroup =1 AND exg.CompanyId = @CompanyId
	 GROUP BY exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID])
		  ,ISNULL(g.Code,'') 
		  ,COALESCE(g.Name,exg.[FullName])
		  ,exg.IsInternal
		  ,exg.[OrderNo] 
		  	 
 ELSE IF @TeamId IS NULL
	SELECT exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) TeamID		
		  ,ISNULL(g.Code,'') Team
		  ,COALESCE(g.Name,exg.[FullName]) TeamName
		  ,SUM(CASE WHEN exm.[ExtID] IS NOT NULL THEN 1 ELSE 0 END ) TotalMember
		  ,exg.IsInternal
		  ,exg.[OrderNo] 
	  FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK)
		LEFT JOIN dbo.[Group] g WITH(NOLOCK)
			ON exg.GroupID = g.GroupID AND exg.IsInternal = 1 
		LEFT JOIN dbo.ExtensionNumbers exm WITH(NOLOCK)
			ON exm.IsGroup = 0 AND (
				(exg.GroupID  = exm.GroupID AND exm.IsInternal = 1)
				OR (exg.[ExtID]  = exm.GroupID AND exm.IsInternal = 0)
			)
	 WHERE exg.IsGroup =1 AND exg.CompanyId = @companyId AND 
			@isInternal =  exg.IsInternal 
	GROUP BY exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) 
		  ,ISNULL(g.Code,'') 
		  ,COALESCE(g.Name,exg.[FullName]) 
		  ,exg.IsInternal
		  ,exg.[OrderNo] 	 
 ELSE IF @TeamId IS NOT NULL
	SELECT exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) TeamID		
		  ,ISNULL(g.Code,'') Team
		  ,COALESCE(g.Name,exg.[FullName]) TeamName
		  ,SUM(CASE WHEN exm.[ExtID] IS NOT NULL THEN 1 ELSE 0 END ) TotalMember
		  ,exg.IsInternal
		  ,exg.[OrderNo] 
	  FROM [dbo].[ExtensionNumbers] exg WITH(NOLOCK)
		LEFT JOIN dbo.[Group] g WITH(NOLOCK)
			ON exg.GroupID = g.GroupID AND exg.IsInternal = 1 
		LEFT JOIN dbo.ExtensionNumbers exm WITH(NOLOCK)
			ON exm.IsGroup = 0 AND (
				(exg.GroupID  = exm.GroupID AND exm.IsInternal = 1)
				OR (exg.[ExtID]  = exm.GroupID AND exm.IsInternal = 0)
			)
	 WHERE exg.IsGroup =1 AND exg.CompanyId = @companyId AND 
			@isInternal =  exg.IsInternal AND 
			@TeamId = CASE WHEN @isInternal = 1 THEN exg.[GroupID]
							WHEN @isInternal = 0 THEN exg.[ExtID]
							END
	GROUP BY exg.[ExtID]
		  ,COALESCE(g.[GroupID],exg.[ExtID]) 
		  ,ISNULL(g.Code,'') 
		  ,COALESCE(g.Name,exg.[FullName]) 
		  ,exg.IsInternal
		  ,exg.[OrderNo]



