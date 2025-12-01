/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/
/*
    Created: Lilac@20251201
    Task: Calculate allowance
    DB: bodb_HRM

    Revisions:
        20251201@Lilac: add new column to calculate allowance [Redmine: #245214]
*/

USE bodb_HRM
GO

ALTER TABLE [dbo].[MonthlySalary]
ADD JobLevelAddOn VARCHAR(100) NULL,
	SpecialSubsidy VARCHAR(100) NULL,
	ManagementAllowance VARCHAR(100) NULL,
    TransportationAllowance VARCHAR(100) NULL,
    MobilephoneAllowance VARCHAR(100) NULL,
	TotalIncome VARCHAR(100) NULL;
GO