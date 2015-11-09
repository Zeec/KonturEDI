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
DECLARE @Measure_Default NVARCHAR(10) = 'PCE'

SELECT @nttp_ID_Measure = nttp_ID_Measure
FROM #EDISettings

--����� �� ������
DECLARE ct CURSOR FOR
    SELECT TOP 1 messageId, doc_ID 
	FROM KonturEDI.dbo.edi_Messages 
	WHERE doc_Type = 'request' AND IsProcessed = 0

OPEN ct
FETCH ct INTO @message_ID, @doc_ID

WHILE @@FETCH_STATUS = 0 BEGIN 

    SET @TRANCOUNT = @@TRANCOUNT
    IF @TRANCOUNT = 0 
	    BEGIN TRAN external_ExportORDERS
    ELSE              
	    SAVE TRAN external_ExportORDERS

    -- ������������ ������-������� ORDERS
    BEGIN TRY


		-- �������� ������
		SET @LineItem = 
		(SELECT
			 CONVERT(NVARCHAR(MAX), N.note_Value) N'gtin' -- GTIN ������
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
		--	,'Direct' N'flowType' --��� ��������, ����� ��������� ��������: Stock - ���� �� ��, Transit - ������� � �������, Direct - ������ ��������, Fresh - ������ ��������
			,I.strqti_Price N'netPrice' --���� ������ ��� ���
			,I.strqti_Price+I.strqti_Price*I.strqti_VAT N'netPriceWithVAT' --���� ������ � ���
			,I.strqti_Sum N'netAmount' --����� �� ������� ��� ���
			--,NULL N'exciseDuty' --����� ������
			,I.strqti_VAT*100 N'VATRate' --������ ��� (NOT_APPLICABLE - ��� ���, 0 - 0%, 10 - 10%, 18 - 18%)
			,I.strqti_SumVAT N'VATAmount' --����� ��� �� �������
			,I.strqti_Sum+I.strqti_SumVAT N'amount' --����� �� ������� � ���
		FROM KonturEDI.dbo.edi_Messages M
		JOIN StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
		JOIN ProductItems            P ON P.pitm_ID = I.strqti_pitm_ID
		JOIN MeasureItems            MI ON MI.meit_ID = strqti_meit_ID
		-- ������� ���������
		LEFT JOIN Notes              NM ON NM.note_obj_ID = strqti_meit_ID AND note_nttp_ID = @nttp_ID_Measure
		LEFT JOIN Notes               N ON N.note_obj_ID = P.pitm_ID
		WHERE M.messageId = @message_ID  --'AA215039-87FE-4EA6-B9B4-CAFE688864D1'
		FOR XML PATH(N'lineItem'), TYPE)

		SET @LineItems = 
			(SELECT
				 'RUB' N'currencyISOCode' --��� ������ (�� ��������� �����)
				,@LineItem
				,SUM(strqti_Sum) N'totalSumExcludingTaxes' -- ����� ������ ��� ���
				,SUM(strqti_SumVAT) N'totalVATAmount' -- ����� ��� �� ������
				,SUM(strqti_Sum + strqti_SumVAT) N'totalAmount' -- --����� ����� ������ ����� � ���
			FROM KonturEDI.dbo.edi_Messages M
			JOIN StoreRequests           R ON R.strqt_ID = M.doc_ID
			JOIN StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
			WHERE M.messageId = @message_ID
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
		WHERE M.messageId = @message_ID

		EXEC dbo.external_GetSellerXML @part_ID_Out, @seller OUTPUT
		EXEC dbo.external_GetBuyerXML @part_ID_Self, @addr_ID, @buyer OUTPUT
		--EXEC external_GetInvoiceeXML @part_ID, @invoicee OUTPUT
		EXEC external_GetDeliveryInfoXML @part_ID_Out, NULL, @part_ID_Self, @addr_ID, @strqt_DateInput, @deliveryInfo OUTPUT

		DECLARE @senderGLN NVARCHAR(MAX), @buyerGLN NVARCHAR(MAX)
		SET @senderGLN = @seller.value('(/seller/gln)[1]', 'NVARCHAR(MAX)')
		SET @buyerGLN = @buyer.value('(/buyer/gln)[1]', 'NVARCHAR(MAX)')


		SET @Result=
			(SELECT
				 messageId N'id'
				,creationDateTime N'creationDateTime'
				,(SELECT
					@buyerGLN N'sender',
					@senderGLN N'recipient',
					'ORDERS' N'documentType'
					,creationDateTime N'creationDateTime'
					,creationDateTime N'creationDateTimeBySender'
					,NULL 'IsTest'
				  FOR XML PATH(N'interchangeHeader'), TYPE)
				,(SELECT
					--����� ���������-������, ���� ���������-������, ������ ��������� - ������������/����������/�����/������, ����� ����������� ��� ������-������
				   -- R.strqt_Name N'@number'
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
				   ,@lineItems
				  FOR XML PATH(N'order'), TYPE
			)
			FROM KonturEDI.dbo.edi_Messages M
			JOIN StoreRequests              R ON R.strqt_ID = M.doc_ID
			LEFT JOIN PartnerContracts      C ON C.pcntr_part_ID = R.strqt_part_ID_Out
			WHERE M.messageId = @message_ID
			FOR XML RAW(N'eDIMessage'))

		-- ������ � ����
		SET @R = N'<?xml  version ="1.0"  encoding ="utf-8"?>'+@Result
		SET @File = 'C:\kontur\Outbox\ORDERS_'+CAST(@message_ID AS NVARCHAR(MAX))+'.xml'
		EXEC dbo.external_SaveToFile @File, @R

		EXEC external_UpdateDocStatus @doc_ID, 'request', '����������' --, current_timestamp
		-- ������ ���������
		UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 1 WHERE messageId = @message_ID
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
		INSERT INTO #EDIErrors (ProcedureName, ErrorNumber, ErrorMessage)
	    SELECT 'ExportORDERS', ERROR_NUMBER(), ERROR_MESSAGE()
	    -- EXEC tpsys_ReraiseError
	END CATCH

    FETCH ct INTO @message_ID, @doc_ID
END

CLOSE ct
DEALLOCATE ct

