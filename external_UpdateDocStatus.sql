IF OBJECT_ID('external_UpdateDocStatus', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_UpdateDocStatus
GO

CREATE PROCEDURE dbo.external_UpdateDocStatus (
    @doc_ID UNIQUEIDENTIFIER,
	@Staus NVARCHAR(MAX),
	@Date DATETIME = NULL)
AS
DECLARE 
     @note_ID UNIQUEIDENTIFIER
    ,@tpsyso_ID UNIQUEIDENTIFIER
	,@nttp_ID UNIQUEIDENTIFIER
	,@Value sql_variant

SET @nttp_ID = 'FC9F6DE1-3CF3-5247-AE66-8EFC7B40C5B8'
--
SELECT @tpsyso_ID = tpsyso_ID
FROM sys_Objects
WHERE tpsyso_Name like '%Заявки на закупку%'
--
SELECT @note_ID = note_ID FROM Notes WHERE note_nttp_ID = @nttp_ID AND note_obj_ID = @doc_ID
--
SET @Value = CONVERT(NVARCHAR(4000), @Staus + ' в ' + CONVERT(NVARCHAR(MAX), ISNULL(@Date, GETDATE()), 113))

-- Статус заявки
IF @note_ID IS NULL
    INSERT INTO Notes (note_ID, note_nttp_ID, note_obj_ID, note_item_ID, note_Value, note_tpsyso_ID)
    VALUES(NEWID(), @nttp_ID, @doc_ID, @doc_ID, @Value, @tpsyso_ID)
ELSE 
    UPDATE Notes
	SET note_Value = @Value 
	WHERE note_ID = @note_ID
   
