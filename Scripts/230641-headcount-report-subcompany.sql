CREATE TABLE SubCompany (
    SubCompanyId INT PRIMARY KEY IDENTITY(1,1),
    CompanyId INT NOT NULL,
    [Name] NVARCHAR(100),
    CountryCode NVARCHAR(10),
	IsActivated BIT NOT NULL DEFAULT 1,
	ModifiedBy INT,
	ModifiedDate DATETIME
);

ALTER TABLE CompanyEmployee 
ADD SubCompanyId INT

ALTER TABLE [Group] 
ADD IsOutsource BIT NOT NULL DEFAULT 0

DECLARE @SMSCompanyId INT = 3;
DECLARE @CabintechCompanyId INT = 9;
DECLARE @OneLabCompanyId INT = 22;
DECLARE @OseasCompanyId INT = 23;

SET IDENTITY_INSERT SubCompany ON;
INSERT INTO SubCompany (SubCompanyId, CompanyId, [Name], CountryCode)
VALUES
	(1, @CabintechCompanyId, 'PSP', 'KH'),
	(2, @CabintechCompanyId, 'PSB', 'KH'),
	(3, @CabintechCompanyId, 'WGI', 'KH'),
	(4, @SMSCompanyId, 'DAR', 'VN'),
	(5, @OseasCompanyId, 'SRM', 'MY'),
	(6, @OseasCompanyId, 'EXT', 'MY'),
	(7, @OneLabCompanyId, 'OW', 'TW')
SET IDENTITY_INSERT SubCompany OFF;

INSERT INTO SystemConfigs
VALUES('IsShowSubCompany', 'true', @CabintechCompanyId),
('IsShowSubCompany', 'true', @SMSCompanyId),
('IsShowSubCompany', 'true', @OseasCompanyId),
('IsShowSubCompany', 'true', @OneLabCompanyId)
GO

-------- SubCompany --------
-- Cabintech PSP --
DECLARE @PSPSubId INT = 1
DECLARE @CabintechCompanyId INT = 9

UPDATE ce 
SET SubCompanyId = @PSPSubId
FROM CompanyEmployee ce
INNER JOIN Employee e ON ce.EmpId = e.EmpId
WHERE Code IN
('LM0111', 'LM0123', 'LM0076', 'LM0126', 'LM0119', 'LM0124', 'LM0122', 'LM0077', 
'LM0125', 'LM0118', 'LM0117', 'LM0131', 'LM0132', 'LM0034', 'LM0116', 'LM0084', 
'LM0113', 'LM0083', 'LM0068', 'LM0074', 'LM0112', 'LM0030', 'LM0134', 'LM0135', 
'LM0025', 'LM0054', 'LM0044', 'LM0040', 'LM0079', 'LM0045', 'LM0032', 'LM0053', 
'LM0136', 'LM0129', 'LM0139', 'LM0038', 'LM0037', 'LM0026', 'LM0021')
AND CompanyId = @CabintechCompanyId
GO

-- Cabintech PSB --
DECLARE @PSBSubId INT = 2
DECLARE @CabintechCompanyId INT = 9

UPDATE ce 
SET SubCompanyId = @PSBSubId
FROM CompanyEmployee ce
INNER JOIN Employee e ON ce.EmpId = e.EmpId
WHERE Code IN
('EM0570', 'E16-828', 'E21-054', 'E12-293', 'EM0571', 'E22-162', 'E22-085', 'E22-094', 'E22-105', 
'E16-805', 'EM0569', 'E24-009', 'E19-060', 'E13-395', 'E18-003', 'E22-125', 'E21-093', 'E23-003', 
'E22-135', 'E23-095', 'E17-055', 'E20-056', 'E18-002', 'E22-020', 'E10-044', 'E23-119', 'E18-031', 
'E23-065', 'E17-919', 'E13-334', 'E23-063', 'E22-160', 'E10-043', 'E22-043', 'E19-139', 'E10-002', 
'E17-085', 'E22-161', 'E22-021', 'E21-055', 'E17-922', 'EM0565', 'E22-082', 'E21-035', 'E11-180', 
'E19-083', 'E22-126', 'E16-887', 'E23-004', 'E22-019', 'E18-069', 'EM0564', 'E18-116', 'E22-180', 
'E13-458', 'E23-118', 'E21-090', 'E23-169', 'E14-526', 'E23-059', 'E14-504', 'E19-046', 'E19-030', 
'E23-061', 'E22-034', 'E14-539', 'E18-112', 'E22-007', 'E14-592', 'E22-117', 'EM0563', 'E22-031', 
'E12-239', 'E22-057', 'E16-804', 'E18-095', 'E23-099', 'E17-945', 'E20-006', 'E15-686', 'EM0587', 
'EM0589', 'EM0590', 'EM0558', 'EM0560', 'EM0577', 'EM0559', 'EM0578', 'EM0579', 'EM0580', 'EM0581', 
'E16-846', 'E23-145', 'E22-030', 'E10-021', 'E22-029', 'E23-196', 'E18-131', 'E23-176', 'E22-118', 
'E24-029', 'E18-133', 'E22-084', 'E16-803', 'E23-021', 'E23-177', 'E23-074', 'E16-904', 'E24-039', 
'E16-802', 'E22-136', 'E10-012', 'E16-888', 'E17-090', 'E10-019', 'E10-017', 'EM0574', 'EM0572', 
'EM0568', 'EM0575', 'E10-045', 'EM0573')
AND CompanyId = @CabintechCompanyId
GO

-- Cabintech WGI --
DECLARE @WGISubId INT = 3
DECLARE @CabintechCompanyId INT = 9

UPDATE ce 
SET SubCompanyId = @WGISubId
FROM CompanyEmployee ce
INNER JOIN Employee e ON ce.EmpId = e.EmpId
WHERE Code IN
('EM0340', 'EM0333', 'EM0339', 'EM0429', 'EM0512', 'EM0425', 'EM0414', 'EM0438', 'EM0426', 
'EM0474', 'EM0303', 'EM0486', 'EM0511', 'EM0394', 'EM0335', 'EM0403', 'EM0437', 'EM0439', 
'EM0471', 'EM0517', 'EM0518', 'EM0404', 'EM0382', 'EM0374', 'EM0424', 'EM0391', 'EM0272', 
'EM0252', 'EM0476', 'EM0383', 'EM0323', 'EM0525', 'EM0015', 'EM0485', 'EM0591', 'EM0522', 
'EM0509', 'EM0557', 'EM0592', 'EM0585', 'EM0514', 'EM0401', 'EM0576', 'EM0367', 'EM0431', 
'EM0099', 'EM0050', 'EM0315', 'EM0062', 'EM0361', 'EM0409', 'EM0204', 'EM0472', 'EM0500', 
'EM0481', 'EM0451', 'EM0408', 'EM0343', 'EM0346', 'EM0455', 'EM0325', 'EM0508', 'EM0452', 
'EM0491', 'EM0413', 'EM0393', 'EM0445', 'EM0064')
AND CompanyId = @CabintechCompanyId
GO

-- SMS DAR --
DECLARE @DarSubId INT = 4
DECLARE @SMSCompanyId INT = 3
UPDATE ce 
SET SubCompanyId = @DarSubId
FROM CompanyEmployee ce
INNER JOIN Employee e ON ce.EmpId = e.EmpId
WHERE Code IN
('00031', '03282', '00054', '00049', '00145', '00036', '00067', '90003', '00121', '90031', '00044', 
'00032', '00132', '00093', '00112', '90014', '90019', '00045', '00115', '00062', '00064', '00023', 
'90008', '00103', '02196', '00111', '00090', '00058', '00080', '00085', '00081', '00088', '00091', 
'00099', '00100', '00082', '00053', '90018', '00025', '00027', '00139')
AND CompanyId = @SMSCompanyId
GO

