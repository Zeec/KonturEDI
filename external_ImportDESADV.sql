SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_ImportDESADV', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ImportDESADV
GO

CREATE PROCEDURE dbo.external_ImportDESADV (
  @Path NVARCHAR(255) = NULL)
WITH EXECUTE AS OWNER
AS
-- DESADV (УВЕДОМЛЕНИЕ ОБ ОТГРУЗКЕ)
DECLARE @doc_ID UNIQUEIDENTIFIER, @doc_Type NVARCHAR(100), @message_ID UNIQUEIDENTIFIER

DECLARE @fname NVARCHAR(255), @full_fname NVARCHAR(255),  @Text NVARCHAR(255), @xml xml, @sql NVARCHAR(MAX), @cmd NVARCHAR(255), @R INT
DECLARE @t TABLE (fname NVARCHAR(255), d INT, f INT)
DECLARE @TRANCOUNT INT

DECLARE @Result_XML XML, @Result_Text NVARCHAR(MAX), @FileName SYSNAME
DECLARE @despatchAdvice_number NVARCHAR(MAX), @despatchAdvice_date DATETIME
		DECLARE 
			@idoc_Name NVARCHAR(MAX)
			,@idoc_Date DATETIME 


DECLARE @OutboxPath NVARCHAR(255), @InboxPath NVARCHAR(255)
SELECT @OutboxPath = OutboxPath, @InboxPath = InboxPath FROM KonturEDI.dbo.edi_Settings

-- получаем список файлов для закачки (заказы)
INSERT INTO @t (fname, d, f) EXEC xp_dirtree @InboxPath, 1, 1

-- идем по списку
DECLARE ct CURSOR FOR
  SELECT fname, @InboxPath+'\'+fname AS full_fname FROM @t WHERE f=1 AND fname LIKE 'DESADV%'

OPEN ct
FETCH ct INTO @fname, @full_fname

