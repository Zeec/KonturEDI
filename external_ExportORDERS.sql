SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'external_ExportORDERS', 'P') IS NOT NULL
  DROP PROCEDURE dbo.external_ExportORDERS
GO

CREATE PROCEDURE dbo.external_ExportORDERS 
AS
DECLARE @TRANCOUNT INT
DECLARE @LineItem XML, @LineItems XML
DECLARE @File SYSNAME, @R NVARCHAR(MAX)
DECLARE @Result NVARCHAR(MAX)
-- seller
DECLARE
     @part_ID_Out UNIQUEIDENTIFIER
	,@part_ID_Self UNIQUEIDENTIFIER
	,@addr_ID UNIQUEIDENTIFIER

DECLARE @seller XML, @buyer XML, @invoicee XML, @deliveryInfo XML
DECLARE @strqt_DateInput DATETIME
DECLARE @message_ID UNIQUEIDENTIFIER
DECLARE @doc_ID UNIQUEIDENTIFIER
-- ������� ���������
DECLARE @nttp_ID_Measure UNIQUEIDENTIFIER
DECLARE @idtp_ID_GTIN UNIQUEIDENTIFIER
DECLARE @Measure_Default NVARCHAR(10) 
DECLARE @OutboxPath NVARCHAR(MAX)
DECLARE @Currency_Default NVARCHAR(10)

SELECT 
     @OutboxPath = OutboxPath
	,@nttp_ID_Measure = nttp_ID_Measure
	,@Measure_Default = Measure_Default
	,@Currency_Default = Currency_Default
	,@idtp_ID_GTIN = idtp_ID_GTIN
FROM KonturEDI.dbo.edi_Settings

DECLARE 
     @doc_Name NVARCHAR(max)
	,@doc_Date DATETIME
	,@doc_Type NVARCHAR(max)

--����� �� ������
DECLARE ct CURSOR FOR
    SELECT message_Id, doc_ID 
	FROM KonturEDI.dbo.edi_Messages 
	WHERE doc_Type = 'request' AND IsProcessed = 0
	
	/*SELECT nEWID(), strqt_ID, strqt_Name, strqt_Date, 'request'
	FROM StoreRequests R 
	LEFT JOIN KonturEDI.dbo.edi_Messages M ON doc_ID = strqt_ID
	WHERE strqt_strqtyp_ID IN (11,12)
		AND strqt_strqtst_ID = 12 
		AND M.doc_ID IS NULL*/

OPEN ct
FETCH ct INTO @message_ID, @doc_ID --, @doc_Name, @doc_Date, @doc_Type

