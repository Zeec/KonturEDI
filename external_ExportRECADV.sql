SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_ExportRECADV', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ExportRECADV
GO

CREATE PROCEDURE dbo.external_ExportRECADV 
WITH EXECUTE AS OWNER
AS
/*
<eDIMessage id="messageId" creationDateTime="creationDateTime">  <!--������������� ���������, ����� ���������-->
  <!-- ������ ��������� ��������� -->
  <interchangeHeader>
    <sender>SenderGLN</sender>    <!--GLN ����������� ���������-->
    <recipient>RecipientGLN</recipient>   <!--GLN ���������� ���������-->
    <documentType>RECADV</documentType>  <!--��� ���������-->
    <creationDateTime>creationDateTimeT00:00:00.000Z</creationDateTime> <!--���� � ����� �������� ���������-->
    <creationDateTimeBySender>creationDateTimeBySenderT00:00:00.000Z</creationDateTimeBySender> <!--���� � ����� �������� ��������� ��������-->
    <isTest>1</isTest>    <!--�������� ����-->
  </interchangeHeader>
  <!-- ����� ��������� ��������� -->
  <receivingAdvice number="recadvNumber" date="recadvDate">  <!--����� ������, ���� ����������� � ������-->
    <originOrder number="ordersNumber" date="ordersDate" />      <!--����� ������, ���� ������-->
    <contractIdentificator number="contractNumber" date="contractDate" />
    <!--����� ��������/ ���������, ���� ��������/ ���������-->
    <despatchIdentificator number="DespatchAdviceNumber" date="DespatchDate0000" />
    <!--����� ���������, ���� ���������-->
    <blanketOrderIdentificator number="BlanketOrdersNumber" />     <!--����� ����� �������-->
    <!-- ������ ����� ������ � ���������� -->
    <seller/>
    <buyer/>
    <invoicee/>
    <deliveryInfo/>
    <!-- ����� ����� ������ � ���������������� � ��������������� -->
    <!-- ������ ����� � ������� � ������ -->
    <lineItems>
      <lineItem>
        <gtin>GTIN</gtin>       <!--GTIN ������-->
        <internalBuyerCode>BuyerProductId</internalBuyerCode>     <!--���������� ��� ����������� �����������-->
        <internalSupplierCode>SupplierProductId</internalSupplierCode>
        <!--������� ������ (��� ������ ����������� ���������)-->
        <orderLineNumber>orderLineNumber</orderLineNumber>     <!--����� ������� � ������-->
        <typeOfUnit>R�</typeOfUnit>   <!--������� ���������� ����, ���� ��� �� ����, �� ������ ���-->
        <description>Name</description>         <!--������������ ������-->
        <comment>LineItemComment</comment>          <!--����������� � �������� �������-->
        <orderedQuantity unitOfMeasure="MeasurementUnitCode">OrderedQuantity</orderedQuantity>
        <!--���������� ����������-->
        <despatchedQuantity unitOfMeasure="MeasurementUnitCode">DespatchQuantity</despatchedQuantity>
        <!--����������� ����������� ����������-->
        <deliveredQuantity unitOfMeasure="MeasurementUnitCode">DesadvQuantity</deliveredQuantity>
        <!--������������ ���������� ����������-->
        <acceptedQuantity unitOfMeasure="MeasurementUnitCode">RecadvQuantity</acceptedQuantity>
        <!--�������� ����������-->
        <onePlaceQuantity unitOfMeasure="MeasurementUnitCode">OnePlaceQuantity</onePlaceQuantity>
        <!-- ���������� � ����� ����� (���� �.�. ������ ����� ���-��) -->
        <netPrice>Price</netPrice>     <!--���� ������� ������ ��� ���-->
        <netPriceWithVAT>PriceWithVAT</netPriceWithVAT>     <!--���� ������� ������ � ���-->
        <netAmount>PriceSummary</netAmount>      <!--����� �� ������� ��� ���-->
        <exciseDuty>exciseSum</exciseDuty>       <!--����� ������-->
        <vATRate>VATRate</vATRate>  <!--������ ��� (NOT_APPLICABLE - ��� ���, 0 - 0%, 10 - 10%, 18 - 18%)-->
        <vATAmount>vatSum</vATAmount>  <!--����� ���-->
        <amount>PriceSummaryWithVAT</amount>       <!--����� �� ������� � ���-->
        <countryOfOriginISOCode>CountriesOfOriginCode</countryOfOriginISOCode>     <!--��� ������ ������������-->
        <customsDeclarationNumber>CustomDeclarationNumbers</customsDeclarationNumber>
        <!--����� ���������� ����������-->
      </lineItem>
      <!-- ������ ����������� �������� ������� ������ ���� � ��������� ���� <lineItem> -->

      <totalSumExcludingTaxes>RecadvTotal</totalSumExcludingTaxes>      <!--����� ��� ���-->
      <totalAmount>RecadvTotalWithVAT</totalAmount>
      <!--����� ����� �� �������, �� ������� ����������� ��� (125/86)-->
      <totalVATAmount>RecadvTotalVAT</totalVATAmount>    <!--����� ���, �������� ����� �� orders/ordrsp-->
    </lineItems>
  </receivingAdvice>
</eDIMessage>
*/

