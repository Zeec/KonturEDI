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
/*
    1. Статусные
	2. Инбокс
	3. Аутбокс
*/

DECLARE @cmd VARCHAR(200)

-- Ошибки 
IF OBJECT_ID(N'tempdb..#EDIErrors') IS NOT NULL DROP TABLE #EDIErrors
CREATE TABLE #EDIErrors (ProcedureName NVARCHAR(100), ErrorNumber INT, ErrorMessage NVARCHAR(2047))

-- Настройки
IF OBJECT_ID(N'tempdb..#EDISettings') IS NOT NULL DROP TABLE #EDISettings
CREATE TABLE #EDISettings (InboxPath NVARCHAR(MAX), OutboxPath NVARCHAR(MAX), ReportsPath NVARCHAR(MAX), 
    ActionsPath NVARCHAR(MAX), nttp_ID_GLN UNIQUEIDENTIFIER, nttp_ID_GTIN UNIQUEIDENTIFIER, nttp_ID_idoc_Name UNIQUEIDENTIFIER,
	nttp_ID_idoc_Date UNIQUEIDENTIFIER, nttp_ID_Status UNIQUEIDENTIFIER, nttp_ID_Log UNIQUEIDENTIFIER, nttp_ID_Measure UNIQUEIDENTIFIER,
	ShowAdditionalInfo INT)

INSERT INTO #EDISettings (InboxPath, OutboxPath, ReportsPath, ActionsPath, nttp_ID_GLN, nttp_ID_GTIN, nttp_ID_idoc_Name, 
	nttp_ID_idoc_Date, nttp_ID_Status, nttp_ID_Log, nttp_ID_Measure, ShowAdditionalInfo)
SELECT TOP 1 InboxPath, OutboxPath, ReportsPath, ActionsPath, nttp_ID_GLN, nttp_ID_GTIN, nttp_ID_idoc_Name, 
	nttp_ID_idoc_Date, nttp_ID_Status, nttp_ID_Log, nttp_ID_Measure, 0
FROM KonturEDI.dbo.edi_Settings

-- Настройки
DECLARE
     @InboxPath NVARCHAR(MAX)
	,@OutboxPath NVARCHAR(MAX)
	
	,@ActionsPath NVARCHAR(MAX)

SELECT @InboxPath = InboxPath, @OutboxPath = OutboxPath, @ActionsPath = ActionsPath
FROM #EDISettings

DECLARE
    
     @nttp_ID_GLN UNIQUEIDENTIFIER
	-- GLN отправителя сообщения
    ,@part_ID_Sender UNIQUEIDENTIFIER = 'E8687459-FC7F-474D-B15A-37A0E9EBC125'
DECLARE @seller XML
EXEC dbo.external_GetSellerXML @part_ID_Sender, @seller OUTPUT
select @seller
return

-- EXEC external_ExportPARTIN
--------------------------------------------------------------------------------
-- Прием статустных сообщений
SET @cmd = @ActionsPath+'get_reports.cmd'
EXEC master..xp_cmdshell @cmd, no_output

-- Обработка статустных сообщений
EXEC external_ImportReports 
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Прием входящих данных
SET @cmd = @ActionsPath+'get_inbox.cmd'
EXEC master..xp_cmdshell @cmd, no_output

-- Обработка входящих данных
EXEC external_ImportORDRSP @InboxPath
EXEC external_ImportDESADV @InboxPath

-- Предача на фтп
SET @cmd = @ActionsPath+'put_outbox.cmd'
EXEC master..xp_cmdshell @cmd, no_output
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Необработанные заявки, скорее всего перенести в триггер 
INSERT INTO KonturEDI.dbo.edi_Messages (doc_ID, doc_Name, doc_Date, doc_Type)
SELECT strqt_ID, strqt_Name, strqt_Date, 'request'
FROM tp_StoreRequests
WHERE strqt_strqtyp_ID = 12 
    AND strqt_strqtst_ID = 12
	AND strqt_ID NOT IN (SELECT doc_ID FROM KonturEDI.dbo.edi_Messages)

-- Тут курсор
/*DECLARE @messageId UNIQUEIDENTIFIER, @doc_ID UNIQUEIDENTIFIER

SELECT TOP 1 @messageId = messageId, @doc_ID = doc_ID FROM KonturEDI.dbo.edi_Messages WHERE doc_Type = 'request' AND IsProcessed = 0

IF @messageId IS NOT NULL BEGIN
  EXEC external_ExportORDERS @messageId, @doc_ID
  EXEC external_UpdateDocStatus @doc_ID, 'request', 'Отправлена' --, current_timestamp
END*/

EXEC external_ExportORDERS -- @messageId, @doc_ID

-- Необработанные приходы
SET @messageId = NULL
SELECT TOP 1 @messageId = messageId, @doc_ID = doc_ID FROM KonturEDI.dbo.edi_Messages M JOIN InputDocuments I ON I.idoc_ID = M.doc_ID WHERE doc_Type = 'input' AND IsProcessed = 0 AND idoc_idst_ID = 1
print @messageId
IF @messageId IS NOT NULL BEGIN
    EXEC external_ExportRECADV @messageId, @doc_ID,  @OutboxPath
	EXEC external_UpdateDocStatus @doc_ID, 'input', 'Отправлена' --, current_timestamp
END

-- Предача на фтп
SET @cmd = @ActionsPath+'put_outbox.cmd'
EXEC master..xp_cmdshell @cmd, no_output
--------------------------------------------------------------------------------

-- Обработка ошибок
DECLARE 
	 @ErrorNumber INT
    ,@ErrorMessage NVARCHAR(2047)

SELECT TOP 1 @ErrorNumber = ErrorNumber, @ErrorMessage = ProcedureName+' '+ErrorMessage
FROM #EDIErrors

IF @ErrorNumber IS NOT NULL 
    EXEC tpsys_RaiseError @ErrorNumber, @ErrorMessage

IF OBJECT_ID(N'tempdb..#EDIErrors') IS NOT NULL DROP TABLE #EDIErrors
IF OBJECT_ID(N'tempdb..#EDISettings') IS NOT NULL DROP TABLE #EDISettings