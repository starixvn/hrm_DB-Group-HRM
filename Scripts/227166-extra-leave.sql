ALTER TABLE dbo.[Group] 
ADD LocalYearsOfServiceForExtraLeave INT,
	ExpatYearsOfServiceForExtraLeave INT;

DECLARE @AscentisId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'Ascentis')
DECLARE @HyjayId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'Hyjay')
DECLARE @LetstalkId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'Letstalk')
DECLARE @NextFortuneId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'Next Fortune')
DECLARE @OneLabId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'One Lab')
DECLARE @SSIId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'SSI')
DECLARE @EMCId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'EMC')
INSERT INTO SystemConfigs([Key], [Value], CompanyId)
VALUES('AnualLeaveResetTimeLine', 'Yearly', @AscentisId),
('AnualLeaveResetTimeLine', 'Yearly', @HyjayId),
('AnualLeaveResetTimeLine', 'Yearly', @LetstalkId),
('AnualLeaveResetTimeLine', 'Yearly', @NextFortuneId),
('AnualLeaveResetTimeLine', 'Yearly', @OneLabId),
('AnualLeaveResetTimeLine', 'Yearly', @SSIId),
('AnualLeaveResetTimeLine', 'Yearly', @EMCId)