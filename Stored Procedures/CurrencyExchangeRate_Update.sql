/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CurrencyExchangeRate_Update]
    @CurrencyId INT,
    @OldEffectiveDate DATE,
    @ExchangeRate DECIMAL(20, 10),
    @EffectiveDate DATE,
    @ModifiedBy INT,
    @Rounding SMALLINT,
    @CurrencyCode VARCHAR(3) = NULL
AS

/*
    Created: 20251117@Lilac
    Task : Update currency exchange rate
    DB: bodb_HRM

    Revisions:
        20251114@Lilac: init
*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @errmsg NVARCHAR(255) = '';
    DECLARE @errcode INT = 0;
    DECLARE @OldCurrencyCode VARCHAR(3);
    DECLARE @xml XML
        ,@logData NVARCHAR(MAX)
        ,@logOldData NVARCHAR(MAX)

    BEGIN TRY
        -- Get currency code
        SELECT @OldCurrencyCode = CurrencyCode
        FROM Currency
        WHERE Id = @CurrencyId;

        IF @OldCurrencyCode IS NULL
        BEGIN
            SET @errcode = 1;
            SET @errmsg = 'Currency not found';
            GOTO ErrorHandler;
        END

        -- If CurrencyCode is provided, check if it already exists (if changed)
        IF @CurrencyCode IS NOT NULL AND @CurrencyCode <> @OldCurrencyCode
        BEGIN
            IF EXISTS (
                SELECT 1 
                FROM Currency 
                WHERE CurrencyCode = @CurrencyCode 
                    AND Id <> @CurrencyId
            )
            BEGIN
                SET @errcode = 1;
                SET @errmsg = 'Currency code ' + @CurrencyCode + ' already exists';
                GOTO ErrorHandler;
            END
        END

        -- Check if exchange rate exists
        IF NOT EXISTS (
            SELECT 1 
            FROM CurrencyExchangeRate 
            WHERE CurrencyId = @CurrencyId 
                AND EffectiveDate = @OldEffectiveDate
        )
        BEGIN
            SET @errcode = 1;
            SET @errmsg = 'Exchange rate not found';
            GOTO ErrorHandler;
        END

        -- Check if new EffectiveDate already exists (if EffectiveDate changed)
        IF @EffectiveDate <> @OldEffectiveDate
        BEGIN
            IF EXISTS (
                SELECT 1 
                FROM CurrencyExchangeRate 
                WHERE CurrencyId = @CurrencyId 
                    AND EffectiveDate = @EffectiveDate
            )
            BEGIN
                SET @errcode = 1;
                SET @errmsg = 'Exchange Rate for ' + @OldCurrencyCode + ' with effective date ' + CONVERT(VARCHAR, @EffectiveDate) + ' already exists';
                GOTO ErrorHandler;
            END
        END

        -- Get old data for log
        SET @xml = (
                SELECT cer.CurrencyId AS '@CurrencyId'
                    ,cer.ExchangeRate AS '@ExchangeRate'
                    ,cer.EffectiveDate AS '@EffectiveDate'
                    ,c.Rounding AS '@Rounding'
                    ,c.CurrencyCode AS '@CurrencyCode'
                FROM dbo.CurrencyExchangeRate cer WITH (NOLOCK)
                INNER JOIN dbo.Currency c WITH (NOLOCK) ON cer.CurrencyId = c.Id
                WHERE cer.CurrencyId = @CurrencyId
                    AND cer.EffectiveDate = @OldEffectiveDate
                FOR XML PATH('Row')
                    ,TYPE
                )
        SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

        -- Update the exchange rate
        UPDATE CurrencyExchangeRate
        SET ExchangeRate = @ExchangeRate,
            EffectiveDate = @EffectiveDate,
            ModifiedBy = @ModifiedBy,
            ModifiedDate = GETDATE()
        WHERE CurrencyId = @CurrencyId 
            AND EffectiveDate = @OldEffectiveDate;

        -- Update CurrencyCode and Rounding in Currency table
        UPDATE Currency
        SET CurrencyCode = CASE WHEN @CurrencyCode IS NOT NULL THEN @CurrencyCode ELSE CurrencyCode END,
            Rounding = @Rounding
        WHERE Id = @CurrencyId;

        -- Get new data for log
        SET @xml = (
                SELECT cer.CurrencyId AS '@CurrencyId'
                    ,cer.ExchangeRate AS '@ExchangeRate'
                    ,cer.EffectiveDate AS '@EffectiveDate'
                    ,c.Rounding AS '@Rounding'
                    ,c.CurrencyCode AS '@CurrencyCode'
                FROM dbo.CurrencyExchangeRate cer WITH (NOLOCK)
                INNER JOIN dbo.Currency c WITH (NOLOCK) ON cer.CurrencyId = c.Id
                WHERE cer.CurrencyId = @CurrencyId
                    AND cer.EffectiveDate = @EffectiveDate
                FOR XML PATH('Row')
                    ,TYPE
                )
        SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

        -- Log activity
        EXEC dbo.ActivityLog_Insert
            @ObjectTypeId = 11
            ,@ObjectId = NULL
            ,@UserId = @ModifiedBy
            ,@OldData = @logOldData
            ,@Data = @logData
            ,@ErrCode = @errcode OUTPUT
            ,@ErrMsg = @errmsg OUTPUT

        SET @errmsg = 'Exchange Rate updated successfully';
        GOTO SuccessHandler;

    END TRY
    BEGIN CATCH
        SET @errcode = 1;
        SET @errmsg = ERROR_MESSAGE();
        GOTO ErrorHandler;
    END CATCH

    SuccessHandler:
        SELECT @errcode AS errcode, @errmsg AS errmsg;
        RETURN;

    ErrorHandler:
        SELECT @errcode AS errcode, @errmsg AS errmsg;
        RETURN;
END
GO

