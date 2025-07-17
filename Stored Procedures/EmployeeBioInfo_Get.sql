/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/
CREATE OR ALTER     PROCEDURE [dbo].[EmployeeBioInfo_Get]
    @EmpId INT = NULL,
    @CompanyId INT,
    @CurrentDate DATETIME = NULL,
    @ClientIp VARCHAR(100)
AS
/*
Created: 2025-07-14 @Jay.Do  
Task: Get employee bio info by ID  
DB: HRM  
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @WhitelistJson NVARCHAR(MAX);
    DECLARE @IsWhitelisted BIT = 0;

    -- Get Whitelist IPs from config (JSON array)
    SELECT @WhitelistJson = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE [Key] = 'WhitelistIPs'
      AND CompanyId = @CompanyId;
	  
    -- Check if '*' is in the Whitelist JSON array
    IF CHARINDEX('*', @WhitelistJson) > 0
    BEGIN
        SET @IsWhitelisted = 1;
    END
    -- Check if client IP is in the whitelist JSON array
    ELSE IF EXISTS (
        SELECT 1
        FROM OPENJSON(@WhitelistJson)
        WHERE value = @ClientIp
    )
    BEGIN
        SET @IsWhitelisted = 1;
    END

    SELECT
        -- 1. HasBio
        ISNULL((
            SELECT TOP 1 [Value]
            FROM dbo.SystemConfigs WITH (NOLOCK)
            WHERE [Key] = 'HasBio'
              AND CompanyId = @CompanyId
        ), 'false') AS HasBio,

        -- 2. IsWhitelisted (based on client IP)
        CAST(@IsWhitelisted AS BIT) AS IsWhitelisted,

        -- 3. IsWorkingFromHome
        CASE 
            WHEN @EmpId IS NOT NULL THEN ISNULL((
                SELECT TOP 1 1
                FROM dbo.EmployeeWorkFromHome ewfh WITH (NOLOCK)
                WHERE ewfh.EmpId = @EmpId
				  AND @CurrentDate >= ewfh.FromDate 
				  AND DATEADD(DD, -1, @CurrentDate) <= ewfh.ToDate
            ), 0)
            ELSE 0
        END AS IsWorkFromHome,

        -- 4. WFHNearlyExpired
        CASE 
            WHEN @EmpId IS NOT NULL THEN ISNULL((
                SELECT TOP 1 1
                FROM dbo.EmployeeWorkFromHome ewfh WITH (NOLOCK)
                WHERE ewfh.EmpId = @EmpId
                  AND @CurrentDate BETWEEN ewfh.FromDate AND ewfh.ToDate
                  AND DATEDIFF(DAY, @CurrentDate, ewfh.ToDate) BETWEEN 0 AND 3
            ), 0)
            ELSE 0
        END AS IsWFHNearlyExpired,

        -- 5. IsSecondment
        CASE 
            WHEN @EmpId IS NOT NULL THEN ISNULL((
                SELECT TOP 1 1
                FROM dbo.CompanySecondmentEmployee WITH (NOLOCK)
                WHERE EmpId = @EmpId
            ), 0)
            ELSE 0
        END AS IsSecondment;
END