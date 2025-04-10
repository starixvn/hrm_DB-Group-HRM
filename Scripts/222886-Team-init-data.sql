USE [bodb_HRM]

--ALTER TABLE [Group]
--ADD DepartmentId INT NULL,
--GroupTeamId INT NULL,
--AccountableArea NVARCHAR(100) NULL,
--PICEmpId INT NULL

--ALTER TABLE [Group]
--DROP COLUMN SectionId, OldGroupId

DECLARE @Now DATETIME = GETDATE();

CREATE TABLE #tmpTeam (
    TeamID BIGINT,
    DeptCode NVARCHAR(50),
    TeamName NVARCHAR(100),
    TeamCode NVARCHAR(50),
    AccountableArea NVARCHAR(100),
    TeamPICCtrID INT,
    OldTeamCode NVARCHAR(100),
	Company NVARCHAR(100)
);
INSERT INTO #tmpTeam (TeamID, DeptCode, TeamName, TeamCode, AccountableArea, TeamPICCtrID, OldTeamCode)
VALUES 
(300000001,'AU06','AU Core Team','CT1','Core Team PU06',74,'AU Core Team'),
(300000002,'AU11','Automation','AT1','Automation - VN PU06',168,'Automation'),
(300000003,'AU22','DSA','AT2','Automation - PH PU06',819,'DSA'),
(300000004,'OS22','Shift A','PM7','OS PM Team Kaivin',543,'Shift A'),
(300000005,'OS22','Shift C','PM8','OS PM Team Murray',386,'Shift C'),
(300000006,'OS22','Shift B','PM6','OS PM Team Elton',925,'Shift B'),
(300000007,'BK22','European','LT3','BK LT Team Adam',1011,'European'),
(300000008,'BK22','Asian','LT5','BK LT Team Logan',2078,'Asian'),
(300000009,'CD22','CCS','CS3','CSD BU03',904,'CCS'),
(300000010,'CT88','CPO','CT1','Core Team - SRM',1256,'CPO'),
(300000011,'ES22','ES - Live Trading','ES3','PU03 Live Trading',307,'ES - Live Trading'),
(300000012,'FI01','FNA','FI1','Finance SU01',353,'FNA'),
(300000013,'FI01','Group Finance','NULL','Finance SU01',1729,'Group Finance'),
(300000014,'HM01','HR IMCT','HI4','HR IMCT SU04',283,'HR IMCT'),
(300000015,'HM03','Admin (Office)','AD4','ADM SU04',100,'AD4'),
(300000016,'HM03','Housing','AH4','ADM Housing SU04',100,'Housing'),
(300000017,'HM03','Logistics','AL4','ADM Logistics SU04',100,'Logistics'),
(300000018,'HM03','Security','AS4','ADM Security SU04',100,'Security'),
(300000019,'HM03','Kitchen','AK4','ADM Kitchen SU04',441,'Kitchen'),
(300000020,'HM05','HR','HR4','HR SU04',441,'HR'),
(300000021,'IH22','ITNS - Core Team','CT1','Core Team SU03',283,'ITNS - Core Team'),
(300000022,'IH22','IT-Admin','NULL','IT-Admin SU03',82,'IT-Admin'),
(300000023,'IH22','Support Team A','NULL','Technical Support SU03',66,'IT-Support Team A'),
(300000024,'IH22','Support Team B','NULL','Technical Support SU03',66,'IT-Support Team B'),
(300000025,'IH22','Support Team C','NULL','Technical Support SU03',66,'IT-Support Team C'),
(300000026,'IH33','IT-Network','SE3','SU03 System Engineer VN',66,'IT-Network'),
(300000027,'OS11','BC','LT6','OS LT Team Rayson',277,'BC'),
(300000028,'OS11','Major Sports','LT7','OS LT Team Tim',731,'Major Sports'),
(300000029,'OS33','Reporting & Live Support','OS5','Supportive PU05',157,'Supportive'),
(300000030,'PH22','PH-VN Site','V10','Pool House PU10',71,'PH-VN Site'),
(300000031,'PH22','PH-VN Site (Britney)','NULL','Pool House PU10',278,'PH-VN Site_Britney'),
(300000032,'PH22','PH-VN Site (Dallas)','NULL','Pool House PU10',489,'PH-VN Site_Dallas'),
(300000033,'PH22','PH-VN Site (Dante)','NULL','Pool House PU10',675,'PH-VN Site_Dante'),
(300000034,'PH22','PH-VN Site (Lucas)','NULL','Pool House PU10',1476,'PH-VN Site_Lucas'),
(300000035,'PH22','PH-VN Site (Tevez)','NULL','Pool House PU10',254,'PH-VN Site_Tevez'),
(300000036,'RD09','RD - Core Team','CT1','Core Team PU09',191,'RD - Core Team'),
(300000037,'RD11','EST','ES9','Event Support PU09',182,'EST'),
(300000038,'RD22','KST','KS9','Fraud & Keyscore PU09',1022,'KST'),
(300000039,'RD22','KST (Iris)','NULL','Fraud & Keyscore PU09',471,'KST_Iris'),
(300000040,'RD22','KST (Kathy)','NULL','Fraud & Keyscore PU09',615,'KST_Kathy'),
(300000041,'RD22','KST (Mickie)','NULL','Fraud & Keyscore PU09',271,'KST_Mickie'),
(300000042,'RD22','KST (Venny)','NULL','Fraud & Keyscore PU09',924,'KST_Venny'),
(300000043,'RD22','KST (Yoki)','NULL','Fraud & Keyscore PU09',526,'KST_Yoki'),
(300000044,'RD33','Supportive PRT','NULL','Supportive PU09',472,'Supportive PRT'),
(300000045,'SO01','SO - Core Team','CT1','PU01 Core Team',190,'SO - Core Team'),
(300000047,'SO02','SO - Core Team 2','CT2','PU01 Core Team 2',190,'SO - Core Team 2'),
(300000048,'SO18','Pre Match','PM1','Pre Match PU01',41,'Pre Match'),
(300000049,'SO18','Pre Match_Bolly','NULL','Pre Match PU01',626,'Pre Match_Bolly'),
(300000050,'SO18','Pre Match_Carson','NULL','Pre Match PU01',370,'Pre Match_Carson'),
(300000051,'SO18','Pre Match_Messi','NULL','Pre Match PU01',243,'Pre Match_Messi'),
(300000052,'SO18','Pre Match_Nelson','NULL','Pre Match PU01',362,'Pre Match_Nelson'),
(300000053,'SO18','Pre Match_Zon','NULL','Pre Match PU01',368,'Pre Match_Zon'),
(300000054,'SO28','Live Assistant-VN','LA1','Live Assistant-VN PU01',215,'LA-VN'),
(300000055,'SO28','Live Assistant-VN (Billy)','NULL','Live Assistant-VN PU01',769,'LA-VN_Billy'),
(300000056,'SO28','Live Assistant-VN (Bosco)','NULL','Live Assistant-VN PU01',401,'LA-VN_Bosco'),
(300000057,'SO28','Live Assistant-VN (Keity)','NULL','Live Assistant-VN PU01',359,'LA-VN_Keity'),
(300000058,'SO28','Live Assistant-VN (Rain)','NULL','Live Assistant-VN PU01',176,'LA-VN_Rain'),
(300000059,'SO28','Live Assistant-VN (Sammy)','NULL','Live Assistant-VN PU01',177,'LA-VN_Sammy'),
(300000060,'SO28','Live Assistant-VN (Sunny)','NULL','Live Assistant-VN PU01',659,'LA-VN_Sunny'),
(300000061,'SO88','Live Trading-VN','LT1','Live Trading - VN PU01',39,'Live Trading-VN'),
(300000062,'SO88','Live Trading-VN_Albert','NULL','Live Trading - VN PU01',978,'LG-VN_Albert'),
(300000063,'SO88','Live Trading-VN_Luke','NULL','Live Trading - VN PU01',285,'LG-VN_Luke'),
(300000064,'SO88','Live Trading-VN_Ping','NULL','Live Trading - VN PU01',238,'LG-VN_Ping'),
(300000065,'SO88','Live Trading-VN_Yen','NULL','Live Trading - VN PU01',49,'LG-VN_Yen'),
(300000066,'SO99','LST','LS1','Live Support PU01',95,'LST'),
(300000067,'SV11','Risk','RS1','PU08 Risk',181,'Risk'),
(300000068,'SV33','VT','VT8','PU08 Variance Team',391,'VT'),
(300000069,'BK22','Asian (WGI)','','',NULL,'Asian (WGI)'),
(300000070,'CD22','B2C - CSD (CTS)','','',NULL,'B2C - CSD (CTS)'),
(300000071,'OS11','BC (WGI)','','',NULL,'BC (WGI)'),
(300000072,'BK11','BK PM Team Elton','','',NULL,'BK PM Team Elton'),
(300000073,'CD22','CCS (WGI)','','',NULL,'CCS (WGI)'),
(300000074,'CD03','CSD (CTI)','','',NULL,'CSD (CTI)'),
(300000075,'ES22','ES - Live Trading (WGI)','','',NULL,'ES -LiveTrading(WGI)'),
(300000076,'RD11','EST (WGI)','','',NULL,'EST (WGI)'),
(300000077,'RD11','Event Support Team (CTI)','','',NULL,'EST (CTI)'),
(300000078,'OTHER','Guest','','',NULL,'Guest'),
(300000079,'HM03','Housing (RH)','','',NULL,'Housing (RH)'),
(300000080,'HM05','HRA - Core Team','','',NULL,'HRA - Core Team'),
(300000081,'HM01','HRC','','',NULL,'HRC'),
(300000082,'RD22','KST (WGI)','','',NULL,'KST (WGI)'),
(300000083,'SO88','Live Trading-PH (CTI)','','',NULL,'Live Trading-PH(CTI)'),
(300000084,'SO78','Live Trading-PH (WGI)','','',NULL,'LG-PH (WGI)'),
(300000085,'HM03','Logitem (Outsource)','','',NULL,'Logitem'),
(300000086,'SO99','LST (WGI)','','',NULL,'LST (WGI)'),
(300000087,'OS11','Major Sports (WGI)','','',NULL,'Major Sports (WGI)'),
(300000088,'HM01','Others','','',NULL,'Others'),
(300000089,'OS22','Pre Match CT (WGI)','','',NULL,'Pre Match CT (WGI)'),
(300000090,'HM01','Project S','','',NULL,'Project S'),
(300000091,'OS33','Reporting & Live Support (WGI)','','',NULL,'Supportive (WGI)'),
(300000092,'SV11','Risk (WGI)','','',NULL,'Risk (WGI)'),
(300000093,'OS22','Shift A (WGI)','','',NULL,'Shift A (WGI)'),
(300000094,'OS22','Shift B (WGI)','','',NULL,'Shift B (WGI)'),
(300000095,'OS22','Shift C (WGI)','','',NULL,'Shift C (WGI)'),
(300000096,'OTHER','Special User','','',NULL,'Special User'),
(300000097,'RD33','Supportive SPR - SPS - OSPR','','',NULL,'SPR - SPS - OSPR'),
(300000098,'SO18','Trading (Henry)','','',NULL,'Trading_Henry'),
(300000099,'BK22','USA (WGI)','','',NULL,'USA (WGI)');