-------- WFH --------
-- Cabintech --
INSERT INTO dbo.EmployeeWorkFromHome (
    EmpId,
    FromDate,
    ToDate,
    Remark,
    ModifiedDate
)
SELECT 
    e.EmpId,
    '2025-01-01',
    '2025-12-31',
    CASE 
        WHEN e.Code = 'E15-686' THEN 'WFH - China'
        WHEN e.Code IN ('E16-803', 'E16-802') THEN 'WFH - India' 
        WHEN e.Code = 'E10-017' THEN 'WFH - Malaysia'       
		WHEN e.Code IN ('E24-009', 'E24-029', 'E18-133', 'E23-177', 'E22-136') THEN 'WFH - Philippines'
        WHEN e.Code IN ('E23-176', 'E22-084', 'E23-074') THEN 'WFH - Vietnam'
    END,
    '2025-06-19'
FROM dbo.Employee e
WHERE e.Code IN ('E24-009', 'E15-686', 'E23-176', 'E24-029', 'E18-133', 'E22-084', 'E16-803', 'E23-177', 'E23-074', 'E16-802', 'E22-136', 'E10-017');

-- WGI --
DECLARE @WGICompanyId INT = 8
INSERT INTO dbo.EmployeeWorkFromHome (
    EmpId,
    FromDate,
    ToDate,
	Remark,
	ModifiedDate
)
SELECT 
    e.EmpId,
    '2025-01-01',         
    '2025-12-31',
	'WFH',
	'2025-06-19'
FROM dbo.Employee e
INNER JOIN CompanyEmployee ce ON ce.EmpId = e.EmpId
WHERE e.Code IN 
('WGI0519', 'WGI0513', 'WGI0505', 'WGI0498', 'WGI0497', 'WGI0489', 'WGI0479', 'WGI0462', 'WGI0461', 'WGI0444', 
'WGI0440', 'WGI0435', 'WGI0484', 'WGI0432', 'WGI0423', 'WGI0407', 'WGI0390', 'WGI0372', 'WGI0342', 'WGI0338', 
'WGI0331', 'WGI0326', 'WGI0324', 'WGI0319', 'WGI0318', 'WGI0314', 'WGI0499', 'WGI0286', 'WGI0283', 'WGI0284', 
'WGI0278', 'WGI0267', 'WGI0085', 'WGI0007', 'WGI0035', 'WGI0026', 'WGI0159', 'WGI0045', 'WGI0009', 'WGI0135', 
'WGI0165', 'WGI0105', 'WGI0054', 'WGI0022', 'WGI0120', 'WGI0078', 'WGI0082', 'WGI0024', 'WGI0093', 'WGI0502', 
'WGI0264', 'WGI0263', 'WGI0217', 'WGI0202', 'WGI0166', 'WGI0164', 'WGI0161', 'WGI0158', 'WGI0067', 'WGI0046', 
'WGI0042', 'WGI0037', 'WGI0034', 'WGI0209', 'WGI0203', 'WGI0084', 'WGI0069', 'WGI0091', 'WGI0478', 'WGI0031', 
'WGI0070', 'WGI0089', 'WGI0043', 'WGI0250', 'WGI0163', 'WGI0106', 'WGI0218', 'WGI0143', 'WGI0185', 'WGI0477', 
'WGI0259', 'WGI0213', 'WGI0193', 'WGI0160', 'WGI0071', 'WGI0238', 'WGI0256', 'WGI0151', 'WGI0182', 'WGI0111', 
'WGI0010', 'WGI0011', 'WGI0231', 'WGI0189', 'WGI0260', 'WGI0233', 'WGI0229', 'WGI0225', 'WGI0188', 'WGI0186', 
'WGI0126', 'WGI0244', 'WGI0207', 'WGI0170', 'WGI0155', 'WGI0153', 'WGI0027', 'WGI0115', 'WGI0094', 'WGI0469', 
'WGI0178', 'WGI0222', 'WGI0208', 'WGI0196', 'WGI0194', 'WGI0191', 'WGI0237', 'WGI0219', 'WGI0103', 'WGI0240', 
'WGI0199', 'WGI0156', 'WGI0220', 'WGI0344', 'WGI0261', 'WGI0192', 'WGI0100', 'WGI0246', 'WGI0210', 'WGI0190', 
'WGI0187', 'WGI0125', 'WGI0104', 'WGI0107', 'WGI0073', 'WGI0171', 'WGI0076', 'WGI0044', 'WGI0006', 'WGI0005', 
'WGI0109', 'WGI0047', 'WGI0317', 'WGI0075', 'WGI0195', 'WGI0018', 'WGI0003', 'WGI0262', 'WGI0101', 'WGI0255', 
'WGI0002', 'WGI0001', 'WGI0028', 'WGI0181', 'WGI0180')
AND CompanyId = @WGICompanyId
GO

-- Digibyte --
DECLARE @DigibyteCompanyId INT = 15
INSERT INTO dbo.EmployeeWorkFromHome (
    EmpId,
    FromDate,
    ToDate,
	Remark,
	ModifiedDate
)
SELECT 
    e.EmpId,
    '2025-01-01',         
    '2025-12-31',
	'WFH',
	'2025-06-19'
