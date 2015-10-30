IF OBJECT_ID(N'external_SaveToFile', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_SaveToFile
GO

CREATE PROCEDURE dbo.external_SaveToFile (
	 @File		SysName
	,@Data		NVarChar(max)
	,@Encoding	SysName	= 'utf-8'
) WITH EXECUTE AS OWNER AS BEGIN
	DECLARE	 @OLEStream	Int
			,@Code		Int
			,@Method	SysName
			,@Source	SysName
			,@Descript	NVarChar(4000)
	EXEC @Code = sys.sp_OACreate 'ADODB.Stream' ,@OLEStream OUT
	IF (@Code != 0)
		SELECT	 @Method	= 'Scripting.Stream'
				,@Source	= 'sp_OACreate'
				,@Descript	= 'Ошибка создания OLE объекта'
	ELSE BEGIN
		SET @Method = 'Open';		EXEC @Code = sys.sp_OAMethod		@OLEStream ,@Method					IF (@Code != 0) GOTO Error;
		SET @Method = 'CharSet';	EXEC @Code = sys.sp_OASetProperty	@OLEStream ,@Method, @Encoding		IF (@Code != 0) GOTO Error;
		SET @Method = 'WriteText';	EXEC @Code = sys.sp_OAMethod		@OLEStream ,@Method ,NULL ,@Data	IF (@Code != 0) GOTO Error;
		SET @Method = 'SaveToFile';	EXEC @Code = sys.sp_OAMethod		@OLEStream, @Method, NULL, @File, 2	IF (@Code != 0) GOTO Error;
		SET @Method = 'Close';		EXEC @Code = sys.sp_OAMethod		@OLEStream, @Method					IF (@Code != 0) GOTO Error;
		SET @Method = NULL; GOTO Destroy;
Error:						EXEC @Code = sys.sp_OAGetErrorInfo	@OLEStream ,@Source OUT ,@Descript OUT
Destroy:					EXEC @Code = sys.sp_OADestroy		@OLEStream
	END
	-- Вывод ошибок
	IF (@Method IS NOT NULL) BEGIN
		RAISERROR('Ошибка при выполнении метода "%s" в "%s": %s',18,1,@Method,@Source,@Descript)
		RETURN	@@Error
	END
END
GO