-- ������� ���������
DECLARE @TRANCOUNT INT
DECLARE @File SYSNAME, @R NVARCHAR(MAX)
DECLARE  @message_Id UNIQUEIDENTIFIER,
  @doc_ID UNIQUEIDENTIFIER

DECLARE @LineItem XML, @LineItems XML
DECLARE
     @nttp_ID_idoc_name UNIQUEIDENTIFIER 
    ,@nttp_ID_idoc_date UNIQUEIDENTIFIER 

-- ������� ���������
DECLARE @nttp_ID_Measure UNIQUEIDENTIFIER
DECLARE @Measure_Default NVARCHAR(10) 
DECLARE @OutboxPath NVARCHAR(MAX)
DECLARE @Currency_Default NVARCHAR(10)

SELECT @OutboxPath = OutboxPath, 
    @nttp_ID_Measure = nttp_ID_Measure, @nttp_ID_idoc_name = nttp_ID_idoc_name, @nttp_ID_idoc_date = nttp_ID_idoc_date,
    @Measure_Default = Measure_Default, @Currency_Default = Currency_Default
FROM  KonturEDI.dbo.edi_Settings


--����� �� ������
DECLARE ct CURSOR FOR
	SELECT TOP 1 message_Id, doc_ID 
	FROM KonturEDI.dbo.edi_Messages M 
	JOIN InputDocuments I ON I.idoc_ID = M.doc_ID 
	WHERE doc_Type = 'input' AND IsProcessed = 0 AND idoc_idst_ID = 1

OPEN ct
FETCH ct INTO @message_ID, @doc_ID

