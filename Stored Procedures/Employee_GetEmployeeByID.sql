/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetEmployeeByID]
(
    @EmpId INT,
    @CompanyId SMALLINT = NULL
)
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get employee by id
    DB: bodb_HRM

    Revisions:
        - 03062023@Otis: get field ResignedReason
        - 20250707@Tim: add salary structure [Redmine: #230542]
        - 20250722@Tim: add auto approve request [Remine: #233324]
        - 20250806@Tim: get CtrId [Redmine: #235227]
        - 20250813@Jay: change db structure [Redmine: #235678]
		- 20250903@Jay: update role [Redmine: #237201]
		- 20251017@Henry: add payroll settings field [Redmine: #241812]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @KIVLeaveBalance NUMERIC(18, 2)
		,@AnnualLeaveBalance NUMERIC(18, 2)
		,@Today DATE = GETDATE()

	SELECT @KIVLeaveBalance = dbo.fnc_GetKIVByDayBalance(@EmpId, @Today, NULL)
		,@AnnualLeaveBalance = dbo.fnc_GetAnnualLeaveBalance(@EmpId, @Today, NULL)
		
	SELECT e.CtrId
        ,ce.EmpId
		,e.UserId
		,ce.Code
		,ce.DomainUsername
		,e.FullName
		,ce.NickName
		,ce.EmployeeCard
		,e.DOB AS DateOfBirth
		,ce.Email
		,ce.[Enabled]
		,e.Phone
		,e.Gender
		,ce.TeamDate
		,ce.PromotionDate
		,e.JoinedDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.ResignedReason
		,ce.CompanyDate
		,empsum.WorkingDays
		,empsum.WorkingHours
		,e.MilitaryFromDate
		,e.MilitaryToDate
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
		,ce.CreatedDate
		,ce.CreatedBy
		,ce.ModifiedDate
		,ce.ModifiedBy
		,ce.isDeleted
		,e.PermanentAddress AS [Address]
		,e.CurrentAddress
		,e.IdCardNumber AS CardNo
		,e.PassportNo
		,e.PassportExp
		,e.[Password]
		,e.ChineseName
		,empsum.IsDefaultSchedule
		,ce.IsSpecialUser AS IsTopManager
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
		,ce.PickupRemark
		,ce.JobTitleId
		,ce.ExpertGradeId
		,ce.JobLevelId
		,jl.[Name] AS JobLevel
		,lk.[Name] AS JobTitle
		,ce.SubCompanyId
		,c.[Name] AS CompanyName
		,ce.ManagementLevelId
		,ml.[Name] AS ManagementLevel
        ,ep.SalaryStructureId
		,ep.SpecialSubsidy
		,ep.NoOfDependent
        ,ss.Name AS SalaryStructure
		,ssd.BasicSalary
		,ssd.JobLevelAddOn
        ,ce.AutoApproveRequest
		,STUFF((
			SELECT ',' + CAST(epa.AllowanceItemSettingId AS VARCHAR(10))
			FROM dbo.EmployeePayrollAllowance epa WITH (NOLOCK)
			WHERE epa.EmpId = ce.EmpId
			FOR XML PATH('')
		), 1, 1, '') AS AllowanceItemSettingIds
		,ISNULL(ce.GroupId, - 1) AS [TeamId]
		,g.Code
		,g.[Name]
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
		LEFT JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = ce.EmpId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
        INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId 
		LEFT JOIN dbo.EmployeeContract AS e_cs WITH (NOLOCK) ON e_cs.EmpId = ce.EmpId
		LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON empsum.CountryCode = ct.CountryCode
		LEFT JOIN dbo.LookupData AS lk WITH (NOLOCK) ON ce.JobTitleId = lk.Id
			AND lk.LookupId = 1
		LEFT JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON jl.JobLevelId = ce.JobLevelId
		LEFT JOIN dbo.ManagementLevel AS ml WITH (NOLOCK) ON ml.ManagementLevelId = ce.ManagementLevelId
		LEFT JOIN dbo.EmployeePayroll AS ep WITH (NOLOCK) ON ep.EmpId = ce.EmpId
		LEFT JOIN dbo.SalaryStructure AS ss WITH (NOLOCK) ON ss.SalaryStructureId = ep.SalaryStructureId
		LEFT JOIN dbo.SalaryStructureDetail AS ssd WITH (NOLOCK) ON ssd.SalaryStructureId = ss.SalaryStructureId AND ssd.JobLevelId = ce.JobLevelId
	WHERE ce.EmpId = @EmpId
		AND (@CompanyId IS NULL OR ce.CompanyId = @CompanyId)
END