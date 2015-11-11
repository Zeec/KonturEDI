SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_EDIKontur', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_EDIKontur
GO

CREATE PROCEDURE dbo.external_EDIKontur  (
@TaskID UNIQUEIDENTIFIER)
WITH EXECUTE AS OWNER
AS
/*
    1. Статусные
	2. Инбокс
	3. Аутбокс
*/

DECLARE @cmd VARCHAR(200)

-- Ошибки 
--IF OBJECT_ID(N'tempdb..#EDIErrors') IS NOT NULL DROP TABLE #EDIErrors
--CREATE TABLE #EDIErrors (ProcedureName NVARCHAR(100), ErrorNumber INT, ErrorMessage NVARCHAR(2047))
TRUNCATE TABLE KonturEDI.dbo.edi_Errors

-- Настройки
IF OBJECT_ID(N'tempdb..#EDISettings') IS NOT NULL DROP TABLE #EDISettings
CREATE TABLE #EDISettings (InboxPath NVARCHAR(MAX), OutboxPath NVARCHAR(MAX), ReportsPath NVARCHAR(MAX), 
    ActionsPath NVARCHAR(MAX), nttp_ID_GLN UNIQUEIDENTIFIER, nttp_ID_GTIN UNIQUEIDENTIFIER, nttp_ID_idoc_Name UNIQUEIDENTIFIER,
	nttp_ID_idoc_Date UNIQUEIDENTIFIER, nttp_ID_Status UNIQUEIDENTIFIER, nttp_ID_Log UNIQUEIDENTIFIER, nttp_ID_Measure UNIQUEIDENTIFIER,
	ShowAdditionalInfo INT, Measure_Default NVARCHAR(10), Currency_Default NVARCHAR(10))

INSERT INTO #EDISettings (InboxPath, OutboxPath, ReportsPath, ActionsPath, nttp_ID_GLN, nttp_ID_GTIN, nttp_ID_idoc_Name, 
	nttp_ID_idoc_Date, nttp_ID_Status, nttp_ID_Log, nttp_ID_Measure, ShowAdditionalInfo, Measure_Default, Currency_Default)
SELECT TOP 1 InboxPath, OutboxPath, ReportsPath, ActionsPath, nttp_ID_GLN, nttp_ID_GTIN, nttp_ID_idoc_Name, 
	nttp_ID_idoc_Date, nttp_ID_Status, nttp_ID_Log, nttp_ID_Measure, 0, Measure_Default, Currency_Default
FROM KonturEDI.dbo.edi_Settings

-- Настройки
DECLARE
     @InboxPath NVARCHAR(MAX)
	,@OutboxPath NVARCHAR(MAX)
	
	,@ActionsPath NVARCHAR(MAX)

SELECT @InboxPath = InboxPath, @OutboxPath = OutboxPath, @ActionsPath = ActionsPath
FROM #EDISettings

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
-- Подготавливаем список заказов
EXEC external_PrepareORDERS
-- Необработанные заявки, скорее всего перенести в триггер 
EXEC external_ExportORDERS 

-- Необработанные приходы
EXEC external_ExportRECADV

-- Предача на фтп
SET @cmd = @ActionsPath+'put_outbox.cmd'
EXEC master..xp_cmdshell @cmd, no_output
--------------------------------------------------------------------------------

-- Обработка ошибок
DECLARE 
	 @ErrorNumber INT
    ,@ErrorMessage NVARCHAR(2047)

SELECT TOP 1 @ErrorNumber = ErrorNumber, @ErrorMessage = ProcedureName+' '+ErrorMessage
FROM KonturEDI.dbo.edi_Errors

--IF @ErrorNumber IS NOT NULL 
--    EXEC tpsys_RaiseError @ErrorNumber, @ErrorMessage

EXEC tpsrv_AddTaskLogError @TaskID, 5, @ErrorMessage, 0

TRUNCATE TABLE KonturEDI.dbo.edi_Errors

--IF OBJECT_ID(N'tempdb..#EDIErrors') IS NOT NULL DROP TABLE #EDIErrors
--IF OBJECT_ID(N'tempdb..#EDISettings') IS NOT NULL DROP TABLE #EDISettings