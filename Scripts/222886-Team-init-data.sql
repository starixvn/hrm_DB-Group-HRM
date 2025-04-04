
ALTER TABLE [Group]
ADD DepartmentId INT NULL,
GroupTeamId INT NULL,
AccountableArea NVARCHAR(100) NULL,
PICEmpId INT NULL

--ALTER TABLE [Group]
--DROP COLUMN SectionId, OldGroupId

DECLARE @Now DATETIME = GETDATE();
CREATE TABLE #tmpTeam (
    TeamID BIGINT,
    DeptCode NVARCHAR(50),
    TeamName NVARCHAR(255),
    TeamCode NVARCHAR(50),
    AccountableArea NVARCHAR(255),
    TeamPICCtrID INT,
    Company NVARCHAR(100)
);
INSERT INTO #tmpTeam (TeamID, DeptCode, TeamName, TeamCode, AccountableArea, TeamPICCtrID, Company)
VALUES 
(300000011,'AU11','Automation','AT1','Automation - VN PU06',168,'SMS'),
(300000064,'HM05','ADM Kitchen','AK4','ADM Kitchen SU04',441,'SMS'),
(300000069,'HM03','ADM Security','AS4','ADM Security SU04',100,'SMS'),
(300000275,'IH33','System Engineer','SE3','SU03 System Engineer VN',66,'SMS'),
(300000239,'OS33','Supportive','OS5','Supportive PU05',337,'SMS'),
(300000306,'OS11','Live Trading','LT6','OS LT Team Rayson',277,'SMS'),
(300000307,'OS11','Live Trading','LT7','OS LT Team Tim',154,'SMS'),
(300000308,'OS22','Pre Match','PM6','OS PM Team Elton',113,'SMS'),
(300000309,'OS22','Pre Match','PM7','OS PM Team Kaivin',543,'SMS'),
(300000310,'OS22','Pre Match','PM8','OS PM Team Murray',386,'SMS'),
(300000251,'PH22','VN Site','V10','Pool House PU10',71,'SMS'),
(300000253,'RD11','Event Support','ES9','Eveent Support PU09',182,'SMS'),
(300000254,'RD22','KST','KS9','Fraud & Keyscore PU09',528,'SMS'),
(300000255,'RD33','Supportive','SP9','Supportive PU09',472,'SMS'),
(300000257,'SO28','Live Assistant','LA1','Live Assistant-VN PU01',215,'SMS'),
(300000258,'SO38','Live Assistant','LA2','Live Assistant - PH PU01',302,'SMS'),
(300000259,'SO99','Live Support ','LS1','Live Support PU01',95,'SMS'),
(300000260,'SO88','Live Trading','LT1','Live Trading - VN PU01',39,'SMS'),
(300000261,'SO78','Live Trading','LT2','Live Trading - PH PU01',303,'SMS'),
(300000262,'SO18','Pre Match','PM1','Pre Match PU01',41,'SMS'),
(300000267,'SV11','Risk','RS1','PU08 Risk',181,'SMS');

--INSERT INTO [dbo].[Group]
--           ([Code]
--           ,[Name]
--           ,[Rank]
--           ,[CreatedDate]
--           ,[CreatedBy]
--           ,[ModifiedDate]
--           ,[ModifiedBy]
--           ,[IsDeleted]
--           ,[MailGroup]
--           --,[LocalBasicAnnualLeaveBalance]
--           --,[LocalWorkingDays]
--           --,[LocalWorkingHours]
--           --,[LocalOffDaysbyWeek]
--           --,[ExpatBasicAnnualLeaveBalance]
--           --,[ExpatWorkingDays]
--           --,[ExpatWorkingHours]
--           --,[ExpatOffDaysbyWeek]
--           --,[LocalWorkingHoursbyWeek]
--           --,[ExpatWorkingHoursbyWeek]
--           ,[CompanyId]
--           --,[OldGroupId]
--           ,[DepartmentId]
--           ,[GroupTeamId]
--           ,[AccountableArea]
--           ,[PICEmpId])
SELECT t.TeamCode,
		t.TeamName,
		NULL,
		@Now,
		NULL,
		NULL,
		NULL,
		0,
		NULL,
		3,
		d.DepartmentId,
		t.TeamID,
		t.AccountableArea,
		e.EmpId
FROM #tmpTeam t 
LEFT JOIN dbo.Department d WITH(NOLOCK) ON d.Code = t.DeptCode
LEFT JOIN dbo.Employee e WITH(NOLOCK) ON e.CtrId = t.TeamPICCtrID

DROP TABLE #tmpTeam