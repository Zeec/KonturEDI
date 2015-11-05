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
	,@nttp_ID_Status UNIQUEIDENTIFIER
	,@nttp_ID_Log UNIQUEIDENTIFIER
	,@Value sql_variant

--
SELECT TOP 1 @nttp_ID_Status = nttp_ID_Status, @nttp_ID_Log = nttp_ID_Log 
FROM KonturEDI.dbo.edi_Settings
--
IF @doc_Type = 'request'
    SELECT @tpsyso_ID = tpsyso_ID
    FROM sys_Objects
    WHERE tpsyso_Name LIKE '%������ �� �������%'
IF @doc_Type = 'input'
    SELECT @tpsyso_ID = tpsyso_ID
    FROM sys_Objects
    WHERE tpsyso_Name LIKE '%��������� ���������%'
--
SELECT @note_ID = note_ID FROM Notes WHERE note_nttp_ID = @nttp_ID_Status AND note_obj_ID = @doc_ID
--
SET @Value = CONVERT(NVARCHAR(4000), CONVERT(NVARCHAR(MAX), ISNULL(@Date, GETDATE()), 127) + ' - ' + @Status)

-- ������ ������
IF @note_ID IS NOT NULL
    DELETE FROM Notes WHERE note_ID = @note_ID

INSERT INTO Notes (note_ID, note_nttp_ID, note_obj_ID, note_item_ID, note_Value, note_tpsyso_ID)
VALUES(NEWID(), @nttp_ID_Status, @doc_ID, @doc_ID, @Value, @tpsyso_ID)

/*ELSE 
    UPDATE Notes
	SET note_Value = @Value 
	WHERE note_ID = @note_ID*/

-- Log
INSERT INTO Notes (note_ID, note_nttp_ID, note_obj_ID, note_item_ID, note_Value, note_tpsyso_ID)
VALUES(NEWID(), @nttp_ID_log, @doc_ID, @doc_ID, @Value, @tpsyso_ID)
  

