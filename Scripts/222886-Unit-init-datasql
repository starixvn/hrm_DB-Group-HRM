

ALTER TABLE dbo.Department 
ADD GroupDeptId INT NULL,
AccountableArea NVARCHAR(100) NULL, PICEmpId INT NULL

ALTER TABLE dbo.Department  
ALTER COLUMN OldDepartmentId INT NULL;

ALTER TABLE dbo.Department  
ALTER COLUMN CompanyId INT NULL;

--ALTER TABLE dbo.Department 
--DROP COLUMN CompanyId, OldDepartmentId

-- insert data into department
DECLARE @Now DATETIME = GETDATE();
CREATE TABLE #tmpDepartment (
    DeptID INT,
    DeptCode NVARCHAR(50),
    DeptName NVARCHAR(255),
    AccountableArea NVARCHAR(255),
    DeptPICCtrId INT,
    BUCode NVARCHAR(50)
);
INSERT INTO #tmpDepartment (DeptID, DeptCode, DeptName, AccountableArea, DeptPICCtrId, BUCode)
VALUES
(600001,'AT66','ASPlus','AC ASPLUS','538','AT'),
(600002,'AT16','Azeroth','AC AZEROTH','888','AT'),
(600003,'AT88','GM Office','AC GM OFFICE','766','AT'),
(600004,'AT18','Product','AC PRODUCT','766','AT'),
(600005,'AT19','Supporting','AC SUPPORT','252','AT'),
(600146,'AT99','AC CORE TEAM','AC CORE TEAM','766','AT'),
(600006,'AU06','Automation','Automation','74','AU'),
(600100,'AU11','Automation VN','PU06 VN','168','AU'),
(600101,'AU22','Automation PH','PU06 PH','819','AU'),
(600007,'BK02','Basketball','Basketball Core Team','60','BK'),
(600102,'BK11','Pre Match','PU02 Pre Match','390','BK'),
(600103,'BK22','Live Trading','PU02 Live Trading ','333','BK'),
(600104,'BK33','Supportive','PU02 Supportive','157','BK'),
(600008,'C188','Consultant 1','Consultant 1','1','C1'),
(600009,'C288','Consultant 2','Consultant 2','1','C2'),
(600010,'C388','Consultant 3','Consultant 3','1256','C3'),
(600011,'C588','Consultant 5','Consultant 5','25','C5'),
(600012,'C599','Consultant 5 - Fixed Term','Consultant 5 - Fixed Term','25','C5'),
(600013,'CC04','Cricket','Cricket Core Team','60','CC'),
(600106,'CC22','Live Trading','PU04 Live Trading ','750','CC'),
(600014,'CD03','Credit','BU03 Credit CT','37','CD'),
(600108,'CD11','Marketing','BU03 Marketing','37','CD'),
(600109,'CD22','CSD','BU03 CSD','137','CD'),
(600016,'CI66','CTO Office','Technology Excellence','611','CI'),
(600017,'CL01','Licensee','CSD Licensee','715','CL'),
(600077,'OL88','Licensee Management','Licensee Management','233','CL'),
(600143,'CL99','Licensee Core Team','Licensee Core Team','233','CL'),
(600018,'CT99','CEO Office','CEO Office','1256','CT'),
(600019,'CT88','Core Team','Core Team','1256','CT'),
(600021,'ES03','E-Sports','E-Sports','780','ES'),
(600110,'ES11','Pre Match','PU03 Pre Match','953','ES'),
(600111,'ES22','Live Trading','PU03 Live Trading','307','ES'),
(600150,'EV77','EVO.IO','','34','EV'),
(600022,'FI01','Finance','Finance','492','FI'),
(600027,'HM05','HR HCM','SU04 HR HCM','441','HH'),
(600112,'HM03','ADM HCM','SU04 ADM HCM','100','HH'),
(600114,'HM01','IMCT','IMCT','51','HH'),
(600144,'HM06','HRA HMA','SU04 HRA HMA','44','HH'),
(600145,'HM07','HR NEX','SU04 HR NEX','452','HH'),
(600151,'HM09','ADM NEX','SU04 ADM NEX','901','HH'),
(600152,'HM66','HRA CBT','SU04 HRA CABINTECH','51','HH'),
(600156,'HM22','HR Acora','HR Acora','51','HH'),
(600023,'HJ99','Back Office','HJ BACK OFFICE','918','HJ'),
(600024,'HJ01','Executive Office','HJ EO','918','HJ'),
(600025,'HJ66','IT','HJ IT INFRA','599','HJ'),
(600028,'HM04','HR MNL','SU04 HR MNL','1009','HM'),
(600113,'HM02','ADM MNL','SU04 ADM MNL','306','HM'),
(600147,'HM08','HR LEX','SU04 HR LEX','1487','HM'),
(600153,'HM12','HR PSP','HR PSP','51','HM'),
(600029,'IH03','ITNS','ITNS','66','IH'),
(600115,'IH11','ITNS CBT','ITNS CBT','51','IH'),
(600116,'IH22','ITNS','SU03 ITNS VN','66','IH'),
(600117,'IH33','System Engineer','SU03 System Engineer VN','66','IH'),
(600030,'IM03','ITNS','ITNS','86','IM'),
(600118,'IM11','IT Admin','SU03 IT Admin PH','245','IM'),
(600119,'IM22','ITNS','SU03 ITNS PH','860','IM'),
(600120,'IM33','System Engineer','SU03 System Engineer PH','140','IM'),
(600121,'IM55','Software Dev','SU03 Software Dev','68','IM'),
(600031,'LG02','LEGAL','LEGAL','208','LG'),
(600141,'LG03','LEGAL ADMIN','LEGAL ADMIN','208','LG'),
(600032,'LT88','Finance','LT FIN','957','LT'),
(600033,'LT01','GM Office','LT GM OFFICE','957','LT'),
(600034,'LT66','HRA','LT HRA','957','LT'),
(600035,'LT16','ITSD','LT ITSD','957','LT'),
(600036,'LT11','Marketing','LT MKTG','957','LT'),
(600148,'MW11','Marketing ','','1256','MW'),
(600037,'NF18','Aspire','NF ASPIRE','261','NF'),
(600038,'NF99','Bifrost','NF BIFROST','1224','NF'),
(600039,'NF33','Discover','NF DISCOVER','887','NF'),
(600041,'NF78','Genome','NF GENOME','1190','NF'),
(600042,'NF01','GM Office','NF GM OFFICE','1190','NF'),
(600044,'NF26','Muses','NF MUSES','890','NF'),
(600045,'NF16','Nueron','NF NUERON','1328','NF'),
(600048,'NF68','W Space','NF W SPACE','1267','NF'),
(600049,'NF66','Yorozuya','NF YOROZUYA','721','NF'),
(600050,'NV99','Business Development','Business Development','527','NV'),
(600051,'NV66','CSD','CSD','941','NV'),
(600052,'NV28','Core Team','Core Team','56','NV'),
(600053,'NV69','Marketing','Marketing','56','NV'),
(600055,'NV06','Product Risk','Product Risk','198','NV'),
(600057,'NV36','CRM','CRM','392','NV'),
(600154,'NV38','PMO','PMO','392','NV'),
(600058,'NX01','CORE TEAM','NX CORE TEAM','117','NX'),
(600059,'NX66','GM office','NX GM Office','117','NX'),
(600060,'NX03','Omni Flow','NX Omni Flow','152','NX'),
(600061,'NX69','Pentagon','NX Pentagon','388','NX'),
(600065,'NX99','Synergy','NX Synergy','595','NX'),
(600066,'NX18','Pioneers','NX Pioneers','125','NX'),
(600067,'NX06','Subarashi','NX Subarashi','705','NX'),
(600068,'NX45','Wabi Sabi','NX WABI SABI','560','NX'),
(600069,'NX27','Atomix','NX Atomix','388','NX'),
(600071,'OL99','Forerunner','Forerunner','660','OL'),
(600072,'OL01','GM Office','GM Office','204','OL'),
(600073,'OL38','Guide','Guide','204','OL'),
(600075,'OL27','Infinity','Infinity','322','OL'),
(600076,'OL68','Less Is More','Less Is More','859','OL'),
(600078,'OL06','O4 ONE','O4 ONE','652','OL'),
(600079,'OL09','One Back','One Back','742','OL'),
(600085,'OS05','OS Core Team','OS Core Team PU05','60','OS'),
(600122,'OS11','Live Trading','PU05 Live Trading','435','OS'),
(600123,'OS22','Pre Match','PU05 Pre Match','390','OS'),
(600124,'OS33','Supportive','PU05 Supportive','157','OS'),
(600086,'OT01','Core Team','Core Team','1256','OT'),
(600087,'OT66','CSD','CSD','941','OT'),
(600092,'OT69','PMO','PMO','816','OT'),
(600093,'OT39','Risk Management','Risk Management','374','OT'),
(600094,'OT22','Settlement','Settlement','373','OT'),
(600095,'PH10','Pool House CT','Pool House CT PU10','327','PH'),
(600125,'PH11','Pool House PH','PU10 PH','470','PH'),
(600126,'PH22','Pool House VN','PU10 VN','71','PH'),
(600096,'RD09','RND','RND','191','RD'),
(600127,'RD11','Event Support','PU09 Event Support ','182','RD'),
(600128,'RD22','Fraud & KeyScore','PU09 Fraud & Keyscore','528','RD'),
(600129,'RD33','Supportive','PU09 Supportive','472','RD'),
(600160,'SI55','SSI SOFTWARE DEV','SSI SOFTWARE DEV','2254','SI'),
(600097,'SO01','Soccer CT','Soccer CT','190','SO'),
(600130,'SO18','Pre Match','PU01 Pre Match','41','SO'),
(600131,'SO28','Live Assistant VN','PU01 Live Asssitant VN','215','SO'),
(600132,'SO38','Live Assistant PH','PU01 Live Asssitant PH','302','SO'),
(600133,'SO99','Live Support','PU01Live Support','95','SO'),
(600134,'SO88','Live Trading VN','PU01 Live Trading VN','39','SO'),
(600135,'SO78','Live Trading PH','PU01 Live Trading PH','303','SO'),
(600142,'SO02','Soccer CT2','Soccer CT2','190','SO'),
(600081,'SP39','Oneseal','Oneseal','1389','SP'),
(600084,'OL11','SWAT','SWAT','749','SP'),
(600098,'SP07','Casino & External','Casino & External','197','SP'),
(600136,'SP11','Product Management','PU07 PM','1109','SP'),
(600137,'SP22','Product Operations','PU07 PO','815','SP'),
(600159,'SP33','Less Is More','Less Is More','','SP'),
(600149,'SR36','HRSSC','','204','SR'),
(600054,'SS88','Payment CT','Payment Core Team','746','SS'),
(600157,'SS98','Operation','Payment Operations','1134','SS'),
(600158,'SS38','Resource Provider','Payment Resource Provider ','354','SS'),
(600099,'SV08','SVR Core Team','PU08 SVR Core Team','391','SV'),
(600138,'SV11','Risk','PU08 Risk','181','SV'),
(600139,'SV22','Risk & Support','PU08 Risk & Support','155','SV'),
(600140,'SV33','VT','PU08 Variance','391','SV');


INSERT INTO [dbo].[Department]
           ([Code]
           ,[Name]
           ,[UnitId]
           ,[IsActive]
           ,[ModifiedBy]
           ,[ModifiedDate]
           ,[IsDeleted]
		   ,[GroupDeptId]
           ,[AccountableArea]
           ,[PICEmpId])
SELECT 
		t.DeptCode,
		t.DeptName,
		u.UnitId,
		1, 
		NULL,
		@Now,
		0,
		t.DeptID,
		t.AccountableArea,
		e.EmpId
FROM #tmpDepartment t
LEFT JOIN dbo.Unit u WITH(NOLOCK) ON u.Code = t.BUCode
LEFT JOIN dbo.Employee e WITH(NOLOCK) ON e.CtrId = t.DeptPICCtrId

DROP TABLE #tmpDepartment;