FROM dbo.Employee e
INNER JOIN CompanyEmployee ce ON ce.EmpId = e.EmpId
WHERE Code IN 
('WFH_LM001', 'WFH_LM002', 'WFH_LM003', 'WFH_LM004', 'WFH_LM005', 'WFH_LM006', 'WFH_LM007', 'WFH_LM008', 
'WFH_LM009', 'WFH_LM010', 'WFH_LM011', 'WFH_LM012', 'WFH_LM013', 'WFH_LM014', 'WFH_LM015', 'WFH_LM016', 
'WFH_LM017', 'WFH_LM018', 'WFH_LM019', 'WFH_LM020', 'WFH_LM021', 'WFH_LM022', 'WFH_LM023', 'WFH_LM024', 
'WFH_LM025', 'WFH_LM026', 'WFH_LM027', 'WFH_LM029', 'WFH_LM030', 'WFH_LM031', 'WFH_LM032', 'WFH_LM033', 
'WFH_LM034', 'WFH_LM037', 'WFH_LM038', 'WFH_LM039', 'WFH_LM040', 'WFH_LM041', 'WFH_LM042', 'WFH_LM066', 
'WFH_LM043', 'WFH_LM044', 'WFH_LM045', 'WFH_LM046', 'WFH_LM047', 'WFH_LM048', 'WFH_LM067', 'WFH_LM068', 
'WFH_LM052', 'WFH_LM054', 'WFH_LM053', 'WFH_LM050', 'WFH_LM049', 'WFH_LM051', 'WFH_LM055', 'WFH_LM056', 
'WFH_LM057', 'WFH_LM058', 'WFH_LM059', 'WFH_LM060', 'WFH_LM061', 'WFH_LM062', 'WFH_LM063', 'WFH_LM064', 
'WFH_LM065', 'WFH_LM069')
AND CompanyId = @DigibyteCompanyId
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetEmployeeByID] @EmpId INT
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get employee by id
    DB: bodb_HRM

    Revisions:
        03062023@Otis: get field ResignedReason
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @KIVLeaveBalance NUMERIC(18, 2)
		,@AnnualLeaveBalance NUMERIC(18, 2)
		,@Today DATE = GETDATE()

	SELECT @KIVLeaveBalance = dbo.fnc_GetKIVByDayBalance(@EmpID, @Today, NULL)
		,@AnnualLeaveBalance = dbo.fnc_GetAnnualLeaveBalance(@EmpId, @Today, NULL)

	SELECT e.EmpId
		,e.UserId
		,e.Code
		,e.DomainUsername
		,e.FullName
		,e.NickName
		,e.EmployeeCard
		,e.DOB AS DateOfBirth
		,e.Email
		,e.[Enabled]
		,e.Phone
		,e.Gender
		,e.TeamDate
		,e.PromotionDate
		,e.JoinedDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.ResignedReason
		,empsum.CompanyDate
		,empsum.WorkingDays
		,empsum.WorkingHours
		,empsum.MilitaryFromDate
		,empsum.MilitaryToDate
		,empsum.WorkingHoursByWeek
		,e.Skype
		,e.LetsTalk
		,e.Marriage
		,e.LastLogin
		,@AnnualLeaveBalance AS AnnualLeaveBalance
		,@KIVLeaveBalance AS KeepInViewBalance
		,empsum.CountryCode
		,ct.CountryName
		,empsum.CanOT
		,empsum.SpecialOT
		,empsum.IsLocal
		,empsum.IsExpatUseHoliday
		,e.CreatedDate
		,e.CreatedBy
		,e.ModifiedDate
		,e.ModifiedBy
		,e.isDeleted
		,e.PermanentAddress AS [Address]
		,e.CurrentAddress
		,e.IdCardNumber AS CardNo
		,e.PassportNo
		,e.PassportExp
		,e.[Password]
		,e.ChineseName
		,empsum.IsDefaultSchedule
		,empsum.IsTopManager
		,empsum.OffDaysbyWeek
		,empsum.Unit
		,e.PlaceOfbirth
		,e.Ethnic
		,e.[Native]
		,e.Religion
		,e.DateOfIDCard
		,e.PlaceOfIDCard
		,e.HomePhone
		,e.Qualification
		,e.Major
		,e_cs.[BankAccount]
		,e_cs.[TaxCode]
		,e_cs.[SocialInsuranceNo]
		,e_cs.[RegisteredHospital]
		,e_cs.[Contract1]
		,e_cs.[FromDate1]
		,e_cs.[ToDate1]
		,e_cs.[Contract2]
		,e_cs.[FromDate2]
		,e_cs.[ToDate2]
		,e_cs.[Contract3]
		,e_cs.[FromDate3]
		,e_cs.[ToDate3]
		,e_cs.[Contract4]
		,e_cs.[FromDate4]
		,e_cs.[ToDate4]
		,e_cs.[Contract5]
		,e_cs.[FromDate5]
		,e_cs.[ToDate5]
		,e_cs.History
		,e.PasswordReset
		,e.PickupRemark
		,e.JobTitleId
		,e.ExpertGradeId
		,e.JobLevelId
		,lk.[Name] AS JobTitle
		,ce.SubCompanyId
		,e.ManagementLevelId
		,ISNULL(e.GroupId, - 1) AS [TeamId]
		,g.Code
		,g.[Name]
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.EmployeeContract AS e_cs WITH (NOLOCK) ON e_cs.EmpId = e.EmpId
		LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON empsum.CountryCode = ct.CountryCode
		LEFT JOIN dbo.LookupData AS lk WITH (NOLOCK) ON e.JobTitleId = lk.Id
		AND lk.LookupId = 1
	WHERE e.EmpId = @EmpId
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetEmployees] 
(	
	@query NVARCHAR(256) = NULL
	,@teamIds NVARCHAR(MAX) = ''
	,@enable BIT = NULL
	,@isDelete BIT = NULL
	,@isLocal BIT = NULL
	,@pageNumber INT = 1
	,@pageSize INT = 2000
	,@totalRow INT = NULL OUTPUT
	,@titleId INT = NULL
	,@companyId INT
)
AS
/*
	Created: Tom.Vo@2013-10-23
	Task: Insert default working calendar for employee
	DB: HRM_SMS
	Original:

	Revisions:
	Param's Explanation:
		-Otis - 03062023: get field ResignedReason
		-Jay  - 04042025: remove Section
		-Henry- 10042025: map Company
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #GroupsList (GroupId INT)

	INSERT INTO #GroupsList (GroupId)
	SELECT value
	FROM STRING_SPLIT(@teamIds, ',')

	IF LEN(@query) = 0
		OR @query LIKE '% or %'
		OR @query LIKE '%--%'
	BEGIN
		SET @query = NULL
	END

	SET @query = REPLACE(@query, '''', '''''')

	DECLARE @q NVARCHAR(256) = @query + '%'''

	SELECT @pageNumber = ISNULL(@pageNumber, 1)
		,@pageSize = ISNULL(@pageSize, 2000)

	DECLARE @SQL NVARCHAR(4000)
		,@sWhere NVARCHAR(4000)
		,@bWhere BIT

	SELECT @SQL = 'SELECT @totalRow = count(1) FROM  dbo.Employee AS e WITH (NOLOCK)
				INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = ' + CAST(@companyId AS VARCHAR(10))  + CHAR(13)
				+ 'INNER JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = e.EmpId ' + CHAR(13)

	SELECT @sWhere = ''
		,@bWhere = 0

	IF @enable IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + 'WHERE ISNULL(e.isDeleted, 0) = 0 and e.Enabled = ' + CONVERT(NVARCHAR(10), @enable) + CHAR(13)
			,@bWhere = 1
	END
	ELSE IF @isDelete IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + ' e.isDeleted = ' + CONVERT(NVARCHAR(10), @isDelete) + CHAR(13)
			,@bWhere = 1
	END

	IF @q IS NOT NULL
		AND @query IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + ' (e.NickName LIKE ''' + @q + ' OR e.FullName LIKE N''%' + @q + ' OR e.Code LIKE ''%' + @q + ')' + CHAR(13)
			,@bWhere = 1
	END

	IF ISNULL( @teamIds, '') <> ''
	BEGIN
	SELECT @sWhere = @sWhere + CASE 
			WHEN @bWhere = 1 THEN ' AND '
			ELSE ' WHERE '
			END + ' ( e.GroupId IN (SELECT GroupId FROM #GroupsList) )' + CHAR(13)
		,@bWhere = 1
	END

	IF @titleId IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + ' JobTitleId = ' + CONVERT(NVARCHAR(10), @titleId) + CHAR(13)
			,@bWhere = 1
	END

	IF @isLocal IS NOT NULL
	BEGIN
		SELECT @sWhere = @sWhere + CASE 
				WHEN @bWhere = 1 THEN ' AND '
				ELSE ' WHERE '
				END + ' s.IsLocal = ' + CONVERT(NVARCHAR(10), @isLocal) + CHAR(13)
			,@bWhere = 1
	END

	SELECT @SQL = @SQL + @sWhere

	PRINT @SQL

	EXEC sp_executesql @SQL
		,N'@totalRow INT OUTPUT'
		,@totalRow = @totalRow OUTPUT

	SELECT @SQL = 'SELECT e.[EmpId]
      ,e.[Code]
      ,[DomainUsername]
      ,[FullName]
      ,[NickName]
      ,[DOB]
      ,[Email]
      ,[JobTitleId]
      ,[Enabled]
      ,[Phone]
      ,[Gender]
      ,[JoinedDate]
      ,[ConfirmedDate]
      ,[ResignedDate]
	  ,[ResignedReason]
      ,[Skype]
      ,[LetsTalk]
      ,[Marriage]
      ,[LastLogin]
      ,e.[CreatedDate]
      ,e.[CreatedBy]
      ,e.[ModifiedDate]
      ,e.[ModifiedBy]
      ,e.[isDeleted]
      ,[PermanentAddress]
      ,[CurrentAddress]
      ,[IdCardNumber]
      ,[PassportNo]
      ,[PassportExp]
      ,[Password]
      ,[ChineseName]
      ,[PlaceOfbirth]
      ,[Ethnic]
      ,[Native]
      ,[Religion]
      ,[DateOfIDCard]
      ,[PlaceOfIDCard]
      ,[HomePhone]
      ,[Qualification]
      ,[Major]
      ,[PasswordReset]
      ,[EmployeeCard]
	  ,sc.[Name] AS SubCompanyName' + CHAR(13)
	  + ',s.[AnnualLeaveBalance]' + CHAR(13)
	  + ',dbo.fnc_GetKIVBalance(e.EmpId,null) AS KeepInViewBalance' + CHAR(13)
	  + ',s.[CanOT]' + CHAR(13)
	  + ',s.[IsLocal]' + CHAR(13)
	  + ',s.[WorkingDays]' + CHAR(13)
	  + ',s.[WorkingHours]' + CHAR(13)
	  + ',s.[IsDefaultSchedule]' + CHAR(13)
	  + ',s.[CompanyDate]' + CHAR(13)
	  + ',s.[IsTopManager]' + CHAR(13)
	  + ',s.[OffDaysbyWeek]' + CHAR(13)
	  + ',s.CountryCode' + CHAR(13)
	  + ',s.IsExpatUseHoliday' + CHAR(13)
	  + ',ISNULL(ctry.Nationality, ctry.CountryName) CountryName' + CHAR(13)
	  + ',s.MilitaryFromDate' + CHAR(13)
	  + ',s.MilitaryToDate' + CHAR(13)
	  + ',jt.Name AS [JobTitle]' + CHAR(13)
	  + ',c.CompanyId' + CHAR(13)
	  + ',c.[Name] AS CompanyName' + CHAR(13)
	  + ',unit.[Name] AS UnitName' + CHAR(13)
	  + ',unit.[Code] AS UnitCode' + CHAR(13)
	  + ',g.GroupId AS [TeamId]' + CHAR(13)
	  + ',g.Code AS [TeamCode]' + CHAR(13)
	  + ',g.Name AS [TeamName]' + CHAR(13)
	  + ',g.Rank' + CHAR(13)
	  + ',dep.DepartmentId' + CHAR(13)
	  + ',dep.Code AS DepartmentCode' + CHAR(13)
	  + ',dep.[Name] AS DepartmentName' + CHAR(13)
	  + 'FROM dbo.Employee AS e WITH (NOLOCK)' + CHAR(13)
	  + 'INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = ' + CAST(@companyId AS VARCHAR(10))  + CHAR(13)
	  + 'LEFT JOIN dbo.SubCompany sc WITH (NOLOCK) ON ce.SubCompanyId = sc.SubCompanyId' + CHAR(13)
	  + 'INNER JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = e.EmpId' + CHAR(13)
	  + 'LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupID = g.GroupID' + CHAR(13)
	  + 'INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON dep.DepartmentId = g.DepartmentId' + CHAR(13)
	  + 'INNER JOIN dbo.[Unit] AS unit WITH (NOLOCK) ON dep.UnitId = unit.UnitId' + CHAR(13)
	  + 'LEFT JOIN [dbo].[Country] AS ctry WITH(NOLOCK) ON ctry.CountryCode = s.CountryCode' + CHAR(13)
	  + 'LEFT JOIN [dbo].[Lookup] AS l WITH(NOLOCK) ON l.Code = ''JT''' + CHAR(13)
	  + 'LEFT JOIN [dbo].[LookupData] AS jt WITH(NOLOCK) ON l.Id = jt.LookupId AND e.JobTitleId = jt.Id' + CHAR(13)
	  + 'LEFT JOIN [dbo].Company c WITH (NOLOCK) ON c.CompanyId =' + CAST(@companyId AS VARCHAR(10))  + CHAR(13)
	  + @sWhere + 'ORDER BY ' + CHAR(13)

	IF (@enable = 0)
	BEGIN
		SELECT @SQL = @SQL + ' e.ResignedDate DESC,'
	END

	SELECT @SQL = @SQL + 'JoinedDate DESC' + CHAR(13)
		+ ',[Code] DESC' + CHAR(13)
		+ ',[NickName]' + CHAR(13)
		+ 'OFFSET ' + CONVERT(NVARCHAR(10), (@pageNumber - 1) * @pageSize) + ' ROWS FETCH NEXT ' + CONVERT(NVARCHAR(10), @pageSize) + ' ROWS ONLY;'

	EXEC sp_executesql @SQL

	SELECT EmployeeId
		,RoleId
	FROM dbo.EmployeeRole AS emRo WITH (NOLOCK)

	PRINT @SQL

	DROP TABLE #GroupsList
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetFullProfileInformation] @query NVARCHAR(256) = NULL
	,@teamIds NVARCHAR(MAX) = ''
	,@enable BIT = NULL
	,@isDelete BIT = NULL
	,@isLocal BIT = NULL
	,@titleId INT = NULL
AS
/*
Created: 20190620@Oliver.Dang
Task: get employee full profile information
DB: HRM
Original:

Revisions:
	- 20200714@Merlin.Le: Get section and department code
	- 20230704@Otis.Vu: Get supervisor and roles info
	- 20250404@Jay.Do: Remove section
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (GroupId INT PRIMARY KEY)

	CREATE TABLE #tmpEmployee (EmpId INT PRIMARY KEY)

	CREATE TABLE #tmpSupervisor (
		EmpId INT
		,ActionType INT
		,OwnerId INT
		,Nickname NVARCHAR(20)
		)

	CREATE NONCLUSTERED INDEX IX_tmpSupervisor ON #tmpSupervisor (
		EmpId
		,ActionType
		,OwnerId
		)

	INSERT INTO #tmpGroup (GroupId)
	SELECT val
	FROM fnc_strSplit(@teamIds, ',')

	INSERT INTO #tmpEmployee (EmpId)
	SELECT e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE (
			@isDelete IS NULL
			OR e.isDeleted = @isDelete
			)
		AND (
			@enable IS NULL
			OR e.[Enabled] = @enable
			)
		AND (
			@titleId IS NULL
			OR e.JobTitleId = @titleId
			)
		AND (
			ISNULL(@teamIds, '') = ''
			OR EXISTS (
				SELECT 1
				FROM #tmpGroup AS tmpgr WITH (NOLOCK)
				WHERE e.GroupId = tmpgr.GroupId
				)
			)
		AND (
			@isLocal IS NULL
			OR es.IsLocal = @isLocal
			)
		AND (
			ISNULL(@query, '') = ''
			OR e.NickName LIKE '%' + @query + '%'
			OR e.FullName LIKE '%' + @query + '%'
			)

	SELECT DISTINCT e.EmpId
		,e.Code
		,e.FullName
		,e.NickName
		,e.ChineseName
		,e.DOB
		,e.Gender
		,e.Marriage
		,e.CurrentAddress
		,e.PermanentAddress
		,e.IdCardNumber
		,e.DateOfIDCard
		,e.PlaceOfIDCard
		,e.PlaceOfbirth
		,e.Phone
		,e.HomePhone
		,e.Email
		,e.Qualification
		,e.Major
		,g.[Name] AS TeamName
		,dep.[Name] AS DepartmentName
		,unit.[Name] AS UnitName
		,unit.[Code] AS UnitCode
		,e.EmployeeCard
		,c.[Name] AS CompanyName
		, sc.[Name] AS SubCompanyName
		,es.CompanyDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.ResignedReason
		,e.JoinedDate
		,es.MilitaryFromDate
		,es.MilitaryToDate
		,jt.[Name] AS JobTitle
		,jl.[Name] AS JobLevel
		,e.TeamDate
		,e.Ethnic
		,e.[Native]
		,e.Religion
		,ISNULL(ctry.Nationality, ctry.CountryName) AS Nationality
		,e.PassportNo
		,e.PassportExp
		,e.PickupRemark
		,e.Skype
		,e.LetsTalk
		,es.CanOT
		,es.SpecialOT
		,es.WorkingDays
		,es.WorkingHours
		,es.OffDaysbyWeek
		,es.AnnualLeaveBalance
		,es.KeepInViewBalance
		,es.IsTopManager
		,es.IsLocal
	FROM #tmpEmployee AS tpl WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON tpl.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		LEFT JOIN dbo.SubCompany AS sc WITH (NOLOCK) ON sc.SubCompanyId = ce.SubCompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.[Department] AS dep WITH (NOLOCK) ON g.DepartmentId = dep.DepartmentId
		INNER JOIN dbo.Unit AS unit WITH (NOLOCK) ON dep.UnitId = unit.UnitId
		LEFT JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON tpl.EmpId = es.EmpId
		LEFT JOIN dbo.[Lookup] AS l WITH (NOLOCK) ON l.Code = 'JT'
		LEFT JOIN dbo.[LookupData] AS jt WITH (NOLOCK) ON l.Id = jt.LookupId
		AND e.JobTitleId = jt.Id
		LEFT JOIN dbo.[Country] AS ctry WITH (NOLOCK) ON ctry.CountryCode = es.CountryCode
		LEFT JOIN dbo.[JobLevel] AS jl WITH (NOLOCK) ON jl.JobLevelId = e.JobLevelId
		AND jl.IsDeleted = 0
	ORDER BY e.EmpId

	INSERT INTO #tmpSupervisor(
		EmpId
		,ActionType
		,OwnerId
		,Nickname
		)
	SELECT DISTINCT su.EmpId
		,su.ActionType
		,su.OwnerId
		,empsu.Nickname
	FROM dbo.[EmployeeSupervisor] AS su WITH (NOLOCK)
		INNER JOIN #tmpEmployee AS emp WITH (NOLOCK) ON su.EmpId = emp.EmpId
		INNER JOIN dbo.Employee AS empsu WITH (NOLOCK) ON su.OwnerId = empsu.EmpId
	WHERE empsu.[Enabled] = 1
		AND empsu.isDeleted = 0
		AND su.ActionType IN (2, 3, 4, 5, 8)
		AND su.IsDeleted = 0
	ORDER BY su.EmpId

	SELECT tbl.EmpId
		,tbl.ActionType
		,tbl.OwnerId
		,tbl.Nickname
	FROM #tmpEmployee AS tpl WITH (NOLOCK)
		INNER JOIN #tmpSupervisor AS tbl WITH (NOLOCK) ON tpl.EmpId = tbl.EmpId

	SELECT emprole.EmployeeId
		,emprole.RoleId
	FROM #tmpEmployee AS tpl WITH (NOLOCK)
		INNER JOIN dbo.EmployeeRole AS emprole WITH (NOLOCK) ON emprole.EmployeeId = tpl.EmpId

	DROP TABLE #tmpGroup

	DROP TABLE #tmpEmployee

	DROP TABLE #tmpSupervisor
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Information_update] @EmpId INT
	,@Code VARCHAR(20)
	,@DomainUsername VARCHAR(50) = ''
	,@FullName NVARCHAR(50) = ''
	,@Nickname NVARCHAR(20) = ''
	,@DOB DATE = NULL
	,@Email VARCHAR(50) = NULL
	,@JobTitleId INT = NULL
	,@JobLevelId INT = NULL
    ,@ManagementLevelId SMALLINT = NULL
	,@Enabled BIT
	,@Phone VARCHAR(50) = NULL
	,@Gender TINYINT = NULL
	,@TeamId INT
	,@Roles VARCHAR(20)
	,@JoinedDate DATE = NULL
	,@ConfirmedDate DATE = NULL
	,@ResignedDate DATE = NULL
	,@ResignedReason NVARCHAR(200) = NULL
	,@Skype VARCHAR(100) = NULL
	,@LetsTalk VARCHAR(100) = NULL
	,@Marriage TINYINT = 1
	,@ModifiedBy INT
	,@PermanentAddress NVARCHAR(250) = ''
	,@CurrentAddress NVARCHAR(250) = ''
	,@IdCardNumber VARCHAR(20) = ''
	,@PassportNo VARCHAR(35) = ''
	,@PassportExp DATE = NULL
	,@ChineseName NVARCHAR(200) = NULL
	,@CanOT BIT
	,@SpecialOT DECIMAL(3, 1) = NULL
	,@IsLocal BIT
	,@WorkingDays INT
	,@WorkingHours INT
	,@WorkingHoursByWeek TINYINT = NULL
	,@CompanyDate DATE = NULL
	,@CountryCode VARCHAR(5) = NULL
	,@IsTopManager BIT = 0
	,@OffDaysbyWeek SMALLINT = 0
	,@IsExpatUseHoliday BIT = 0
	,@PlaceOfbirth NVARCHAR(250) = ''
	,@Ethnic NVARCHAR(250) = ''
	,@Native NVARCHAR(250) = ''
	,@Religion NVARCHAR(250) = ''
	,@DateOfIDCard DATE = NULL
	,@PlaceOfIDCard NVARCHAR(250) = ''
	,@HomePhone NVARCHAR(250) = ''
	,@Qualification NVARCHAR(300) = ''
	,@Major NVARCHAR(300) = ''
	,@EmployeeCard VARCHAR(10) = ''
	,@PickupRemark NVARCHAR(200) = NULL
	,@PromotionDate DATE = NULL
	,@TeamDate DATE = NULL
	,@MilitaryFromDate DATE = NULL
	,@MilitaryToDate DATE = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
	,@SubCompanyId INT = NULL
AS
/*
Created: TOM
Task: UPDATE an employee Information 
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @EmpId_exist INT
		,@Nickname_exist NVARCHAR(20)
		,@FullName_exist NVARCHAR(50)
		,@Code_exist NVARCHAR(50)
		,@Roles_old VARCHAR(100)
		,@Enabled_old BIT
		,@IsDeleted_old BIT
		,@IsDefaultSchedule_old BIT
		,@AnnualLeaveBalance_old NUMERIC(18, 1) = 0
		,@KeepInViewBalance_old NUMERIC(18, 1) = 0
		,@xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

	SELECT TOP 1 @EmpId_exist = e.EmpId
		,@FullName_exist = e.FullName
	FROM dbo.Employee e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee c WITH(NOLOCK) ON c.EmpId = e.EmpId
	WHERE e.EmpId <> @EmpId
		AND Code = @code
		AND c.CompanyId = @CompanyId


	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Code ' + @Code + ' has been assigned to ' + @FullName_exist

		RETURN
	END

	SELECT TOP 1 @EmpId_exist = e.EmpId
		,@Nickname_exist = Nickname
		,@FullName_exist = FullName
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee c WITH(NOLOCK) ON c.EmpId = e.EmpId
	WHERE e.EmpId <> @EmpId
		AND Nickname = @nickname
		AND c.CompanyId = @CompanyId
		AND (
			isDeleted = 0
			OR [Enabled] = 1
			)

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Nickname  ' + @Nickname_exist + '  has been assigned to ' + @FullName_exist

		RETURN
	END

	SELECT @Enabled_old = [Enabled]
		,@IsDeleted_old = isDeleted
	FROM dbo.Employee WITH (NOLOCK)
	WHERE EmpId = @EmpId
	
	SELECT @IsDefaultSchedule_old = IsDefaultSchedule
		,@AnnualLeaveBalance_old = AnnualLeaveBalance
		,@KeepInViewBalance_old = KeepInViewBalance
	FROM dbo.EmployeeSummary WITH (NOLOCK)
	WHERE EmpId = @EmpId

	SELECT @Roles_old = COALESCE(@Roles_old + ',', '') + CONVERT(NVARCHAR(2), RoleId)
	FROM dbo.EmployeeRole WITH (NOLOCK)
	WHERE EmployeeId = @EmpId
	Order by RoleID 

	SET @xml = (
			SELECT Code AS '@Code'
				,DomainUsername AS '@DomainUsername'
				,FullName AS '@FullName'
				,Nickname AS '@Nickname'
				,DOB AS '@DOB'
				,Email AS '@Email'
				,JobTitleId AS '@JobTitleId'
				,JobLevelId AS '@JobLevelId'
				,ManagementLevelId AS'@ManagementLevelId'
				,[Enabled] AS '@Enabled'
				,emp.isDeleted AS '@IsDeleted'
				,Phone AS '@Phone'
				,Gender AS '@Gender'
				,GroupId AS '@TeamId'
				,JoinedDate AS '@JoinedDate'
				,ConfirmedDate AS '@ConfirmedDate'
				,ResignedDate AS '@ResignedDate'
				,ResignedReason AS '@ResignedReason'
				,Skype AS '@Skype'
				,LetsTalk AS '@LetsTalk'
				,Marriage AS '@Marriage'
				,PermanentAddress AS '@PermanentAddress'
				,CurrentAddress AS '@CurrentAddress'
				,IdCardNumber AS '@IdCardNumber'
				,PassportNo AS '@PassportNo'
				,PassportExp AS '@PassportExp'
				,ChineseName AS '@ChineseName'
				,PlaceOfbirth AS '@PlaceOfbirth'
				,Ethnic AS '@Ethnic'
				,[Native] AS '@Native'
				,Religion AS '@Religion'
				,DateOfIDCard AS '@DateOfIDCard'
				,PlaceOfIDCard AS '@PlaceOfIDCard'
				,HomePhone AS '@HomePhone'
				,Qualification AS '@Qualification'
				,Major AS '@Major'
				,EmployeeCard AS '@EmployeeCard'
				,PickupRemark AS '@PickupRemark'
				,PromotionDate AS '@PromotionDate'
				,TeamDate AS '@TeamDate'
				,@Roles_old AS '@RoleIds'
				,CanOT AS '@CanOT'
				,SpecialOT AS '@SpecialOT'
				,IsLocal AS '@IsLocal'
				,WorkingDays AS '@WorkingDays'
				,WorkingHours AS '@WorkingHours'
				,WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,IsTopManager AS '@IsTopManager'
				,CompanyDate AS '@CompanyDate'
				,CountryCode AS '@CountryCode'
				,IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,OffDaysbyWeek AS '@OffDaysbyWeek'
				,MilitaryFromDate AS '@MilitaryFromDate'
				,MilitaryToDate AS '@MilitaryToDate'
				,SubCompanyId AS '@SubCompanyId'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
			WHERE emp.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	IF @Enabled_old = 0 AND @Enabled = 1 AND @IsDeleted_old = 1
	BEGIN
		UPDATE dbo.Employee WITH (ROWLOCK, UPDLOCK)
		SET isDeleted = 0
		WHERE EmpId = @EmpId
	END

	UPDATE dbo.Employee WITH (ROWLOCK, UPDLOCK)
	SET Code = @Code
		,DomainUsername = @DomainUsername
		,FullName = @FullName
		,Nickname = @Nickname
		,DOB = @DOB
		,Email = REPLACE(@Email, ' ', '')
		,JobTitleId = @JobTitleId
		,JobLevelId = @JobLevelId
		,ManagementLevelId = @ManagementLevelId
		,[Enabled] = @Enabled
		,Phone = @Phone
		,Gender = @Gender
		,GroupId = @TeamId
		,JoinedDate = @JoinedDate
		,ConfirmedDate = @ConfirmedDate
		,ResignedDate = @ResignedDate
		,ResignedReason = @ResignedReason
		,Skype = @Skype
		,LetsTalk = @LetsTalk
		,Marriage = @Marriage
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
		,PermanentAddress = @PermanentAddress
		,CurrentAddress = @CurrentAddress
		,IdCardNumber = @IdCardNumber
		,PassportNo = @PassportNo
		,PassportExp = @PassportExp
		,ChineseName = @ChineseName
		,PlaceOfbirth = @PlaceOfbirth
		,Ethnic = @Ethnic
		,[Native] = @Native
		,Religion = @Religion
		,DateOfIDCard = @DateOfIDCard
		,PlaceOfIDCard = @PlaceOfIDCard
		,HomePhone = @HomePhone
		,Qualification = @Qualification
		,Major = @Major
		,EmployeeCard = @EmployeeCard
		,PickupRemark = @PickupRemark
		,PromotionDate = @PromotionDate
		,TeamDate = @TeamDate
	WHERE EmpId = @EmpId

	UPDATE CompanyEmployee  WITH (ROWLOCK, UPDLOCK)
	SET SubCompanyId = @SubCompanyId
	WHERE EmpId = @EmpId

	EXEC dbo.EmployeeRole_Update @EmployeeId = @EmpId
		,@RoleIds = @Roles
		,@ModifiedBy = @ModifiedBy

	EXEC dbo.Employee_Summary_Update @EmpId = @EmpId
		,@AnnualLeaveBalance = @AnnualLeaveBalance_old
		,@KeepInViewBalance = @KeepInViewBalance_old
		,@CanOT = @CanOT
		,@SpecialOT = @SpecialOT
		,@IsLocal = @IsLocal
		,@WorkingDays = @WorkingDays
		,@WorkingHours = @WorkingHours
		,@WorkingHoursByWeek = @WorkingHoursByWeek
		,@CompanyDate = @CompanyDate
		,@CountryCode = @CountryCode
		,@IsDefaultSchedule = @IsDefaultSchedule_old
		,@IsTopManager = @IsTopManager
		,@OffDaysbyWeek = @OffDaysbyWeek
		,@IsExpatUseHoliday = @IsExpatUseHoliday
		,@MilitaryFromDate = @MilitaryFromDate
		,@MilitaryToDate = @MilitaryToDate
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	SET @xml = (
			SELECT Code AS '@Code'
				,DomainUsername AS '@DomainUsername'
				,FullName AS '@FullName'
				,Nickname AS '@Nickname'
				,DOB AS '@DOB'
				,Email AS '@Email'
				,JobTitleId AS '@JobTitleId'
				,JobLevelId AS '@JobLevelId'
				,ManagementLevelId AS '@ManagementLevelId'
				,[Enabled] AS '@Enabled'
				,emp.isDeleted AS '@IsDeleted'
				,Phone AS '@Phone'
				,Gender AS '@Gender'
				,GroupId AS '@TeamId'
				,JoinedDate AS '@JoinedDate'
				,ConfirmedDate AS '@ConfirmedDate'
				,ResignedDate AS '@ResignedDate'
				,ResignedReason AS '@ResignedReason'
				,Skype AS '@Skype'
				,LetsTalk AS '@LetsTalk'
				,Marriage AS '@Marriage'
				,PermanentAddress AS '@PermanentAddress'
				,CurrentAddress AS '@CurrentAddress'
				,IdCardNumber AS '@IdCardNumber'
				,PassportNo AS '@PassportNo'
				,PassportExp AS '@PassportExp'
				,ChineseName AS '@ChineseName'
				,PlaceOfbirth AS '@PlaceOfbirth'
				,Ethnic AS '@Ethnic'
				,[Native] AS '@Native'
				,Religion AS '@Religion'
				,DateOfIDCard AS '@DateOfIDCard'
				,PlaceOfIDCard AS '@PlaceOfIDCard'
				,HomePhone AS '@HomePhone'
				,Qualification AS '@Qualification'
				,Major AS '@Major'
				,EmployeeCard AS '@EmployeeCard'
				,PickupRemark AS '@PickupRemark'
				,PromotionDate AS '@PromotionDate'
				,TeamDate AS '@TeamDate'
				,@Roles AS '@RoleIds'
				,CanOT AS '@CanOT'
				,SpecialOT AS '@SpecialOT'
				,IsLocal AS '@IsLocal'
				,WorkingDays AS '@WorkingDays'
				,WorkingHours AS '@WorkingHours'
				,WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,IsTopManager AS '@IsTopManager'
				,CompanyDate AS '@CompanyDate'
				,CountryCode AS '@CountryCode'
				,IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,OffDaysbyWeek AS '@OffDaysbyWeek'
				,MilitaryFromDate AS '@MilitaryFromDate'
				,MilitaryToDate AS '@MilitaryToDate'
				,SubCompanyId AS '@SubCompanyId'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
			WHERE emp.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 1
		,@ObjectId = @EmpId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Get]
(
    @CompanyId INT
    ,@TeamId INT = NULL
	,@keyWord varchar(20) = null
	,@isDeleted BIT = NULL
)
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get group
    DB: bodb_HRM

    Revisions:
        20250310@Mira: filter by CompanyId [Redmine: #217976]
        20250403@Tim: remove section [Redmine: #222886]
        20250515@Jay: add years of service for extra leave [Redmine: #227166]
        20250530@Jay: show company name for employees from different company [Redmine: #225528]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (
		GroupId INT PRIMARY KEY
		,NoOfMembers INT
		,TotalLocal INT
		,TotalExpat INT
		)

	INSERT INTO #tmpGroup (
		GroupId
		,NoOfMembers
		,TotalLocal
		,TotalExpat
		)
	SELECT g.GroupId
		,SUM(CASE 
				WHEN esum.IsLocal IS NOT NULL THEN 1
				ELSE 0
				END) AS NoOfMembers
		,SUM(CASE 
				WHEN esum.IsLocal = 1 THEN 1
				ELSE 0
				END) TotalLocal
		,SUM(CASE 
				WHEN esum.IsLocal = 0 THEN 1
				ELSE 0
				END) TotalExpat
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.GroupId = g.GroupId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) on c.EmpId = emp.EmpId AND c.CompanyId = @CompanyId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		AND g.CompanyId = @CompanyId
	GROUP BY g.GroupId

	SELECT g.groupId AS TeamId
		,g.[Name]
		,g.Code
		,g.[Rank]
		,g.MailGroup
		,g.IsOutsource
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave
		,tbl.NoOfMembers
		,tbl.TotalLocal
		,tbl.TotalExpat
		,g.PICEmpId
		,cpic.[Name] AS PICCompanyName
		,cpic.[CompanyId] AS PICCompanyId
		,ld.NickName as PICNickName
		,dept.DepartmentId
        ,dept.Code
        ,dept.[Name]
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.Employee AS ld WITH (NOLOCK) ON ld.EmpId = g.PICEmpId
		LEFT JOIN dbo.CompanyEmployee cepic WITH (NOLOCK) ON cepic.EmpId = g.PICEmpId
		LEFT JOIN dbo.Company cpic WITH (NOLOCK) ON cpic.CompanyId = cepic.CompanyId
		LEFT JOIN #tmpGroup AS tbl ON g.GroupId = tbl.GroupId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		AND (
			 @keyWord IS NULL
			 OR LOWER(g.[Name]) like LOWER('%' + @keyWord + '%') 
			 OR LOWER(g.Code) like LOWER('%' + @keyWord + '%') 
			)
		AND g.CompanyId = @CompanyId
	ORDER BY g.[Code]

	SELECT mng.GroupId AS TeamId
		,mng.RoleId
		,emp.EmpId
		,emp.NickName
		,emp.FullName
	FROM dbo.GroupManager AS mng WITH (NOLOCK)
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON mng.GroupId = g.GroupId
		AND (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND (
			@isDeleted IS NULL
			OR g.isDeleted = @isDeleted
			)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON mng.EmpId = emp.EmpId
		INNER JOIN dbo.CompanyEmployee c WITH (NOLOCK) on c.EmpId = emp.EmpId
    WHERE g.CompanyId = @CompanyId
        AND c.CompanyId = @CompanyId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1

    DROP TABLE #tmpGroup
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Insert]
(
    @Code VARCHAR(20)
    ,@Name VARCHAR(150)
    ,@CreatedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg VARCHAR(200) = '' OUTPUT
    ,@CompanyId SMALLINT
    ,@GroupTeamId INT
    ,@PICEmpId INT = NULL
    ,@DepartmentId INT
    ,@AccountableArea VARCHAR(200) = NULL
	,@IsOutsource BIT = 0
)
AS
/*
    Created: 20190515@Oliver.Dang
    Task: insert group 
    DB: bodb_HRM

    Revisions:
        - 20250422@Jay: Apply create group team logic [Redmine: #221567]
        - 20250526@Jay: Allow having the same code [Redmine: #228323]
        - 20250530@Jay: allow PICEmpId be null [Redmine: #225528]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupTeamId = @GroupTeamId
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Team Id "' + CAST(@GroupTeamId AS NVARCHAR) + '" exists.'

		RETURN
	END

	INSERT INTO dbo.[Group] (
		Code
		,[Name]
		,CreatedDate
		,CreatedBy
		,CompanyId
		,GroupTeamId
		,PICEmpId
		,DepartmentId
		,AccountableArea
		,IsOutsource
		)
	VALUES (
		@Code
		,@Name
		,GETDATE()
		,@CreatedBy
		,@CompanyId
		,@GroupTeamId
		,@PICEmpId
		,@DepartmentId
		,@AccountableArea
		,@IsOutsource
		)

	DECLARE @id INT = cast(SCOPE_IDENTITY() AS INT)

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,CompanyId as '@CompanyId'
				,GroupTeamId as '@GroupTeamId'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
				,IsOutsource as '@IsOutsource'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @id
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 2
		,@ObjectId = @id
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[Group_UnitScope_Get]
	@keyWord varchar(20) = null,
	@TeamId INT = NULL
AS
/*
Created: Tom.Vo@2013-10-21
Task: get group
DB: HRM

Revisions:
	20250310@Mira: filter by CompanyId [Redmine: #217976]
    20250403@Tim: remove section [Redmine: #222886]
	20250515@Jay: add years of service for extra leave [Redmine: #227166]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpGroup (
		GroupId INT PRIMARY KEY
		,NoOfMembers INT
		)

	INSERT INTO #tmpGroup (
		GroupId
		,NoOfMembers
		)
	SELECT g.GroupId
		,SUM(CASE 
				WHEN esum.IsLocal IS NOT NULL THEN 1
				ELSE 0
				END) AS NoOfMembers
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.GroupId = g.GroupId
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		INNER JOIN dbo.EmployeeSummary AS esum WITH (NOLOCK) ON esum.EmpId = emp.EmpId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND g.isDeleted != 1
	GROUP BY g.GroupId

	SELECT g.GroupId AS Id
		,GroupTeamId AS GroupTeamId
		,g.[Name] AS TeamName
		,g.Code AS TeamCode
		,g.[Rank]
		,tbl.NoOfMembers
		,g.PICEmpId
		,e.NickName as TeamPIC
		,cpic.[CompanyId] AS TeamPICCompanyId
		,cpic.[Name] AS TeamPICCompany
		,d.DepartmentId
        ,d.Code AS DepartmentCode
        ,d.[Name] AS DepartmentName
		,d.PICEmpId AS DepartmentPICId
		,ed.NickName AS DepartmentPIC
		,u.Code AS UnitCode
		,g.AccountableArea
		,g.CompanyId
		,c.[Name] AS CompanyName
		,g.MailGroup
		,g.LocalBasicAnnualLeaveBalance
		,g.LocalWorkingDays
		,g.LocalWorkingHours
		,g.LocalOffDaysbyWeek
		,g.LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave
		,g.ExpatBasicAnnualLeaveBalance
		,g.ExpatWorkingDays
		,g.ExpatWorkingHours
		,g.ExpatOffDaysbyWeek
		,g.ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave
		,g.IsOutsource
	FROM dbo.[Group] AS g WITH (NOLOCK)
		INNER JOIN dbo.Department AS d WITH (NOLOCK) ON g.DepartmentId = d.DepartmentId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = g.PICEmpId
		INNER JOIN dbo.Unit AS u WITH (NOLOCK) ON u.UnitId = d.UnitId
		LEFT JOIN dbo.Employee AS ed WITH (NOLOCK) ON ed.EmpId = d.PICEmpId
		LEFT JOIN dbo.CompanyEmployee AS cepic WITH (NOLOCK) ON cepic.EmpId = g.PICEmpId
		LEFT JOIN dbo.Company AS cpic WITH (NOLOCK) ON cepic.CompanyId = cpic.CompanyId
		LEFT JOIN #tmpGroup AS tbl ON g.GroupId = tbl.GroupId
		LEFT JOIN dbo.Company AS c ON g.CompanyId = c.CompanyId
	WHERE (
			 @TeamId IS NULL
			OR g.GroupId =  @TeamId
			)
		AND g.isDeleted != 1
		AND (
			 @keyWord IS NULL
			 OR LOWER(g.[Name]) like LOWER('%' + @keyWord + '%') 
			 OR LOWER(g.Code) like LOWER('%' + @keyWord + '%') 
			)
	ORDER BY d.Code

    DROP TABLE #tmpGroup
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Update]
(
    @TeamId INT
    ,@Code VARCHAR(20)
    ,@Name NVARCHAR(150)
    ,@ModifiedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
    ,@PICEmpId INT = NULL
    ,@DepartmentId INT
    ,@AccountableArea VARCHAR(200) = NULL
    ,@GroupTeamId INT
    ,@MailGroup VARCHAR(50) = ''
    ,@LocalBasicAnnualLeaveBalance TINYINT = NULL
    ,@LocalWorkingDays TINYINT = NULL
    ,@LocalWorkingHours TINYINT = NULL
    ,@LocalOffDaysbyWeek TINYINT = NULL
    ,@LocalWorkingHoursByWeek TINYINT = NULL
    ,@LocalYearsOfServiceForExtraLeave INT = NULL
    ,@ExpatBasicAnnualLeaveBalance TINYINT = NULL
    ,@ExpatWorkingDays TINYINT = NULL
    ,@ExpatWorkingHours TINYINT = NULL
    ,@ExpatOffDaysbyWeek TINYINT = NULL
    ,@ExpatWorkingHoursByWeek TINYINT = NULL
    ,@ExpatYearsOfServiceForExtraLeave INT = NULL
	,@IsOutsource BIT = 0
)
AS
/*
    Created: Tom.Vo@2013-10-23
    Task: Update group 
    DB: bodb_HRM

    Revisions:
	    - 20250515@Jay: add years of service for extra leave [Redmine: #227166]
	    - 20250526@Jay: Allow having the same code [Redmine: #228323]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId <> @TeamId 
				AND GroupTeamId = @GroupTeamId
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Team Id "' + CAST(@GroupTeamId AS NVARCHAR) + '" have been used by other group.'

		RETURN
	END

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId AS '@PICEmpId'
				,DepartmentId AS '@DepartmentId'
				,AccountableArea AS '@AccountTableArea'
				,GroupTeamId AS '@GroupTeamId'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,LocalYearsOfServiceForExtraLeave AS '@LocalYearsOfServiceForExtraLeave'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,ExpatYearsOfServiceForExtraLeave AS '@ExpatYearsOfServiceForExtraLeave'
				,IsOutsource AS '@IsOutsource'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	UPDATE dbo.[Group] WITH (ROWLOCK, UPDLOCK)
	SET Code = @Code
		,[Name] = @Name
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
		,PICEmpId = @PICEmpId
		,DepartmentId = @DepartmentId
		,AccountableArea = @AccountableArea
		,GroupTeamId = @GroupTeamId
		,LocalBasicAnnualLeaveBalance = @LocalBasicAnnualLeaveBalance
		,LocalWorkingDays = @LocalWorkingDays
		,LocalWorkingHours = @LocalWorkingHours
		,LocalOffDaysbyWeek = @LocalOffDaysbyWeek
		,LocalWorkingHoursByWeek = @LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave = @LocalYearsOfServiceForExtraLeave
		,ExpatBasicAnnualLeaveBalance = @ExpatBasicAnnualLeaveBalance
		,ExpatWorkingDays = @ExpatWorkingDays
		,ExpatWorkingHours = @ExpatWorkingHours
		,ExpatOffDaysbyWeek = @ExpatOffDaysbyWeek
		,ExpatWorkingHoursByWeek = @ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave = @ExpatYearsOfServiceForExtraLeave
		,[MailGroup] = @MailGroup
		,IsOutsource = @IsOutsource
	WHERE GroupId = @TeamId

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
				,GroupTeamId as '@GroupTeamId'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,LocalYearsOfServiceForExtraLeave AS '@LocalYearsOfServiceForExtraLeave'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,ExpatYearsOfServiceForExtraLeave AS '@ExpatYearsOfServiceForExtraLeave'
				,IsOutsource AS '@IsOutsource'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 2
		,@ObjectId = @TeamId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE SubCompanies_ByCompanyId_Get
	@CompanyId INT
AS
/*
Created: 20250616@Jay
Task: Get all subcompanies by company id
DB: HRM
Original:

Revisions:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT SubCompanyId,
		CompanyId,
		[Name]
	FROM SubCompany
	WHERE CompanyId = @CompanyId
END
GO