WHILE @@FETCH_STATUS = 0 BEGIN 

    SET @TRANCOUNT = @@TRANCOUNT
    IF @TRANCOUNT = 0 
	    BEGIN TRAN external_ExportORDERS
    ELSE              
	    SAVE TRAN external_ExportORDERS

    -- ������������ ������-������� ORDERS
    BEGIN TRY
	    --INSERT INTO KonturEDI.dbo.edi_Messages (message_ID, doc_ID, doc_Name, doc_Date, doc_Type)
		--VALUES(@message_ID, @doc_ID, @doc_Name, @doc_Date, @doc_Type)

		-- �������� ������
		SET @LineItem = 
		(SELECT
			 CASE
			     WHEN strqti_idtp_ID = @idtp_ID_GTIN THEN strqti_IdentifierCode
				 ELSE ''
			 END 'gtin'
			 -- CONVERT(NVARCHAR(MAX), N.note_Value) N'gtin' -- GTIN ������
			,P.pitm_ID N'internalBuyerCode' --���������� ��� ����������� �����������
			,I.strqti_Article N'internalSupplierCode' --������� ������ (��� ������ ����������� ���������)
			,I.strqti_Order N'lineNumber' --���������� ����� ������
			,NULL N'typeOfUnit' --������� ���������� ����, ���� ��� �� ����, �� ������ ���
			,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(I.strqti_ItemName, P.pitm_Name), 25) N'description' --�������� ������
			,dbo.f_MultiLanguageStringToStringByLanguage1(I.strqti_Comment, 25) N'comment' --����������� � �������� �������
			,ISNULL(CONVERT(NVARCHAR(MAX), NM.note_Value), @Measure_Default) N'requestedQuantity/@unitOfMeasure' -- MeasurementUnitCode
			,I.strqti_Volume N'requestedQuantity/text()' --���������� ����������
			,NULL N'onePlaceQuantity/@unitOfMeasure' -- MeasurementUnitCode
			,NULL N'onePlaceQuantity/text()' -- ���������� � ����� ����� (���� �.�. ������ ����� ���-��)
			,'Direct' N'flowType' --��� ��������, ����� ��������� ��������: Stock - ���� �� ��, Transit - ������� � �������, Direct - ������ ��������, Fresh - ������ ��������
			,I.strqti_Price N'netPrice' --���� ������ ��� ���
			,I.strqti_Price+I.strqti_Price*I.strqti_VAT N'netPriceWithVAT' --���� ������ � ���
			,I.strqti_Sum N'netAmount' --����� �� ������� ��� ���
			,NULL N'exciseDuty' --����� ������
			,ISNULL(CONVERT(NVARCHAR(MAX), FLOOR(I.strqti_VAT*100)), 'NOT_APPLICABLE') N'VATRate' --������ ��� (NOT_APPLICABLE - ��� ���, 0 - 0%, 10 - 10%, 18 - 18%)
			,I.strqti_SumVAT N'VATAmount' --����� ��� �� �������
			,I.strqti_Sum+I.strqti_SumVAT N'amount' --����� �� ������� � ���
		FROM KonturEDI.dbo.edi_Messages M
		JOIN StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
		JOIN ProductItems            P ON P.pitm_ID = I.strqti_pitm_ID
		JOIN MeasureItems            MI ON MI.meit_ID = strqti_meit_ID
		-- ������� ���������
		LEFT JOIN Notes              NM ON NM.note_obj_ID = strqti_meit_ID AND note_nttp_ID = @nttp_ID_Measure
		-- LEFT JOIN Notes               N ON N.note_obj_ID = P.pitm_ID
		WHERE M.message_Id = @message_ID 
		FOR XML PATH(N'lineItem'), TYPE)

		SET @LineItems = 
			(SELECT
				 @Currency_Default N'currencyISOCode' --��� ������ (�� ��������� �����)
				,@LineItem
				,SUM(strqti_Sum) N'totalSumExcludingTaxes' -- ����� ������ ��� ���
				,SUM(strqti_SumVAT) N'totalVATAmount' -- ����� ��� �� ������
				,SUM(strqti_Sum + strqti_SumVAT) N'totalAmount' -- --����� ����� ������ ����� � ���
			FROM KonturEDI.dbo.edi_Messages M
			JOIN StoreRequests           R ON R.strqt_ID = M.doc_ID
			JOIN StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
			WHERE M.message_Id = @message_ID
			FOR XML PATH(N'lineItems'), TYPE)

		SELECT TOP 1
			-- ���������
			@part_ID_Out = R.strqt_part_ID_Out
			-- ���� �����������
			,@part_ID_Self = G.stgr_part_ID
			-- ����� ������
			,@addr_ID = addr_ID
			,@strqt_DateInput = strqt_DateInput
		FROM KonturEDI.dbo.edi_Messages M
		JOIN StoreRequests           R ON R.strqt_ID = M.doc_ID
		-- ������
		JOIN Stores      S ON S.stor_ID = strqt_stor_ID_In
		JOIN StoreGroups G ON G.stgr_ID = S.stor_stgr_ID
		-- ���� �����������
		-- LEFT JOIN tp_Partners SelfParnter ON SelfParnter.part_ID = stgr_part_ID
		-- ����� ������
		LEFT JOIN Addresses               ON addr_obj_ID         = S.stor_loc_ID
		WHERE M.message_Id = @message_ID

		EXEC dbo.external_GetSellerXML @part_ID_Out, @seller OUTPUT
		EXEC dbo.external_GetBuyerXML @part_ID_Self, @addr_ID, @buyer OUTPUT
		--EXEC external_GetInvoiceeXML @part_ID, @invoicee OUTPUT
		EXEC external_GetDeliveryInfoXML @part_ID_Out, NULL, @part_ID_Self, @addr_ID, @strqt_DateInput, @deliveryInfo OUTPUT

		DECLARE @senderGLN NVARCHAR(MAX), @buyerGLN NVARCHAR(MAX)
		SET @senderGLN = @seller.value('(/seller/gln)[1]', 'NVARCHAR(MAX)')
		SET @buyerGLN = @buyer.value('(/buyer/gln)[1]', 'NVARCHAR(MAX)')


		SET @Result=
			(SELECT
				 message_Id N'id'
				,CONVERT(NVARCHAR(MAX), message_creationDateTime, 127) N'creationDateTime'
				,(SELECT
					@buyerGLN N'sender',
					@senderGLN N'recipient',
					'ORDERS' N'documentType'
					,CONVERT(NVARCHAR(MAX), message_creationDateTime, 127)  N'creationDateTime'
					,CONVERT(NVARCHAR(MAX), message_creationDateTime, 127)  N'creationDateTimeBySender'
					,NULL 'IsTest'
				  FOR XML PATH(N'interchangeHeader'), TYPE)
				,(SELECT
					--����� ���������-������, ���� ���������-������, ������ ��������� - ������������/���������/�����/������, ����� ����������� ��� ������-������
				    R.strqt_Name N'@number'
				   ,CONVERT(NVARCHAR(MAX), CONVERT(DATE, R.strqt_Date), 127) N'@date'
				   ,R.strqt_ID N'@id'
				   ,N'Original' N'@status'
				   ,NULL N'@revisionNumber'

				   ,NULL N'promotionDealNumber'
				   -- �������
				   ,C.pcntr_Name N'contractIdentificator/@number'
				   ,CONVERT(NVARCHAR(MAX),  CONVERT(DATE, C.pcntr_DateBegin), 127) N'contractIdentificator/@date'
				   ,@seller
				   ,@buyer
				   ,@invoicee
				   ,@deliveryInfo
				   -- ���������� � �������
				   ,CONVERT(NVARCHAR(MAX), R.strqt_Description) N'comment'
				   ,@lineItems
				  FOR XML PATH(N'order'), TYPE
			)
			FROM KonturEDI.dbo.edi_Messages M
			JOIN StoreRequests              R ON R.strqt_ID = M.doc_ID
			LEFT JOIN PartnerContracts      C ON C.pcntr_part_ID = R.strqt_part_ID_Out
			WHERE M.message_Id = @message_ID
			FOR XML RAW(N'eDIMessage'))

		-- ������ � ����
		SET @R = N'<?xml  version ="1.0"  encoding ="utf-8"?>'+@Result
		SET @File = @OutboxPath+'ORDERS_'+CAST(@message_ID AS NVARCHAR(MAX))+'.xml'
		EXEC dbo.external_SaveToFile @File, @R

		-- ������ ���������
		UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 1, message_FileName = @File WHERE message_Id = @message_ID
		-- �������������� ������ ���������
		EXEC external_UpdateDocStatus @doc_ID, 'request', '���������� ����������' --, current_timestamp
		-- ���
		INSERT INTO KonturEDI.dbo.edi_MessagesLog (log_XML, log_Text, message_ID, doc_ID)
		VALUES (@Result, '���������� ������ ����������', @message_ID, @doc_ID)

 		IF @TRANCOUNT = 0                   
  			COMMIT TRAN
	END TRY
	BEGIN CATCH
		-- ������ �������� �����, ����� ������ ������
		IF @@TRANCOUNT > 0
			IF (XACT_STATE()) = -1
				ROLLBACK
			ELSE
				ROLLBACK TRAN external_ExportORDERS
		IF @TRANCOUNT > @@TRANCOUNT
			BEGIN TRAN

	    -- ������ � �������, ���������� �����
		INSERT INTO KonturEDI.dbo.edi_Errors (ProcedureName, ErrorNumber, ErrorMessage)
	    SELECT 'ExportORDERS', ERROR_NUMBER(), ERROR_MESSAGE()
	    -- EXEC tpsys_ReraiseError
	END CATCH

    FETCH ct INTO @message_ID, @doc_ID --, @doc_Name, @doc_Date, @doc_Type
END

CLOSE ct
DEALLOCATE ct