WHILE @@FETCH_STATUS = 0 BEGIN
  
  IF OBJECT_ID('tempdb..#Messages') IS NOT NULL 
    DROP TABLE #Messages 

  SET @xml = NULL
  SET @SQL = 'SELECT @xml = CAST(x.data as XML) FROM OPENROWSET(BULK '+QUOTENAME(@full_fname, CHAR(39))+' , SINGLE_BLOB) AS x(data)'
  EXEC sp_executesql @SQL, N'@xml xml out', @xml = @xml OUT
 
  SET @TRANCOUNT = @@TRANCOUNT
  IF @TRANCOUNT = 0
	BEGIN TRAN external_ImportDESADV
  ELSE
	SAVE TRAN external_ImportDESADV

  BEGIN TRY
	-- Сообщение DESADV
    SELECT 
	  n.value('@id', 'NVARCHAR(MAX)') AS 'msgId',
	  n.value('interchangeHeader[1]/sender[1]', 'NVARCHAR(MAX)') AS 'senderGLN',
	  n.value('interchangeHeader[1]/recipient[1]', 'NVARCHAR(MAX)') AS 'recipientGLN', 
	  n.value('interchangeHeader[1]/documentType[1]', 'NVARCHAR(MAX)') AS 'documentType', 
	  n.value('despatchAdvice[1]/@number', 'NVARCHAR(MAX)') AS 'msg_number',
	  n.value('despatchAdvice[1]/@date', 'DATETIME') AS 'msg_date',
	  n.value('despatchAdvice[1]/@status', 'NVARCHAR(MAX)') AS 'msg_status',
      n.value('despatchAdvice[1]/originOrder[1]/@number', 'NVARCHAR(MAX)') AS 'originOrder_number',
      n.value('despatchAdvice[1]/originOrder[1]/@date', 'NVARCHAR(MAX)') AS 'originOrder_date'
    INTO #Messages
    FROM @xml.nodes('/eDIMessage') t(n)

	-- Надо бы проверку

    -- Accepted/Rejected/Changed
	BEGIN
	
	  SELECT @despatchAdvice_number = msg_number, @despatchAdvice_date = msg_date FROM #Messages
	  
	  -- Меняем статус на "Подтверждена"
	  SELECT @message_ID = M.message_ID, @doc_ID = doc_ID, @doc_Type = doc_Type
	  FROM #Messages T
	  JOIN KonturEDI.dbo.edi_Messages M ON M.doc_Name = originOrder_number AND CONVERT(DATE, M.doc_Date) = CONVERT(DATE, originOrder_date)
	  WHERE M.doc_Type = 'request'

		IF @doc_ID IS NULL BEGIN 
			SELECT @Text = 'Не найден документ N'+originOrder_number+' от '+originOrder_date FROM #Messages
			EXEC tpsys_RaiseError 50001, @Text
		END

	  -- Лог
	  INSERT INTO KonturEDI.dbo.edi_MessagesLog (log_XML, log_Text, message_ID, doc_ID) 
  	  VALUES (@xml, 'Получено уведомление об отгрузке', @message_ID, @doc_ID)

	  -- Приходная накладная
	  EXEC external_CreateInputFromRequest @doc_ID, @despatchAdvice_number, @despatchAdvice_date, @idoc_Name OUTPUT, @idoc_Date OUTPUT
	  SET @idoc_Name = 'Создана приходная накладная N'+@idoc_Name+' дата'+CONVERT(NVARCHAR(50), @idoc_Date, 104)
	  -- Статус
	  EXEC external_UpdateDocStatus @doc_ID, @doc_Type, @idoc_Name
	  
	  EXEC external_ExportStatusReport @message_ID, @doc_ID, @OutboxPath, @fname, 'Ok', 'Сообщение доставлено'
	END

    /*SELECT TOP 1 @messageId = messageId, @Text = dateTime + ' ' + description FROM #Messages
    SELECT @doc_ID = doc_ID FROM KonturEDI.dbo.edi_Messages WHERE @messageId = messageId

	INSERT INTO Notes (note_ID, note_nttp_ID, note_Item_ID, note_obj_ID, note_tpsyso_ID, note_Date, note_Value)
    VALUES (NEWID(), '7A89CB1E-8976-0144-9A26-15D6246CB826',@doc_ID, @doc_ID, 'FB5D0433-AEB2-D143-B93C-CC91779430B1', GETDATE(), @Text)

	UPDATE KonturEDI.dbo.edi_Messages 
	SET IsProcessed = 1
	WHERE messageId = @messageId

	INSERT INTO KonturEDI.dbo.edi_MessagesLog (messageId, textLog)
	VALUES (@messageId, @xml)

*/
	
	--SELECT @Result_XML
	--SET @Result_Text = N'<?xml  version ="1.0"  encoding ="utf-8"?>' + CONVERT(NVARCHAR(MAX), @Result_XML)
    --EXEC dbo.external_SaveToFile @FileName, @Result_Text

    SET @cmd = 'DEL /f /q "'+ @full_fname+'"'
    EXEC @R = master..xp_cmdshell @cmd 

 	IF @TRANCOUNT = 0 
	  COMMIT TRAN
  END TRY
  BEGIN CATCH
    -- Ошибка загрузки файла, пишем ошибку приема
	IF @@TRANCOUNT > 0
	  IF (XACT_STATE()) = -1
	    ROLLBACK
	  ELSE
	    ROLLBACK TRAN external_ImportDESADV
	IF @TRANCOUNT > @@TRANCOUNT
	  BEGIN TRAN

	    -- Ошибки в таблицу, обработаем потом
		INSERT INTO KonturEDI.dbo.edi_Errors (ProcedureName, ErrorNumber, ErrorMessage)
	    SELECT 'ImportDESADV', ERROR_NUMBER(), ERROR_MESSAGE()
	    -- EXEC tpsys_ReraiseError
    END CATCH
  
    IF OBJECT_ID('tempdb..#Messages') IS NOT NULL 
        DROP TABLE #Messages 
 
    FETCH ct INTO @fname, @full_fname
END

CLOSE ct
DEALLOCATE ct

GO
