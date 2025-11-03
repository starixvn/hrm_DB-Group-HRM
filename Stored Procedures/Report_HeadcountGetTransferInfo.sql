/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_HeadcountGetTransferInfo] @Year INT
AS
/*
    Created: 20251027@Mira
    Task: get employee transfer
    DB: bodb_HRM

    Revisions:
        20251027@Mira: get employee transfer - [Redmine: #242668]
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @FromDate DATETIME = DATEFROMPARTS(@Year, 1, 1);
	DECLARE @ToDate DATETIME = DATEFROMPARTS(@Year, 12, 31);

	-- Get Transfer OUT
	SELECT 
		t.TransferId,
		t.ToEmpId AS EmpId,
		NULL AS FromCompanyId,
		ce_to.CompanyId AS ToCompanyId,
		t.TransferInDate AS TransferDate
	FROM dbo.EmployeeTransfer t WITH(NOLOCK)
	LEFT JOIN dbo.CompanyEmployee ce_to WITH(NOLOCK) ON t.ToEmpId = ce_to.EmpId
	WHERE t.TransferOutDate <= @ToDate AND t.TransferOutDate >= @FromDate

	-- Get Transfer IN
	SELECT 
		t.TransferId,
		t.FromEmpId AS EmpId,
		ce_from.CompanyId AS FromCompanyId,
		NULL AS ToCompanyId,
		t.TransferOutDate AS TransferDate
	FROM dbo.EmployeeTransfer t WITH(NOLOCK)
	LEFT JOIN dbo.CompanyEmployee ce_from WITH(NOLOCK) ON t.FromEmpId = ce_from.EmpId
	WHERE t.TransferOutDate <= @ToDate AND t.TransferOutDate >= @FromDate
END