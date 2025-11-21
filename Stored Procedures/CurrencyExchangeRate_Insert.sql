/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CurrencyExchangeRate_Insert]
    @CurrencyCode VARCHAR(3),
    @ExchangeRate DECIMAL(20, 10),
    @EffectiveDate DATE,
    @ModifiedBy INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(255) = '' OUTPUT
AS

/*
    Created: 20251114@Lilac
    Task : Insert currency exchange rate
    DB: bodb_HRM

    Revisions:
        20251114@Lilac: init
*/

BEGIN
    SET NOCOUNT ON;

    -- Initialize error variables
    SET @ErrCode = 0;
    SET @ErrMsg = '';

    DECLARE @CurrencyId INT;
    DECLARE @CurrencyExchangeRateId INT;

    BEGIN TRY
        -- Check if currency already exists
        SELECT @CurrencyId = Id
        FROM Currency
        WHERE CurrencyCode = @CurrencyCode;

        -- If currency doesn't exist, insert it
        IF @CurrencyId IS NULL
        BEGIN
            INSERT INTO Currency (CurrencyCode)
            VALUES (@CurrencyCode);

            SET @CurrencyId = SCOPE_IDENTITY();
        END

        -- Check if exchange rate with same EffectiveDate already exists
        IF EXISTS (
            SELECT 1 
            FROM CurrencyExchangeRate 
            WHERE CurrencyId = @CurrencyId 
                AND EffectiveDate = @EffectiveDate
        )
        BEGIN
            SELECT @ErrCode = 1
                ,@ErrMsg = 'Exchange rate for ' + @CurrencyCode + ' with effective date ' + CONVERT(VARCHAR, @EffectiveDate) + ' already exists';
            RETURN;
        END

        -- Insert the exchange rate
        INSERT INTO CurrencyExchangeRate (
            CurrencyId,
            ExchangeRate,
            EffectiveDate,
            ModifiedBy,
            ModifiedDate
        )
        VALUES (
            @CurrencyId,
            @ExchangeRate,
            @EffectiveDate,
            @ModifiedBy,
            GETDATE()
        );

        SET @CurrencyExchangeRateId = SCOPE_IDENTITY();

        -- Log activity
        DECLARE @xml XML;
        DECLARE @logData NVARCHAR(MAX);

        SET @xml = (
            SELECT cer.CurrencyId AS '@CurrencyId'
                ,cer.ExchangeRate AS '@ExchangeRate'
                ,cer.EffectiveDate AS '@EffectiveDate'
            FROM dbo.CurrencyExchangeRate cer WITH (NOLOCK)
            INNER JOIN dbo.Currency c WITH (NOLOCK) ON cer.CurrencyId = c.Id
            WHERE cer.CurrencyId = @CurrencyId
                AND cer.EffectiveDate = @EffectiveDate
            FOR XML PATH('Row'), TYPE
        );
        SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

        EXEC dbo.ActivityLog_Insert
            @ObjectTypeId = 11
            ,@ObjectId = @CurrencyExchangeRateId
            ,@UserId = @ModifiedBy
            ,@OldData = NULL
            ,@Data = @logData
            ,@ErrCode = @ErrCode OUTPUT
            ,@ErrMsg = @ErrMsg OUTPUT;

        -- Check if ActivityLog_Insert failed
        IF @ErrCode <> 0
        BEGIN
            RETURN;
        END

        SELECT @ErrCode = 0
            ,@ErrMsg = 'Exchange Rate added successfully';
        RETURN;

    END TRY
    BEGIN CATCH
        SELECT @ErrCode = 1
            ,@ErrMsg = ERROR_MESSAGE();
        RETURN;
    END CATCH
END
GO