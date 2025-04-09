USE [bodb_HRM]
GO

ALTER TABLE [dbo].[Unit]  
ADD 
    GroupUnitId INT,
    PICEmpId INT,
    Category VARCHAR(200) NULL,
    Type VARCHAR(200) NULL,
    AccountableArea VARCHAR(200) NULL;

GO

--ALTER TABLE [dbo].[Unit]  
--ADD CONSTRAINT U_GroupUnitId UNIQUE (GroupUnitId);
--GO

ALTER TABLE [dbo].[Unit]  
DROP COLUMN OldUnitId, CompanyId;
GO

TRUNCATE TABLE [dbo].[Unit];
GO

ALTER TABLE [dbo].[Unit]  
ALTER COLUMN Name VARCHAR(200) NULL;
GO


DECLARE @tmpUnit TABLE (
    GroupUnitId INT,
    Code VARCHAR(255),
    Category VARCHAR(255),
	Type VARCHAR(255),
	AccountableArea VARCHAR(255),
	PICCtrId INT
 );

INSERT INTO @tmpUnit (GroupUnitId, Code, Category, Type, AccountableArea, PICCtrId)
VALUES
    (901, 'OT', 'Customer', '2C', '12 PSP', 1256),
    (902, 'SP', 'Customer', '2B', 'Casino & External', 197),
    (903, 'NV', 'Customer', '2C', 'B2C', 56),
    (905, 'CD', 'Customer', '2B', 'Credit', 37),
    (906, 'CL', 'Customer', '2B', 'Licensee', 233),
    (907, 'HM', 'Functional', 'Organization Development', 'HR & ADM - MNL', 51),
    (908, 'IM', 'Functional', 'Organization Development', 'IT Network - MNL', 51),
    (909, 'HH', 'Functional', 'Organization Development', 'HR & ADM - HCM', 51),
    (910, 'IH', 'Functional', 'Organization Development', 'IT Network - HCM', 51),
    (911, 'LG', 'Functional', 'Compliance', 'Legal & Corporate', 208),
    (913, 'FI', 'Functional', 'Compliance', 'Finance', 492),
    (914, 'C5', 'Information', 'Consultation', 'Consultant 5', 25),
    (915, 'C1', 'Information', 'Consultation', 'Consultant 1', 1),
    (916, 'C3', 'Information', 'Integration', 'Consultant 3', 1256),
    (917, 'CT', 'Information', 'Integration', 'Overall', 1256),
    (918, 'C2', 'Information', 'Consultation', 'Consultant 2', 1),
    (919, 'CI', 'Information', 'Integration', 'Technology', 611),
    (920, 'OL', 'Product', 'Product Development', 'OL', 204),
    (921, 'NF', 'Product', 'Product Development', 'NF', 1190),
    (922, 'LT', 'Product', 'Product Development', 'LT', 957),
    (923, 'HJ', 'Product', 'Product Development', 'CD', 918),
    (924, 'AT', 'Product', 'Product Development', '12 Aircast', 766),
    (925, 'NX', 'Product', 'Product Development', 'Nexcel', 117),
    (926, 'AU', 'Product', 'Data Processing', 'Automation', 74),
    (927, 'BK', 'Product', 'Data Processing', 'Basketball', 60),
    (928, 'ES', 'Product', 'Data Processing', 'E-Sports', 780),
    (929, 'OS', 'Product', 'Data Processing', 'Other Sports', 60),
    (930, 'CC', 'Product', 'Data Processing', 'Cricket', 60),
    (931, 'PH', 'Product', 'Data Processing', 'Pool House', 327),
    (932, 'RD', 'Product', 'Data Processing', 'R&D', 191),
    (933, 'SO', 'Product', 'Data Processing', 'Soccer', 190),
    (934, 'SV', 'Product', 'Data Processing', 'Support & VR', 391),
    (935, 'MW', 'Customer', '', 'Marketing', 1256),
    (936, 'SR', 'Functional', '', 'HRSSC', 204),
    (937, 'EV', 'Customer', '', 'EVO.IO', 34),
    (938, 'SS', 'Customer', '', 'Payment', 746),
    (939, 'SI', 'Product', 'Product Development', 'SSI Software Dev', 2254);


INSERT INTO [dbo].[Unit]
           ([Code]
		   ,[Name]
           ,[IsActive]
           ,[ModifiedBy]
           ,[ModifiedDate]
           ,[IsDeleted]
           ,[GroupUnitId]
           ,PICEmpId
           ,[Category]
           ,[Type]
           ,[AccountableArea])
     SELECT
           tmp.Code
		   ,NULL
           ,1
           ,NULL
           ,GETDATE()
           ,0
           ,tmp.GroupUnitId
           ,e.EmpId
           ,tmp.Category
           ,tmp.Type
           ,tmp.AccountableArea
	FROM @tmpUnit AS tmp 
	LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.CtrId = tmp.PICCtrId

    INSERT INTO [dbo].[Unit]
       ([Code]
       ,[IsActive]
       ,[ModifiedBy]
       ,[ModifiedDate]
       ,[IsDeleted]
       ,[GroupUnitId]
       ,[PICEmpId]
       ,[Category]
       ,[Type]
       ,[AccountableArea])
VALUES 
       ('Other', 1, NULL, GETDATE(), 0, 940, NULL, 'Other', NULL, NULL);
GO

