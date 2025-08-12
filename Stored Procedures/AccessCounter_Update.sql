/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AccessCounter_Update]
(
    @Date DATE
	,@EmpId INT
	,@FunctionName NVARCHAR(200)
    ,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20250801@Tim
    Task : AccessCounter
    DB: bodb_HRM

    Revisions:
	    20250801@Tim: init [Redmine: #217977]
*/
BEGIN
    SET NOCOUNT ON;

	IF EXISTS (
        SELECT 1
        FROM dbo.AccessCounter WITH (NOLOCK)
        WHERE [Date] = @Date
            AND EmpId = @EmpId
            AND FunctionName = @FunctionName
        )  
	BEGIN  
		UPDATE a  
		SET a.[Count] = a.[Count] + 1
		FROM dbo.AccessCounter AS a WITH (ROWLOCK) 
		WHERE [Date] = @Date
            AND EmpId = @EmpId
            AND FunctionName = @FunctionName
	END  
	ELSE  
	BEGIN  
		INSERT INTO dbo.AccessCounter([Date], EmpId, FunctionName, [Count])
		VALUES(@Date, @EmpId, @FunctionName, 1)
	END
END