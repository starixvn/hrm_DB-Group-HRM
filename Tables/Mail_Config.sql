CREATE TABLE [dbo].[Mail_Config](
	[AppId] [int] IDENTITY(1,1) NOT NULL,
	[AppName] [nvarchar](100) NOT NULL,
	[Description] [nchar](250) NULL,
	[SettingId] [int] NOT NULL,
	[MailFrom] [nvarchar](100) NULL,
	[IsEncrypt] [bit] NULL,
 CONSTRAINT [PK_MailConfig] PRIMARY KEY CLUSTERED 
(
	[AppId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Mail_Config] ADD CONSTRAINT [DF_Mail_Config_IsEncrypt]  DEFAULT ((0)) FOR [IsEncrypt]
GO