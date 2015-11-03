SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'external_ExportORDERS', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ExportORDERS
GO

CREATE PROCEDURE dbo.external_ExportORDERS (
     @messageId UNIQUEIDENTIFIER
	,@doc_ID UNIQUEIDENTIFIER)
AS
DECLARE @TRANCOUNT INT
DECLARE @LineItem XML, @LineItems XML


  SET @TRANCOUNT = @@TRANCOUNT
  IF @TRANCOUNT = 0
	  BEGIN TRAN external_ExportORDERS
  ELSE
	  SAVE TRAN external_ExportORDERS

-- ������������ ������-������� ORDERS
BEGIN TRY


-- �������� ������
SET @LineItem = (
SELECT 
     CONVERT(NVARCHAR(MAX), N.note_Value) N'gtin' -- GTIN ������
    ,P.pitm_ID N'internalBuyerCode' --���������� ��� ����������� �����������
	,I.strqti_Article N'internalSupplierCode' --������� ������ (��� ������ ����������� ���������)
	,I.strqti_Order N'lineNumber' --���������� ����� ������
	,NULL N'typeOfUnit' --������� ���������� ����, ���� ��� �� ����, �� ������ ���
	,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(I.strqti_ItemName, P.pitm_Name), 25) N'description' --�������� ������
	,dbo.f_MultiLanguageStringToStringByLanguage1(I.strqti_Comment, 25) N'comment' --����������� � �������� �������
	-- ,dbo.f_MultiLanguageStringToStringByLanguage1(MI.meit_Name, 25) N'requestedQuantity/@unitOfMeasure' -- MeasurementUnitCode
	,'PCE' N'requestedQuantity/@unitOfMeasure' -- MeasurementUnitCode
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
LEFT JOIN Notes      N ON N.note_obj_ID = P.pitm_ID
WHERE M.messageId = @messageId  --'AA215039-87FE-4EA6-B9B4-CAFE688864D1'
FOR XML PATH(N'lineItem'), TYPE)



SET @LineItems = (
SELECT
     'RUB' N'currencyISOCode' --��� ������ (�� ��������� �����)
	,@LineItem
    ,SUM(strqti_Sum) N'totalSumExcludingTaxes' -- ����� ������ ��� ���
	,SUM(strqti_SumVAT) N'totalVATAmount' -- ����� ��� �� ������
	,SUM(strqti_Sum + strqti_SumVAT) N'totalAmount' -- --����� ����� ������ ����� � ���
FROM KonturEDI.dbo.edi_Messages M
JOIN StoreRequests           R ON R.strqt_ID = M.doc_ID
JOIN StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
WHERE M.messageId = @messageId
FOR XML PATH(N'lineItems'), TYPE)


-- seller
DECLARE 
     @part_ID_Out UNIQUEIDENTIFIER
	,@part_ID_Self UNIQUEIDENTIFIER
	,@addr_ID UNIQUEIDENTIFIER

DECLARE @seller XML, @buyer XML, @invoicee XML, @deliveryInfo XML
DECLARE @strqt_DateInput DATETIME

SELECT TOP 1 
     -- ���������
     @part_ID_Out = R.strqt_part_ID_Out
	 -- ���� �����������
	,@part_ID_Self = G.stgr_part_ID
	-- ����� ������
	,@addr_ID = addr_ID
	,@strqt_DateInput = strqt_DateInput
FROM KonturEDI.dbo.edi_Messages M
JOIN tp_StoreRequests           R ON R.strqt_ID = M.doc_ID
-- ������
JOIN tp_Stores      S ON S.stor_ID = strqt_stor_ID_In
JOIN tp_StoreGroups G ON G.stgr_ID = S.stor_stgr_ID
-- ���� �����������
-- LEFT JOIN tp_Partners SelfParnter ON SelfParnter.part_ID = stgr_part_ID
-- ����� ������
LEFT JOIN Addresses               ON addr_obj_ID         = S.stor_loc_ID
WHERE M.messageId = @messageId

EXEC dbo.external_GetSellerXML @part_ID_Out, @seller OUTPUT
EXEC dbo.external_GetBuyerXML @part_ID_Self, @addr_ID, 0, @buyer OUTPUT
--EXEC external_GetInvoiceeXML @part_ID, @invoicee OUTPUT
EXEC external_GetDeliveryInfoXML @part_ID_Out, NULL, @part_ID_Self, @addr_ID, @strqt_DateInput, @deliveryInfo OUTPUT

DECLARE @senderGLN NVARCHAR(MAX), @buyerGLN NVARCHAR(MAX)
SET @senderGLN = @seller.value('(/seller/gln)[1]', 'NVARCHAR(MAX)')
SET @buyerGLN = @buyer.value('(/buyer/gln)[1]', 'NVARCHAR(MAX)')

--SELECT @senderGLN , @buyerGLN
-- SELECT @buyer
--return

DECLARE @Result NVARCHAR(MAX)
SET @Result=
	--N'<?xml  version ="1.0"  encoding ="utf-8"?>'+
	(
		SELECT
			messageId N'id', 
            creationDateTime N'creationDateTime',
			(
				SELECT
					@buyerGLN N'sender',
					@senderGLN N'recipient',
					'ORDERS' N'documentType'
					,creationDateTime N'creationDateTime'
					,creationDateTime N'creationDateTimeBySender'
					,NULL 'IsTest'
				FOR XML PATH(N'interchangeHeader'), TYPE
			)
			,(
			    SELECT 
				--����� ���������-������, ���� ���������-������, ������ ��������� - ������������/���������/�����/������, ����� ����������� ��� ������-������
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
		WHERE M.messageId = @messageId
		FOR XML RAW(N'EDIMessage')
	)

	DECLARE @File SYSNAME, @R NVARCHAR(MAX)

	SET @R = N'<?xml  version ="1.0"  encoding ="utf-8"?>'+@Result
	SET @File = 'C:\kontur\Outbox\ORDERS_'+CAST(@messageId AS NVARCHAR(MAX))+'.xml'
	EXEC dbo.external_SaveToFile @File, @R

	-- ������ ���������
	UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 1 WHERE messageId = @messageId
	-- ���
	INSERT INTO KonturEDI.dbo.edi_MessagesLog (log_XML, log_Text, message_ID, doc_ID) 
	VALUES (@Result, '���������� ������ ����������', @messageId, @doc_ID)

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

	EXEC tpsys_ReraiseError
END CATCH

