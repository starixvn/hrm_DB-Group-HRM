CREATE TABLE [dbo].[Mail_Record](
	[MailId] [bigint] IDENTITY(1,1) NOT NULL,
	[AppId] [int] NOT NULL,
	[FuncId] [int] NOT NULL,
	[MailTo] [nvarchar](250) NOT NULL,
	[Title] [nvarchar](250) NOT NULL,
	[Subject] [nvarchar](250) NOT NULL,
	[Body] [ntext] NOT NULL,
	[MailCc] [nvarchar](500) NULL,
	[MailBcc] [nvarchar](250) NULL,
	[MailDate] [datetime] NULL,
	[Attachments] [nvarchar](250) NULL,
	[CountSend] [int] NULL,
	[SentSuccess] [int] NULL,
	[sentFail] [int] NULL,
	[MailUpdatedDate] [datetime] NULL,
	[IsEncrypt] [bit] NULL,
 CONSTRAINT [PK_MailRecord] PRIMARY KEY CLUSTERED 
(
	[MailId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[Mail_Record] ADD  CONSTRAINT [DF_MailRecord_FuncId]  DEFAULT ((0)) FOR [FuncId]
GO

ALTER TABLE [dbo].[Mail_Record] ADD  CONSTRAINT [DF_MailRecord_CountSend]  DEFAULT ((0)) FOR [CountSend]
GO