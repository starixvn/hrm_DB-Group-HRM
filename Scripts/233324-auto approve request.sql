/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

/*
Created: 20250731@Tim
Task:  auto approve request
DB: bodb_HRM

Revisions:
    20250731@Tim: init - [Redmine: #233324]
*/

update ce
set ce.AutoApproveRequest = es.IsTopManager
from dbo.CompanyEmployee as ce with (rowlock)
    inner join dbo.EmployeeSummary as es with (nolock) on ce.EmpId = es.EmpId