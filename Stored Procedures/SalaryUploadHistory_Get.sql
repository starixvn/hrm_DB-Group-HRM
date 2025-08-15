/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SalaryUploadHistory_Get]
    @CompanyId INT
AS
/*
	Created: 20250505@Hank.Nguyen
	Task: Get salary upload history.
	DB: SMS-HRM
	Original: 

	Revisions:  
		Hank.Nguyen@20250505: Get salary upload history.
		20250812@Mira: tranfer employee [Redmine: #235678]
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    SELECT 
        su.[FileName],
        su.[SavedFileName],
        su.[CreatedBy],
        su.[CreatedDate],
        su.[PeriodType],
        su.[Month],
        emp.[NickName]  
    FROM [dbo].[SalaryUploadHistory] su
    LEFT JOIN [dbo].[CompanyEmployee] emp ON su.CreatedBy = emp.EmpId
    WHERE su.[CompanyId] = @CompanyId
    ORDER BY su.[CreatedDate] DESC;

END
