CREATE TABLE [dbo].[Mail_Error](
	[ErrorId] [bigint] IDENTITY(1,1) NOT NULL,
	[MailId] [bigint] NULL,
	[AppId] [int] NULL,
	[Message] [nvarchar](1000) NULL,
	[StackTrace] [nvarchar](2000) NULL,
	[SettingName] [nvarchar](250) NULL,
	[ErrorTime] [datetime] NULL,
 CONSTRAINT [PK_Mail_Error] PRIMARY KEY CLUSTERED 
(
	[ErrorId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO