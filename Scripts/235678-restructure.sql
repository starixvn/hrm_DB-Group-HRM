USE [bodb_HRM]
GO

alter table dbo.Employee add MilitaryFromDate date, MilitaryToDate date, Username varchar(50)
go

alter table dbo.CompanyEmployee add UserId int, Code varchar(20), Nickname nvarchar(20), JobTitleId int, ManagerId int, EmployeeCard varchar(10)
    ,PickupRemark nvarchar(200), TeamDate date, PromotionDate date, JobLevelId int, ManagementLevelId int, ExpertGradeId int
    ,DistanceToCompany varchar(10), CreatedBy int, CreatedDate datetime, ModifiedBy int, ModifiedDate datetime, OldEmpId int
go

update dbo.Employee set UserId = EmpId

update ce
set ce.UserId = ce.EmpId
from dbo.CompanyEmployee as ce

update e
set e.Username = e.Code,
    e.MilitaryFromDate = es.MilitaryFromDate
    ,e.MilitaryToDate = es.MilitaryToDate
from dbo.Employee as e
    inner join dbo.EmployeeSummary as es on es.EmpId = e.EmpId

declare @nexcelId tinyint = 1, @lumiId tinyint = 2, @nexvisionId tinyint = 34

update ce
set ce.IsSpecialUser = es.IsTopManager,
    ce.CompanyDate = es.CompanyDate
from dbo.Employee as e
    inner join dbo.CompanyEmployee as ce on e.EmpId = ce.EmpId
    inner join dbo.EmployeeSummary as es on e.EmpId = es.EmpId
where ce.CompanyId not in (@nexcelId, @lumiId, @nexvisionId)

update ce
set ce.Code = e.Code,
    ce.DomainUsername = e.DomainUsername,
    ce.Nickname = e.Nickname,
    ce.JobTitleId = e.JobTitleId,
    ce.ManagerId = e.ManagerId,
    ce.EmployeeCard = e.EmployeeCard,
    ce.PickupRemark = e.PickupRemark,
    ce.TeamDate = e.TeamDate,
    ce.PromotionDate = e.PromotionDate,
    ce.JobLevelId = e.JobLevelId,
    ce.ManagementLevelId = e.ManagementLevelId,
    ce.ExpertGradeId = e.ExpertGradeId,
    ce.DistanceToCompany = e.DistanceToCompany,
    ce.Enabled = e.Enabled,
    ce.IsDeleted = e.isDeleted,
    ce.GroupId = e.GroupId,
    ce.Roles = e.Roles,
    ce.Email = e.Email,
    ce.OldEmpId = e.OldEmpId,
    ce.CreatedBy = e.CreatedBy,
    ce.CreatedDate = e.CreatedDate,
    ce.ModifiedBy = e.ModifiedBy,
    ce.ModifiedDate = e.ModifiedDate
from dbo.CompanyEmployee as ce
    inner join dbo.Employee as e on e.EmpId = ce.EmpId
where ce.CompanyId not in (@nexcelId, @lumiId, @nexvisionId)

update ce
set ce.Code = e.Code,
    ce.Nickname = e.Nickname,
    ce.JobTitleId = e.JobTitleId,
    ce.EmployeeCard = e.EmployeeCard,
    ce.DistanceToCompany = e.DistanceToCompany,
    ce.OldEmpId = e.OldEmpId,
    ce.CreatedBy = e.CreatedBy,
    ce.CreatedDate = e.CreatedDate,
    ce.ModifiedBy = e.ModifiedBy,
    ce.ModifiedDate = e.ModifiedDate
from dbo.CompanyEmployee as ce
    inner join dbo.Employee as e on e.EmpId = ce.EmpId
where ce.CompanyId in (@nexcelId, @lumiId, @nexvisionId)
go

declare @tmpEmployee table (RowNum int, CompanyId smallint, EmpId int, Nickname nvarchar(50), Enabled bit, IsDeleted bit)
declare @tmpResult table (RowIndex int identity(1,1), CompanyId smallint, EmpId int, Nickname nvarchar(50))
declare @newEmpId int = 7000

insert into @tmpEmployee (RowNum, CompanyId, EmpId, Nickname, Enabled, IsDeleted)
select ROW_NUMBER() OVER (PARTITION BY ce.EmpId ORDER BY ce.Nickname, ce.IsDeleted, ce.Enabled desc, ce.IsSpecialUser, ce.CompanyId) AS RowNum
    ,ce.CompanyId
    ,ce.EmpId
    ,ce.Nickname
    ,ce.Enabled
    ,ce.IsSpecialUser
from dbo.CompanyEmployee as ce
where ce.EmpId in (
    select ce1.EmpId
    from dbo.CompanyEmployee as ce1
    group by ce1.EmpId
    having count(1) > 1
    )
order by ce.Nickname, ce.IsDeleted, ce.Enabled desc, ce.IsSpecialUser, ce.CompanyId

insert into @tmpResult (CompanyId, EmpId, Nickname)
select CompanyId, EmpId, Nickname
from @tmpEmployee
where RowNum > 1

update ce
set ce.EmpId = @newEmpId + e.RowIndex
from dbo.CompanyEmployee as ce
    inner join @tmpResult as e on ce.CompanyId = e.CompanyId and ce.EmpId = e.EmpId