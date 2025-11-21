/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CurrencyExchangeRate_Delete]
    @CurrencyId INT,
    @EffectiveDate DATE,
    @ModifiedBy INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(255) = '' OUTPUT
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

    -- Initialize error variables
    SET @ErrCode = 0;
    SET @ErrMsg = '';

    DECLARE @xml XML;
    DECLARE @logOldData NVARCHAR(MAX);

    BEGIN TRY
        -- Validation: Check if exchange rate exists
        IF NOT EXISTS (
            SELECT 1 
            FROM CurrencyExchangeRate 
            WHERE CurrencyId = @CurrencyId 
                AND EffectiveDate = @EffectiveDate
        )
        BEGIN
            SELECT @ErrCode = 1
                ,@ErrMsg = 'Exchange Rate not found';
            RETURN;
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
                AND cer.EffectiveDate = @EffectiveDate
            FOR XML PATH('Row'), TYPE
        );
        SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

        -- Delete the exchange rate
        DELETE FROM CurrencyExchangeRate
        WHERE CurrencyId = @CurrencyId 
            AND EffectiveDate = @EffectiveDate;

        -- Check if delete was successful
        IF @@ROWCOUNT = 0
        BEGIN
            SELECT @ErrCode = 1
                ,@ErrMsg = 'No records were deleted';
            RETURN;
        END

        -- Log activity
        EXEC dbo.ActivityLog_Insert
            @ObjectTypeId = 11
            ,@ObjectId = NULL
            ,@UserId = @ModifiedBy
            ,@OldData = @logOldData
            ,@Data = NULL
            ,@ErrCode = @ErrCode OUTPUT
            ,@ErrMsg = @ErrMsg OUTPUT;

        -- Check if ActivityLog_Insert failed
        IF @ErrCode <> 0
        BEGIN
            RETURN;
        END

        SELECT @ErrCode = 0
            ,@ErrMsg = 'Exchange Rate deleted successfully';
        RETURN;

    END TRY
    BEGIN CATCH
        SELECT @ErrCode = 1
            ,@ErrMsg = ERROR_MESSAGE();
        RETURN;
    END CATCH
END
GO
