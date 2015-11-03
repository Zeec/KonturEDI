SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_UpdateDocStatus', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_UpdateDocStatus
GO

CREATE PROCEDURE dbo.external_UpdateDocStatus (
     @doc_ID UNIQUEIDENTIFIER
	,@doc_Type NVARCHAR(50)
	,@Status NVARCHAR(MAX)
	,@Date DATETIME = NULL)
AS
DECLARE 
     @note_ID UNIQUEIDENTIFIER
    ,@tpsyso_ID UNIQUEIDENTIFIER
	,@nttp_ID UNIQUEIDENTIFIER
	,@nttp_ID_log UNIQUEIDENTIFIER
	,@Value sql_variant

SET @nttp_ID = 'FC9F6DE1-3CF3-5247-AE66-8EFC7B40C5B8'
SET @nttp_ID_log = '7A89CB1E-8976-0144-9A26-15D6246CB826'
--
IF @doc_Type = 'request'
    SELECT @tpsyso_ID = tpsyso_ID
    FROM sys_Objects
    WHERE tpsyso_Name LIKE '%Заявки на закупку%'
IF @doc_Type = 'input'
    SELECT @tpsyso_ID = tpsyso_ID
    FROM sys_Objects
    WHERE tpsyso_Name LIKE '%Приходная накладная%'
--
SELECT @note_ID = note_ID FROM Notes WHERE note_nttp_ID = @nttp_ID AND note_obj_ID = @doc_ID
--
SET @Value = CONVERT(NVARCHAR(4000), CONVERT(NVARCHAR(MAX), ISNULL(@Date, GETDATE()), 127) + ' - ' + @Status)

-- Статус заявки
IF @note_ID IS NOT NULL
    DELETE FROM Notes WHERE note_ID = @note_ID

INSERT INTO Notes (note_ID, note_nttp_ID, note_obj_ID, note_item_ID, note_Value, note_tpsyso_ID)
VALUES(NEWID(), @nttp_ID, @doc_ID, @doc_ID, @Value, @tpsyso_ID)

/*ELSE 
    UPDATE Notes
	SET note_Value = @Value 
	WHERE note_ID = @note_ID*/

-- Log
INSERT INTO Notes (note_ID, note_nttp_ID, note_obj_ID, note_item_ID, note_Value, note_tpsyso_ID)
VALUES(NEWID(), @nttp_ID_log, @doc_ID, @doc_ID, @Value, @tpsyso_ID)
  

