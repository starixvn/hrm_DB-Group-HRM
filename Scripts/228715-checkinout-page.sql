USE bodb_HRM
GO

CREATE TABLE Currency (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    CurrencyCode VARCHAR(3) NOT NULL UNIQUE
);

INSERT INTO Currency (CurrencyCode)
VALUES 
('CNY'),
('EUR'),
('GBP'),
('MYR'),
('NTD'),
('PHP'),
('SGD'),
('THB'),
('USD'),
('VND');

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Company_Get]
AS

/*
Created: 20250714@Lilac.Nguyen
Task: Get Setting Companys
DB: HRM
Original:

Revisions:

*/

BEGIN
    SET NOCOUNT ON;

	SELECT 
		c.CompanyId,
		c.[Name],
		cfg.HasBIO,
		cfg.EnableLetstalk,
		cfg.WhitelistIPs,
		cur.Currency
	FROM dbo.Company c

	LEFT JOIN (
		SELECT 
			CompanyId,
			[HasBIO],
			[WhitelistIPs],
			[EnableLetstalk],
			[Currency]
		FROM (
			SELECT 
				CompanyId, [Key], [Value]
			FROM dbo.SystemConfigs
			WHERE [Key] IN ('HasBIO', 'WhitelistIPs', 'EnableLetstalk', 'Currency')
		) AS raw
		PIVOT (
			MAX([Value])
			FOR [Key] IN ([HasBIO], [WhitelistIPs], [EnableLetstalk], [Currency])
		) AS pvt
	) cfg ON c.CompanyId = cfg.CompanyId

	LEFT JOIN (
		SELECT 
			sc.CompanyId,
			STUFF((
				SELECT ', ' + c.CurrencyCode
				FROM STRING_SPLIT(sc.[Value], ',') AS s
				JOIN dbo.Currency c ON c.Id = TRY_CAST(s.value AS INT)
				FOR XML PATH(''), TYPE
			).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS Currency
		FROM dbo.SystemConfigs sc
		WHERE sc.[Key] = 'Currency'
	) cur ON cur.CompanyId = c.CompanyId

	WHERE ISNULL(c.IsDeleted, 0) = 0
	ORDER BY c.CompanyId;

END;

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Company_GetById]
    @CompanyId INT
AS

/*
Created: 20250714@Lilac.Nguyen
Task: Get Company by CompanyId
DB: HRM
Original:

Revisions:

*/

BEGIN
    SET NOCOUNT ON;

    SELECT 
        c.CompanyId,
        c.[Name],
        cfg.HasBIO,
        cfg.Currency,
        cfg.EnableLetstalk,
        cfg.WhitelistIPs
    FROM dbo.Company c
    LEFT JOIN (
        SELECT 
            CompanyId,
            [HasBIO],
            [WhitelistIPs],
            [EnableLetstalk],
            [Currency]
        FROM (
            SELECT CompanyId, [Key], [Value]
            FROM dbo.SystemConfigs
            WHERE [Key] IN ('HasBIO', 'WhitelistIPs', 'EnableLetstalk', 'Currency')
        ) AS raw
        PIVOT (
            MAX([Value])
            FOR [Key] IN ([HasBIO], [WhitelistIPs], [EnableLetstalk], [Currency])
        ) AS pvt
    ) cfg ON c.CompanyId = cfg.CompanyId
    WHERE ISNULL(c.IsDeleted, 0) = 0
      AND c.CompanyId = @CompanyId;
END;

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Currency_Get]
AS
/*
Created: 20250714@Lilac.Nguyen
Task: get currency
DB: HRM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT  Id
		,[CurrencyCode]
	FROM dbo.Currency WITH (NOLOCK)
END

GO

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

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SystemConfigs_UpdateCompanySetting]
    @CompanyId INT,
    @HasBIO VARCHAR(10),
    @EnableLetstalk VARCHAR(10),
    @WhitelistIPs VARCHAR(MAX),
    @Currency VARCHAR(MAX)
AS

/*
Created: 20250715@Lilac.Nguyen
Task: Update Setting Companys
DB: HRM
Original:

Revisions:

*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @Configs TABLE (
        [Key] VARCHAR(30),
        [Value] VARCHAR(MAX)
    );

    INSERT INTO @Configs ([Key], [Value])
    VALUES 
        ('HasBIO', LTRIM(RTRIM(@HasBIO))),
        ('EnableLetstalk', LTRIM(RTRIM(@EnableLetstalk))),
        ('WhitelistIPs', LTRIM(RTRIM(@WhitelistIPs))),
        ('Currency', LTRIM(RTRIM(@Currency)));

    UPDATE sc
    SET sc.[Value] = cfg.[Value]
    FROM dbo.SystemConfigs sc
    JOIN @Configs cfg ON sc.[Key] = cfg.[Key]
    WHERE sc.CompanyId = @CompanyId;

    INSERT INTO dbo.SystemConfigs (CompanyId, [Key], [Value])
    SELECT @CompanyId, cfg.[Key], cfg.[Value]
    FROM @Configs cfg
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SystemConfigs sc
        WHERE sc.CompanyId = @CompanyId AND sc.[Key] = cfg.[Key]
    );
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[TimeRecord_GetPrivilegeCreateCheckInOut] @EmpId INT,
	@CurrentDate DATETIME
AS
/*
Created: 20210527@Quinn.Vo
Task: Get Privilege Create Check In/Out Record.
DB: HRM
Original: 

Revisions:  
    - 20250716@Jay: Fix check by server timezone [Redmine: #228715]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsPrivilegeCreateCheckInOut BIT = 0

	IF (EXISTS(SELECT 1 FROM dbo.EmployeeWorkFromHome WITH (NOLOCK) 
		WHERE EmpId = @EmpId 
			AND @CurrentDate >= FromDate 
			AND DATEADD (DD, -1, @CurrentDate) <= ToDate))
	BEGIN
		SET @IsPrivilegeCreateCheckInOut = 1
	END

	SELECT @IsPrivilegeCreateCheckInOut
END

GO

