/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CurrencyExchangeRate_Update]
    @CurrencyId INT,
    @OldEffectiveDate DATE,
    @ExchangeRate DECIMAL(20, 10),
    @EffectiveDate DATE,
    @ModifiedBy INT,
    @CurrencyCode VARCHAR(3) = NULL,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(255) = '' OUTPUT
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

    -- Initialize error variables
    SET @ErrCode = 0;
    SET @ErrMsg = '';

    DECLARE @OldCurrencyCode VARCHAR(3);
    DECLARE @xml XML;
    DECLARE @logData NVARCHAR(MAX);
    DECLARE @logOldData NVARCHAR(MAX);

    BEGIN TRY
        -- Validation: Check if currency exists
        SELECT @OldCurrencyCode = CurrencyCode
        FROM Currency
        WHERE Id = @CurrencyId;

        IF @OldCurrencyCode IS NULL
        BEGIN
            SELECT @ErrCode = 1
                ,@ErrMsg = 'Currency not found';
            RETURN;
        END

        -- Validation: Check if CurrencyCode already exists for different currency
        IF @CurrencyCode IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1 
                FROM Currency 
                WHERE CurrencyCode = @CurrencyCode 
                    AND Id <> @CurrencyId
            )
            BEGIN
                SELECT @ErrCode = 1
                    ,@ErrMsg = 'Currency code ' + @CurrencyCode + ' already exists';
                RETURN;
            END
        END

        -- Validation: Check if exchange rate exists
        IF NOT EXISTS (
            SELECT 1 
            FROM CurrencyExchangeRate 
            WHERE CurrencyId = @CurrencyId 
                AND EffectiveDate = @OldEffectiveDate
        )
        BEGIN
            SELECT @ErrCode = 1
                ,@ErrMsg = 'Exchange rate not found';
            RETURN;
        END

        -- Validation: Check if new EffectiveDate already exists (if changed)
        IF @EffectiveDate <> @OldEffectiveDate
        BEGIN
            IF EXISTS (
                SELECT 1 
                FROM CurrencyExchangeRate 
                WHERE CurrencyId = @CurrencyId 
                    AND EffectiveDate = @EffectiveDate
            )
            BEGIN
                SELECT @ErrCode = 1
                    ,@ErrMsg = 'Exchange Rate for ' + @OldCurrencyCode + ' with effective date ' + CONVERT(VARCHAR, @EffectiveDate) + ' already exists';
                RETURN;
            END
        END

        -- Get old data for activity log
        SET @xml = (
            SELECT cer.CurrencyId AS '@CurrencyId'
                ,cer.ExchangeRate AS '@ExchangeRate'
                ,cer.EffectiveDate AS '@EffectiveDate'
                ,c.CurrencyCode AS '@CurrencyCode'
            FROM dbo.CurrencyExchangeRate cer WITH (NOLOCK)
            INNER JOIN dbo.Currency c WITH (NOLOCK) ON cer.CurrencyId = c.Id
            WHERE cer.CurrencyId = @CurrencyId
                AND cer.EffectiveDate = @OldEffectiveDate
            FOR XML PATH('Row'), TYPE
        );
        SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

        -- Update the exchange rate
        UPDATE CurrencyExchangeRate
        SET ExchangeRate = @ExchangeRate,
            EffectiveDate = @EffectiveDate,
            ModifiedBy = @ModifiedBy,
            ModifiedDate = GETDATE()
        WHERE CurrencyId = @CurrencyId 
            AND EffectiveDate = @OldEffectiveDate;

        -- Check if update was successful
        IF @@ROWCOUNT = 0
        BEGIN
            SELECT @ErrCode = 1
                ,@ErrMsg = 'No records were updated';
            RETURN;
        END

        -- Update CurrencyCode in Currency table (if provided and changed)
        IF @CurrencyCode IS NOT NULL AND @CurrencyCode <> @OldCurrencyCode
        BEGIN
            UPDATE Currency
            SET CurrencyCode = @CurrencyCode
            WHERE Id = @CurrencyId;
        END

        -- Get new data for activity log
        SET @xml = (
            SELECT cer.CurrencyId AS '@CurrencyId'
                ,cer.ExchangeRate AS '@ExchangeRate'
                ,cer.EffectiveDate AS '@EffectiveDate'
                ,c.CurrencyCode AS '@CurrencyCode'
            FROM dbo.CurrencyExchangeRate cer WITH (NOLOCK)
            INNER JOIN dbo.Currency c WITH (NOLOCK) ON cer.CurrencyId = c.Id
            WHERE cer.CurrencyId = @CurrencyId
                AND cer.EffectiveDate = @EffectiveDate
            FOR XML PATH('Row'), TYPE
        );
        SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

        -- Log activity
        EXEC dbo.ActivityLog_Insert
            @ObjectTypeId = 11
            ,@ObjectId = NULL
            ,@UserId = @ModifiedBy
            ,@OldData = @logOldData
            ,@Data = @logData
            ,@ErrCode = @ErrCode OUTPUT
            ,@ErrMsg = @ErrMsg OUTPUT;

        -- Check if ActivityLog_Insert failed
        IF @ErrCode <> 0
        BEGIN
            RETURN;
        END

        SELECT @ErrCode = 0
            ,@ErrMsg = 'Exchange Rate updated successfully';
        RETURN;

    END TRY
    BEGIN CATCH
        SELECT @ErrCode = 1
            ,@ErrMsg = ERROR_MESSAGE();
        RETURN;
    END CATCH
END
GO
