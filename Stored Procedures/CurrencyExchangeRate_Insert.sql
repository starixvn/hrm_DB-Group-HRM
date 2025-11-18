/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CurrencyExchangeRate_Insert]
    @CurrencyCode VARCHAR(3),
    @ExchangeRate DECIMAL(20, 10),
    @EffectiveDate DATE,
    @ModifiedBy INT,
    @Rounding SMALLINT
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

    DECLARE @errmsg NVARCHAR(255) = '';
    DECLARE @errcode INT = 0;
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
            INSERT INTO Currency (CurrencyCode, Rounding)
            VALUES (@CurrencyCode, @Rounding);

            SET @CurrencyId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- Update Rounding if currency already exists
            UPDATE Currency
            SET Rounding = @Rounding
            WHERE Id = @CurrencyId;
        END

        -- Check if exchange rate with same EffectiveDate already exists
        IF EXISTS (
            SELECT 1 
            FROM CurrencyExchangeRate 
            WHERE CurrencyId = @CurrencyId 
                AND EffectiveDate = @EffectiveDate
        )
        BEGIN
            SET @errcode = 1;
            SET @errmsg = 'Exchange rate for ' + @CurrencyCode + ' with effective date ' + CONVERT(VARCHAR, @EffectiveDate) + ' already exists';
            GOTO ErrorHandler;
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
        DECLARE @xml XML
            ,@logData NVARCHAR(MAX)

        SET @xml = (
                SELECT cer.CurrencyId AS '@CurrencyId'
                    ,cer.ExchangeRate AS '@ExchangeRate'
                    ,cer.EffectiveDate AS '@EffectiveDate'
                    ,c.Rounding AS '@Rounding'
                FROM dbo.CurrencyExchangeRate cer WITH (NOLOCK)
                INNER JOIN dbo.Currency c WITH (NOLOCK) ON cer.CurrencyId = c.Id
                WHERE cer.CurrencyId = @CurrencyId
                    AND cer.EffectiveDate = @EffectiveDate
                FOR XML PATH('Row')
                    ,TYPE
                )
        SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

        EXEC dbo.ActivityLog_Insert
            @ObjectTypeId = 11
            ,@ObjectId = @CurrencyExchangeRateId
            ,@UserId = @ModifiedBy
            ,@OldData = NULL
            ,@Data = @logData
            ,@ErrCode = @errcode OUTPUT
            ,@ErrMsg = @errmsg OUTPUT

        SET @errmsg = 'Exchange Rate added successfully';
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