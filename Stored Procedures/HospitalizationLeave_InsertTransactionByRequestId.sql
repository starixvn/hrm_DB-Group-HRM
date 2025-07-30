/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[HospitalizationLeave_InsertTransactionByRequestId] @RequestId INT
	,@EmpId INT
	,@FromDate DATETIME
	,@ToDate DATETIME
	,@CreatedBy INT
AS
/*
Created: Tim.Trinh@2021-08-24
Task: insert hospitalization leave transaction
DB: HRM
Original: 

Revisions:    
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @CreatedDate DATETIME = GETDATE()
		,@tmpDate DATETIME = @FromDate
		,@tmpStartDate DATETIME
		,@tmpEndDate DATETIME
		,@LeaveDay NUMERIC(5, 1)

	WHILE DATEDIFF(MM, @tmpDate, @ToDate) >= 0
	BEGIN
		SELECT @tmpStartDate = CASE 
				WHEN DATEDIFF(MM, @tmpDate, @FromDate) = 0 THEN @FromDate
				ELSE DATEADD(MM, DATEDIFF(MM, 0, @tmpDate), 0)
				END
			,@tmpEndDate = CASE 
				WHEN DATEDIFF(MM, @tmpDate, @ToDate) = 0 THEN @ToDate
				ELSE EOMONTH(@tmpDate)
				END
			,@LeaveDay = 0

		SELECT @LeaveDay = TotalDays
		FROM dbo.tmpHospitalizationLeaveBalance WITH (NOLOCK)
		WHERE RequestId = @RequestId
			AND [Year] = YEAR(@tmpDate)
			AND [Month] = MONTH(@tmpDate)

		IF ISNULL(@LeaveDay, 0) > 0
		BEGIN
			EXEC dbo.HospitalizationLeave_InsertTransaction @EmpId
				,@RequestId
				,'Leave Request'
				,@tmpStartDate
				,@tmpEndDate
				,@LeaveDay
				,NULL
				,@CreatedDate
				,@CreatedBy
		END

		SET @tmpDate = DATEADD(MM, 1, @tmpDate)
	END
END




