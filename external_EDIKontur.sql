SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_EDIKontur', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_EDIKontur
GO

CREATE PROCEDURE dbo.external_EDIKontur
WITH EXECUTE AS OWNER
AS

DECLARE @cmd VARCHAR(200)

-- Необработанные заявки, скорее всего перенести в триггер 
INSERT INTO KonturEDI.dbo.edi_Messages (doc_ID, doc_Name, doc_Date, doc_Type)
SELECT strqt_ID, strqt_Name, strqt_Date, 'request'
FROM StoreRequests
WHERE strqt_strqtyp_ID = 12 
    AND strqt_strqtst_ID = 12
	AND strqt_ID NOT IN (SELECT doc_ID FROM KonturEDI.dbo.edi_Messages)

-- Тут курсор
DECLARE @messageId UNIQUEIDENTIFIER, @doc_ID UNIQUEIDENTIFIER

SELECT TOP 1 @messageId = messageId, @doc_ID = doc_ID FROM KonturEDI.dbo.edi_Messages WHERE doc_Type = 'request' AND IsProcessed = 0

IF @messageId IS NOT NULL BEGIN
  EXEC external_ExportORDERS @messageId
  EXEC external_UpdateDocStatus @doc_ID, 'Отправлена' --, current_timestamp
END

-- Предача на фтп
SET @cmd = 'c:\kontur\actions\put_outbox.cmd'
EXEC master..xp_cmdshell @cmd, no_output

-- Прием сообщений
SET @cmd = 'c:\kontur\actions\get_reports.cmd'
EXEC master..xp_cmdshell @cmd, no_output

-- Обработка статустных сообщений
EXEC external_ImportReports 'C:\kontur\Reports'

-- Прием сообщений
SET @cmd = 'c:\kontur\actions\get_inbox.cmd'
EXEC master..xp_cmdshell @cmd, no_output

-- Обработка входящих данных
EXEC external_ImportORDRSP 'C:\kontur\Inbox'
return
EXEC external_ImportDESADV 'C:\kontur\Inbox'

-- Предача на фтп
SET @cmd = 'c:\kontur\actions\put_outbox.cmd'
EXEC master..xp_cmdshell @cmd, no_output

-- Тут еще курсор по приходам
SET @messageId = NULL

SELECT TOP 1 @messageId = messageId 
FROM KonturEDI.dbo.edi_Messages M
JOIN InputDocuments I ON I.idoc_ID = M.doc_ID
WHERE doc_Type = 'input' AND IsProcessed = 0 AND idoc_idst_ID = 1

IF @messageId IS NOT NULL
    EXEC external_ExportRECADV @messageId,  'C:\kontur\Outbox'