UPDATE g
SET g.Code = CASE WHEN t.TeamCode = 'NULL' or t.TeamCode = '' or t.TeamCode is NULL
		THEN g.Code
		ELSE t.TeamCode 
	END,
	g.Name = t.TeamName,
	g.GroupTeamId = t.TeamID,
	g.AccountableArea = t.AccountableArea,
	g.ModifiedDate = @Now,
	g.ModifiedBy = NULL,
	g.CompanyId = 3,
	g.PICEmpId = e.EmpId,
	g.DepartmentId = d.DepartmentId
FROM dbo.[Group] g
INNER JOIN #tmpTeam t ON REPLACE(TRIM(g.Code), CHAR(160), '') = t.OldTeamCode
INNER JOIN dbo.Department d WITH(NOLOCK) ON d.Code = t.DeptCode
LEFT JOIN dbo.Employee e WITH(NOLOCK) ON e.CtrId = t.TeamPICCtrID

--SELECT g.GroupId,
--	CASE WHEN t.TeamCode = 'NULL' or t.TeamCode = '' or t.TeamCode is NULL
--			THEN g.Code
--			ELSE t.TeamCode 
--		END 'TeamCode',
--		t.TeamName,
--		t.TeamID,
--		t.AccountableArea,
--		@Now,
--		3 'CompanyId',
--		e.EmpId,
--		d.DepartmentId,		
--		t.DeptCode,
--		g.*
--FROM #tmpTeam t 
--INNER JOIN dbo.[Group] g WITH(NOLOCK) ON REPLACE(TRIM(g.Code), CHAR(160), '') = t.OldTeamCode
--INNER JOIN dbo.Department d WITH(NOLOCK) ON d.Code = t.DeptCode
--LEFT JOIN dbo.Employee e WITH(NOLOCK) ON e.CtrId = t.TeamPICCtrID
--ORDER BY t.TeamID

--DELETE FROM dbo.[Group]
--WHERE GroupTeamId IS NULL;

--select* from [Group]
--WHERE GroupTeamId NOT IN (SELECT TeamID FROM #tmpTeam)  OR GroupTeamId IS NULL;


DROP TABLE #tmpTeam