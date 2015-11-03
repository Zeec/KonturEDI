SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_ImportDESADV', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ImportDESADV
GO

CREATE PROCEDURE dbo.external_ImportDESADV (
  @Path NVARCHAR(255))
WITH EXECUTE AS OWNER
AS
-- DESADV (УВЕДОМЛЕНИЕ ОБ ОТГРУЗКЕ)
DECLARE @doc_ID UNIQUEIDENTIFIER, @doc_Type NVARCHAR(100), @messageId UNIQUEIDENTIFIER

DECLARE @fname NVARCHAR(255), @full_fname NVARCHAR(255),  @Text NVARCHAR(255), @xml xml, @sql NVARCHAR(MAX), @cmd NVARCHAR(255), @R INT
DECLARE @t TABLE (fname NVARCHAR(255), d INT, f INT)
DECLARE @TRANCOUNT INT

DECLARE @Result_XML XML, @Result_Text NVARCHAR(MAX), @FileName SYSNAME
DECLARE @despatchAdvice_number NVARCHAR(MAX), @despatchAdvice_date DATETIME

-- получаем список файлов для закачки (заказы)
INSERT INTO @t (fname, d, f) EXEC xp_dirtree @Path, 1, 1

-- идем по списку
DECLARE ct CURSOR FOR
  SELECT fname, @Path+'\'+fname AS full_fname FROM @t WHERE f=1 AND fname LIKE 'DESADV%'

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
	  n.value('@id', 'NVARCHAR(MAX)') AS 'messageId',
	  n.value('interchangeHeader[1]/sender[1]', 'NVARCHAR(MAX)') AS 'senderGLN',
	  n.value('interchangeHeader[1]/recipient[1]', 'NVARCHAR(MAX)') AS 'recipientGLN', 
	  n.value('interchangeHeader[1]/documentType[1]', 'NVARCHAR(MAX)') AS 'documentType', 
	  n.value('despatchAdvice[1]/@number', 'NVARCHAR(MAX)') AS 'msgdoc_number',
	  n.value('despatchAdvice[1]/@date', 'DATETIME') AS 'msgdoc_date',
	  n.value('despatchAdvice[1]/@status', 'NVARCHAR(MAX)') AS 'msgdoc_status',
      n.value('despatchAdvice[1]/originOrder[1]/@number', 'NVARCHAR(MAX)') AS 'originOrder_number',
      n.value('despatchAdvice[1]/originOrder[1]/@date', 'NVARCHAR(MAX)') AS 'originOrder_date'
    INTO #Messages
    FROM @xml.nodes('/eDIMessage') t(n)

	-- Надо бы проверку

    -- Accepted/Rejected/Changed
	BEGIN
	  
	  SELECT @despatchAdvice_number = doc_number, @despatchAdvice_date = doc_date FROM #Messages
	  
	  -- Меняем статус на "Подтверждена"
	  SELECT @doc_ID = doc_ID, @doc_Type = doc_Type
	  FROM #Messages T
	  JOIN KonturEDI.dbo.edi_Messages M ON M.doc_Name = originOrder_number AND CONVERT(DATE, M.doc_Date) = CONVERT(DATE, originOrder_date)
	  WHERE M.doc_Type = 'request'

	  SELECT *
	  FROM #Messages T
	  JOIN KonturEDI.dbo.edi_Messages M ON M.doc_Name = originOrder_number AND CONVERT(DATE, M.doc_Date) = CONVERT(DATE, originOrder_date)
	  WHERE M.doc_Type = 'request'

	  -- Приходная накладная
	  EXEC external_CreateInputFromRequest @doc_ID, @despatchAdvice_number, @despatchAdvice_date 
      -- Статус
	  EXEC external_UpdateDocStatus @doc_ID, @doc_Type, 'Создана приходная накладная'
	  
	  /*SET @Result_XML = (
	    SELECT 
		   GETDATE() N'reportDateTime'
		  ,senderGLN N'reportRecipient'
		  ,messageId N'reportItem/messageId'
		  ,messageId N'reportItem/documentId'
		  ,senderGLN N'reportItem/messageSender'
		  ,recipientGLN N'reportItem/messageRecepient'
		  ,'DESADV' N'reportItem/documentType'
		  ,despatchAdvice_number N'reportItem/documentNumber'
		  ,despatchAdvice_date N'reportItem/documentDate'
		  ,GETDATE() N'reportItem/statusItem/dateTime'
		  ,'Checking' N'reportItem/statusItem/stage'
		  ,'Ok' N'reportItem/statusItem/state'
		  ,'Сообщение доставлено' N'reportItem/statusItem/description'
        FROM #Messages
		FOR XML PATH(N'statusReport'), TYPE
	  )
  	  
	  SET @FileName = 'C:\kontur\outbox\Ok_'+REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 120), ':', ''), '-', ''), ' ', '')+'_'+CAST(@fname AS NVARCHAR(MAX))+'.xml'*/

	  EXEC external_ExportStatusReport 'C:\kontur\outbox\', @fname, 'Ok', 'Сообщение доставлено'
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

	EXEC tpsys_ReraiseError
  END CATCH
  
  IF OBJECT_ID('tempdb..#Messages') IS NOT NULL 
    DROP TABLE #Messages 
 
  FETCH ct INTO @fname, @full_fname
END

CLOSE ct
DEALLOCATE ct

GO
