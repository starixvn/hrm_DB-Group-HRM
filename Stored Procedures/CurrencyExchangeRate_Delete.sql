/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CurrencyExchangeRate_Delete]
    @CurrencyId INT,
    @EffectiveDate DATE,
    @ModifiedBy INT
AS

/*
    Created: 20251114@Lilac
    Task : Delete currency exchange rate
    DB: bodb_HRM

    Revisions:
        20251114@Lilac: init
*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @errmsg NVARCHAR(255) = '';
    DECLARE @errcode INT = 0;
    DECLARE @xml XML
        ,@logOldData NVARCHAR(MAX)

    BEGIN TRY
        -- Check if exchange rate exists
        IF NOT EXISTS (
            SELECT 1 
            FROM CurrencyExchangeRate 
            WHERE CurrencyId = @CurrencyId 
                AND EffectiveDate = @EffectiveDate
        )
        BEGIN
            SET @errcode = 1;
            SET @errmsg = 'Exchange Rate not found';
            GOTO ErrorHandler;
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
                    AND cer.EffectiveDate = @EffectiveDate
                FOR XML PATH('Row')
                    ,TYPE
                )
        SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

        -- Delete the exchange rate
        DELETE FROM CurrencyExchangeRate
        WHERE CurrencyId = @CurrencyId 
            AND EffectiveDate = @EffectiveDate;

        -- Log activity
        EXEC dbo.ActivityLog_Insert
            @UserId = @ModifiedBy
            ,@ObjectTypeId = 11
            ,@ObjectId = NULL
            ,@OldData = @logOldData
            ,@Data = NULL
            ,@ErrCode = @errcode OUTPUT
            ,@ErrMsg = @errmsg OUTPUT

        SET @errmsg = 'Exchange Rate deleted successfully';
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