WHILE @@FETCH_STATUS = 0 BEGIN 

	SET @TRANCOUNT = @@TRANCOUNT
	IF @TRANCOUNT = 0
		BEGIN TRAN external_ExportRECADV
	ELSE
		SAVE TRAN external_ExportRECADV

    -- ������������ ������-������� ORDERS
    BEGIN TRY

		-- �������� ������
		SET @LineItem = 
			(SELECT 
				 CONVERT(NVARCHAR(MAX), N.note_Value) N'gtin' -- GTIN ������
				,P.pitm_ID N'internalBuyerCode' --���������� ��� ����������� �����������
				,I.idit_Article N'internalSupplierCode' --������� ������ (��� ������ ����������� ���������)
				,I.idit_Order N'lineNumber' --���������� ����� ������
				,NULL N'typeOfUnit' --������� ���������� ����, ���� ��� �� ����, �� ������ ���
				,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(I.idit_ItemName, P.pitm_Name), 25) N'description' --�������� ������
				,dbo.f_MultiLanguageStringToStringByLanguage1(I.idit_Comment, 25) N'comment' --����������� � �������� �������
				-- ,dbo.f_MultiLanguageStringToStringByLanguage1(MI.meit_Name, 25) N'requestedQuantity/@unitOfMeasure' -- MeasurementUnitCode
				,ISNULL(CONVERT(NVARCHAR(MAX), NM.note_Value), @Measure_Default) N'requestedQuantity/@unitOfMeasure' -- MeasurementUnitCode
				,I.idit_Volume N'requestedQuantity/text()' --���������� ����������
				,NULL N'onePlaceQuantity/@unitOfMeasure' -- MeasurementUnitCode
				,NULL N'onePlaceQuantity/text()' -- ���������� � ����� ����� (���� �.�. ������ ����� ���-��)
			--	,'Direct' N'flowType' --��� ��������, ����� ��������� ��������: Stock - ���� �� ��, Transit - ������� � �������, Direct - ������ ��������, Fresh - ������ ��������
				,I.idit_Price N'netPrice' --���� ������ ��� ���
				,I.idit_Price+I.idit_Price*I.idit_VAT N'netPriceWithVAT' --���� ������ � ���
				,I.idit_Sum N'netAmount' --����� �� ������� ��� ���
				--,NULL N'exciseDuty' --����� ������
				,I.idit_VAT*100 N'VATRate' --������ ��� (NOT_APPLICABLE - ��� ���, 0 - 0%, 10 - 10%, 18 - 18%)
				,I.idit_SumVAT N'VATAmount' --����� ��� �� �������
				,I.idit_Sum+I.idit_SumVAT N'amount' --����� �� ������� � ���
			FROM KonturEDI.dbo.edi_Messages M
			JOIN InputDocumentItems       I ON I.idit_idoc_ID = M.doc_ID
			JOIN ProductItems             P ON P.pitm_ID = I.idit_pitm_ID
			JOIN MeasureItems            MI ON MI.meit_ID = idit_meit_ID
			LEFT JOIN Notes              NM ON NM.note_obj_ID = idit_meit_ID AND note_nttp_ID = @nttp_ID_Measure
			LEFT JOIN Notes               N ON N.note_obj_ID = P.pitm_ID
			WHERE M.message_Id = @message_Id  
			FOR XML PATH(N'lineItem'), TYPE)

		SET @LineItems = (
		SELECT
				'RUB' N'currencyISOCode' --��� ������ (�� ��������� �����)
			,@LineItem
			,SUM(strqti_Sum) N'totalSumExcludingTaxes' -- ����� ������ ��� ���
			,SUM(strqti_SumVAT) N'totalVATAmount' -- ����� ��� �� ������
			,SUM(strqti_Sum + strqti_SumVAT) N'totalAmount' -- --����� ����� ������ ����� � ���
		FROM KonturEDI.dbo.edi_Messages M
		JOIN tp_StoreRequests           R ON R.strqt_ID = M.doc_ID
		JOIN tp_StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
		WHERE M.message_ID = @message_Id
		FOR XML PATH(N'lineItems'), TYPE)

		-- seller
		DECLARE 
			 @part_ID_Out UNIQUEIDENTIFIER
			,@part_ID_Self UNIQUEIDENTIFIER
			,@addr_ID UNIQUEIDENTIFIER

		DECLARE @seller XML, @buyer XML, @invoicee XML, @deliveryInfo XML
		DECLARE @idoc_Date DATETIME

		SELECT TOP 1 
			 -- ���������
			 @part_ID_Out = R.idoc_part_ID
			 -- ���� �����������
			,@part_ID_Self = G.stgr_part_ID
			-- ����� ������
			,@addr_ID = addr_ID
			,@idoc_Date = idoc_Date
		FROM KonturEDI.dbo.edi_Messages M
		JOIN InputDocuments           R ON R.idoc_ID = M.doc_ID
		-- ������
		JOIN Stores      S ON S.stor_ID = idoc_stor_ID
		JOIN StoreGroups G ON G.stgr_ID = S.stor_stgr_ID
		-- ���� �����������
		-- LEFT JOIN tp_Partners SelfParnter ON SelfParnter.part_ID = stgr_part_ID
		-- ����� ������
		LEFT JOIN Addresses               ON addr_obj_ID         = S.stor_loc_ID
		WHERE M.message_Id = @message_Id

		EXEC dbo.external_GetSellerXML @part_ID_Out, @seller OUTPUT
		EXEC dbo.external_GetBuyerXML @part_ID_Self, @addr_ID, @buyer OUTPUT
		--EXEC external_GetInvoiceeXML @part_ID, @invoicee OUTPUT
		EXEC external_GetDeliveryInfoXML @part_ID_Out, NULL, @part_ID_Self, @addr_ID, @idoc_Date, @deliveryInfo OUTPUT

		DECLARE @senderGLN NVARCHAR(MAX), @buyerGLN NVARCHAR(MAX)
		SET @senderGLN = @seller.value('(/seller/gln)[1]', 'NVARCHAR(MAX)')
		SET @buyerGLN = @buyer.value('(/buyer/gln)[1]', 'NVARCHAR(MAX)')


		DECLARE @Result NVARCHAR(MAX)
		SET @Result=
		(SELECT
			message_Id N'id', 
            message_creationDateTime N'creationDateTime',
			(
				SELECT
					@buyerGLN N'sender',
					@senderGLN N'recipient',
					'RECADV' N'documentType'
					,message_creationDateTime N'creationDateTime'
					,message_creationDateTime N'creationDateTimeBySender'
					,NULL 'IsTest'
				FOR XML PATH(N'interchangeHeader'), TYPE
			)
			,(
			    SELECT 
				   --����� ���������-������, ���� ���������-������, ������ ��������� - ������������/���������/�����/������, ����� ����������� ��� ������-������
				    I.idoc_Name N'@number'
				   ,CONVERT(NVARCHAR(MAX), CONVERT(DATE, I.idoc_Date), 127) N'@date'

				   -- ����� ������, ���� ������
				   ,R.strqt_Name N'originOrder/@number'
				   ,CONVERT(NVARCHAR(MAX), CONVERT(DATE, R.strqt_Date), 127) N'originOrder/@date'

				   -- �������
				   ,C.pcntr_Name N'contractIdentificator/@number'
				   ,CONVERT(NVARCHAR(MAX), CONVERT(DATE, C.pcntr_DateBegin), 127) N'contractIdentificator/@date'
				   
				   --����� ���������, ���� ���������
				   ,NN.note_Value N'despatchIdentificator/@number'
				   ,CONVERT(NVARCHAR(MAX), ND.note_Value, 127) N'despatchIdentificator/@date'
				   
				   ,@seller
				   ,@buyer
				   ,@invoicee
				   ,@deliveryInfo
				   ,@lineItems

				FOR XML PATH(N'receivingAdvice'), TYPE
            
			)

        FROM KonturEDI.dbo.edi_Messages M
		JOIN InputDocuments             I ON I.idoc_ID  = M.doc_ID
		JOIN StoreRequests              R ON R.strqt_ID = M.doc_ID_original
		LEFT JOIN PartnerContracts      C ON C.pcntr_part_ID = I.idoc_part_ID
		LEFT JOIN Notes                NN ON NN.note_obj_ID = I.idoc_ID AND NN.note_nttp_ID = @nttp_ID_idoc_name
		LEFT JOIN Notes                ND ON ND.note_obj_ID = I.idoc_ID AND ND.note_nttp_ID = @nttp_ID_idoc_date
		WHERE M.message_Id = @message_Id
		FOR XML RAW(N'eDIMessage'))

		SET @R = N'<?xml version ="1.0" encoding ="utf-8"?>'+@Result
		SET @File = @OutboxPath+'RECADV_'+CAST(@message_Id AS NVARCHAR(MAX))+'.xml'
		EXEC dbo.external_SaveToFile @File, @R

		-- ������ ���������
		UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 1, message_FileName = @File WHERE message_Id = @message_ID
		-- �������������� ������ ���������
		EXEC external_UpdateDocStatus @doc_ID, 'input', '���������� ���������' --, current_timestamp
		-- ���
		INSERT INTO KonturEDI.dbo.edi_MessagesLog (log_XML, log_Text, message_ID, doc_ID)
		VALUES (@Result, '���������� ������������� �������', @message_ID, @doc_ID)

 		IF @TRANCOUNT = 0
  			COMMIT TRAN
	END TRY
	BEGIN CATCH
		-- ������ �������� �����, ����� ������ ������
		IF @@TRANCOUNT > 0
			IF (XACT_STATE()) = -1
				ROLLBACK
			ELSE
				ROLLBACK TRAN external_ExportRECADV
		IF @TRANCOUNT > @@TRANCOUNT
			BEGIN TRAN

	    -- ������ � �������, ���������� �����
		INSERT INTO KonturEDI.dbo.edi_Errors (ProcedureName, ErrorNumber, ErrorMessage)
	    SELECT 'ExportRECADV', ERROR_NUMBER(), ERROR_MESSAGE()
	    -- EXEC tpsys_ReraiseError
	END CATCH

    FETCH ct INTO @message_ID, @doc_ID
END

CLOSE ct
DEALLOCATE ct

