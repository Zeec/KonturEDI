IF OBJECT_ID('external_EDIKontur', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_EDIKontur
GO

CREATE PROCEDURE dbo.external_EDIKontur
WITH EXECUTE AS OWNER
AS

-- Необработанные заявки, скорее всего перенести в триггер 
INSERT INTO KonturEDI.dbo.edi_Messages (doc_ID)
SELECT strqt_ID 
FROM tp_StoreRequests
WHERE strqt_strqtyp_ID = 12 
    AND strqt_strqtst_ID = 12
	AND strqt_ID NOT IN (SELECT doc_ID FROM KonturEDI.dbo.edi_Messages)

-- Тут курсор
DECLARE @messageId UNIQUEIDENTIFIER
SELECT TOP 1 @messageId = messageId FROM KonturEDI.dbo.edi_Messages WHERE IsProcessed = 0

IF @messageId IS NOT NULL
  EXEC external_CreateOrdersXML @messageId

-- Обработка статустных сообщений
EXEC external_ImportReports 'C:\kontur\Reports'


