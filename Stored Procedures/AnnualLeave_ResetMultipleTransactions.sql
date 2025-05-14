/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_ResetMultipleTransactions] @EmpValue VARCHAR(MAX)
	,@Description NVARCHAR(4000) = NULL
	,@FromDate DATE
	,@ResetDays NUMERIC(18, 1)
	,@ActorId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-10-23
Task: reset anual balance
DB: HRM_SMS
Original:

Revisions:
Param's Explanation:
	@EmpValue:
		<ROOT><Employee Id="1" LeaveBalance="2"/></ROOT>
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @xml XML
	DECLARE @Emp TABLE (
		EmpID INT
		,LeaveBalance DECIMAL
		)

	SET @xml = CONVERT(XML, @EmpValue)

	INSERT INTO @Emp (
		EmpID
		,LeaveBalance
		)
	SELECT T.C.value('./@Id', 'int')
		,T.C.value('./@LeaveBalance', 'numeric(18,1)')
	FROM @xml.nodes('/ROOT/Employee') AS [T](C) --T: table, C: column

	BEGIN TRY
		BEGIN TRANSACTION;

		INSERT INTO dbo.LeaveTrans (
			EmpId
			,[Description]
			,FromDate
			,DeductDays
			,CreditDays
			,CreatedDate
			,CreatedBy
			)
		SELECT EmpID
			,@Description
			,@FromDate
			,LeaveBalance - @ResetDays
			,0
			,GETDATE()
			,@ActorId
		FROM @Emp

		UPDATE e
		SET e.AnnualLeaveBalance = e.AnnualLeaveBalance - (d.LeaveBalance - @ResetDays)
		FROM dbo.EmployeeSummary AS e
			INNER JOIN @Emp AS d ON e.EmpID = d.EmpID

		COMMIT TRANSACTION;
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION;

		SELECT @ErrCode = 100
			,@ErrMsg = N'Reset annual balance failed.'
	END CATCH;
END