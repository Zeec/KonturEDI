IF OBJECT_ID('external_ImportReports', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ImportReports
GO

CREATE PROCEDURE dbo.external_ImportReports (
  @ReportsPath NVARCHAR(255))
WITH EXECUTE AS OWNER
AS
DECLARE @doc_ID UNIQUEIDENTIFIER, @messageId UNIQUEIDENTIFIER

DECLARE @fname NVARCHAR(255), @full_fname NVARCHAR(255),  @Text NVARCHAR(255), @xml xml, @sql NVARCHAR(MAX), @cmd NVARCHAR(255), @r INT
DECLARE @t TABLE (fname NVARCHAR(255), d INT, f INT)
DECLARE @usr_ID_Msg UNIQUEIDENTIFIER
DECLARE @TRANCOUNT INT
DECLARE @dateTime NVARCHAR(MAX), @description NVARCHAR(MAX)
-- получаем список файлов для закачки (заказы)
INSERT INTO @t (fname, d, f) EXEC xp_dirtree @ReportsPath, 1, 1

--бежим по списку
DECLARE ct CURSOR FOR
  SELECT fname, @ReportsPath+'\'+fname AS full_fname FROM @t

OPEN ct
FETCH ct INTO @fname, @full_fname

WHILE @@FETCH_STATUS = 0 BEGIN
  
  SET @xml = NULL
  SET @SQL = 'SELECT @xml = CAST(x.data as XML) FROM OPENROWSET(BULK '+QUOTENAME(@full_fname, CHAR(39))+' , SINGLE_BLOB) AS x(data)'
  
  PRINT @SQL
  EXEC sp_executesql @SQL, N'@xml xml out', @xml = @xml out
  -- PRINT CONVERT(NVARCHAR(MAX), @Xml)
 
  IF OBJECT_ID('tempdb..#Messages') IS NOT NULL DROP TABLE #Messages 
 
  SET @TRANCOUNT = @@TRANCOUNT
  IF @TRANCOUNT = 0
	BEGIN TRAN external_ImportReports
  ELSE
	SAVE TRAN external_ImportReports

  BEGIN TRY
	-- Сообщение
	-- Заменить на EXEC dbo.spXmlBulkLoad 'Z:\Path\Data.xml', 'Z:\Path\Schema.xsd'
    SELECT 
	  n.value('../messageId[1]', 'NVARCHAR(MAX)') AS 'messageId',
      n.value('dateTime[1]', 'NVARCHAR(MAX)') AS 'dateTime',
      n.value('description[1]', 'NVARCHAR(MAX)') AS 'description'
    INTO #Messages
    FROM @xml.nodes('/statusReport/reportItem/statusItem') t(n)
	
	IF @TRANCOUNT = 0 
	  COMMIT TRAN

    SELECT TOP 1 @messageId = messageId, @Text = dateTime + ' ' + description, @dateTime = dateTime, @description = description FROM #Messages
    SELECT @doc_ID = doc_ID FROM KonturEDI.dbo.edi_Messages WHERE @messageId = messageId

	--INSERT INTO Notes (note_ID, note_nttp_ID, note_Item_ID, note_obj_ID, note_tpsyso_ID, note_Date, note_Value)
    --VALUES (NEWID(), '7A89CB1E-8976-0144-9A26-15D6246CB826',@doc_ID, @doc_ID, 'FB5D0433-AEB2-D143-B93C-CC91779430B1', GETDATE(), @Text)
	EXEC external_UpdateDocStatus @doc_ID, @description, @dateTime

	UPDATE KonturEDI.dbo.edi_Messages 
	SET IsProcessed = 1
	WHERE messageId = @messageId

	INSERT INTO KonturEDI.dbo.edi_MessagesLog (messageId, textLog)
	VALUES (@messageId, @xml)

	-- ACK
    SET @cmd = 'DEL /f /q "'+ @full_fname+'"'
	--PRINT @CMD
    EXEC @R = master..xp_cmdshell @cmd --, NO_OUTPUT
	
	
  END TRY
  BEGIN CATCH
    -- Ошибка загрузки файла, пишем ошибку приема
	IF @@TRANCOUNT > 0
	  IF (XACT_STATE()) = -1
	    ROLLBACK
	  ELSE
	    ROLLBACK TRAN external_ImportReports
	IF @TRANCOUNT > @@TRANCOUNT
	  BEGIN TRAN

	-- NACK
    --SET @cmd = 'RENAME "'+ @full_fname + '" "Error - '+@fname + '"'
	--EXEC @R = master..xp_cmdshell @cmd --, NO_OUTPUT
  END CATCH
  
  IF OBJECT_ID('tempdb..#Messages') IS NOT NULL DROP TABLE #Messages 
 
  FETCH ct INTO @fname, @full_fname
END

CLOSE ct
DEALLOCATE ct

GO
