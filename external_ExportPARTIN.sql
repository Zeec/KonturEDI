SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_ExportPARTIN', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ExportPARTIN 
GO

CREATE PROCEDURE dbo.external_ExportPARTIN
WITH EXECUTE AS OWNER
AS

DECLARE
    
     @nttp_ID_GLN UNIQUEIDENTIFIER
	-- GLN отправителя сообщения
    ,@part_ID_Sender UNIQUEIDENTIFIER = 'E8687459-FC7F-474D-B15A-37A0E9EBC125'
	-- GLN получателя сообщения
	,@part_ID_Recipient UNIQUEIDENTIFIER = '46BA7DB7-0BC1-214E-B704-7ADE47283009'
	,@message_ID UNIQUEIDENTIFIER
	,@GLN_Sender NVARCHAR(MAX)
	,@GLN_Recipient NVARCHAR(MAX)

SELECT @nttp_ID_GLN = nttp_ID_GLN
FROM #EDISettings

SET @message_ID = NEWID()
INSERT INTO KonturEDI.dbo.edi_Messages (messageID, doc_Name, doc_Date, doc_Type)
VALUES (@message_ID, (SELECT ISNULL(MAX(CONVERT(INT, doc_Name)), 0)+1 FROM KonturEDI.dbo.edi_Messages WHERE doc_Type = 'partin'), GETDATE(), 'partin')



    SELECT @GLN_Sender = CONVERT(NVARCHAR(MAX), note_Value)
	FROM Partners       P
	LEFT JOIN Notes     N ON N.note_obj_ID = P.part_ID AND note_nttp_ID = @nttp_ID_GLN
    WHERE part_ID = @part_ID_Sender
  
    SELECT @GLN_Recipient = CONVERT(NVARCHAR(MAX), note_Value)
	FROM Partners       P
	LEFT JOIN Notes     N ON N.note_obj_ID = P.part_ID AND note_nttp_ID = @nttp_ID_GLN
    WHERE part_ID = @part_ID_Recipient


DECLARE @Result NVARCHAR(MAX)
SET @Result =
(SELECT
	 messageID N'id'
    ,CONVERT(NVARCHAR(MAX), creationDateTime, 127) N'creationDateTime'
	,(SELECT
         CONVERT(NVARCHAR(MAX), NS.note_Value) N'sender'
		,CONVERT(NVARCHAR(MAX), NR.note_Value) N'recipient'
		,'PARTIN' N'documentType'
		,NULL 'IsTest'
	  FOR XML PATH(N'interchangeHeader'), TYPE) 
    ,(SELECT 
	     doc_Name N'@number' 
		,CONVERT(NVARCHAR(MAX), CONVERT(DATE, creationDateTime), 127) N'@date'
        ,(SELECT 
 	 	     CONVERT(NVARCHAR(MAX), NS.note_Value) N'gln' --gln покупателя
            ,dbo.f_MultiLanguageStringToStringByLanguage1(PS.part_Name, 25) N'organization/name' 
		    ,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_INN, 25) N'organization/inn' 
		    ,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_KPP, 25) N'organization/kpp' 
		    -- российский адрес
            ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_RegionCode, 25) N'russianAddress/regionISOCode'
    	    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Area, 25) N'russianAddress/district'
			,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_City, 25) N'russianAddress/city'
			,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Street, 25) N'russianAddress/street'
			,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_House, 25) N'russianAddress/house'
			,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Apartment, 25) N'russianAddress/flat'
			,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_PostCode, 25) N'russianAddress/postalCode'
		    ,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_phone, 25) N'additionalInfo/phone' --телефон контактного лица
		    ,dbo.f_MultiLanguageStringToStringByLanguage1(PD.pepl_SecondName, 25) N'additionalInfo/nameOfCEO' --телефон контактного лица
		    ,dbo.f_MultiLanguageStringToStringByLanguage1(PA.pepl_SecondName, 25) N'additionalInfo/nameOfAccountant' --телефон контактного лица
          FOR XML PATH(N'headGLN'), TYPE)      
        ,(SELECT 
		    (SELECT 
			     CONVERT(NVARCHAR(MAX), NS.note_Value) N'gln' --gln покупателя
                ,dbo.f_MultiLanguageStringToStringByLanguage1(PS.part_Name, 25) N'organization/name' 
		        ,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_INN, 25) N'organization/inn' 
		        ,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_KPP, 25) N'organization/kpp' 
		        -- российский адрес
                ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_RegionCode, 25) N'russianAddress/regionISOCode'
    	        ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Area, 25) N'russianAddress/district'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_City, 25) N'russianAddress/city'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Street, 25) N'russianAddress/street'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_House, 25) N'russianAddress/house'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Apartment, 25) N'russianAddress/flat'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_PostCode, 25) N'russianAddress/postalCode'
		        ,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_phone, 25) N'additionalInfo/phone' --телефон контактного лица
		        ,dbo.f_MultiLanguageStringToStringByLanguage1(PD.pepl_SecondName, 25) N'additionalInfo/nameOfCEO' --телефон контактного лица
		        ,dbo.f_MultiLanguageStringToStringByLanguage1(PA.pepl_SecondName, 25) N'additionalInfo/nameOfAccountant' --телефон контактного лица
			  FOR XML PATH(N'invoicee'), TYPE)
		    ,(SELECT 
			     CONVERT(NVARCHAR(MAX), NS.note_Value) N'gln' --gln покупателя
                ,dbo.f_MultiLanguageStringToStringByLanguage1(PS.part_Name, 25) N'organization/name' 
		        ,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_INN, 25) N'organization/inn' 
		        ,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_KPP, 25) N'organization/kpp' 
		        -- российский адрес
                ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_RegionCode, 25) N'russianAddress/regionISOCode'
    	        ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Area, 25) N'russianAddress/district'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_City, 25) N'russianAddress/city'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Street, 25) N'russianAddress/street'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_House, 25) N'russianAddress/house'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_Apartment, 25) N'russianAddress/flat'
			    ,dbo.f_MultiLanguageStringToStringByLanguage1(A.addr_PostCode, 25) N'russianAddress/postalCode'
		        --,dbo.f_MultiLanguageStringToStringByLanguage1(F.firm_phone, 25) N'additionalInfo/phone' --телефон контактного лица
		        --,dbo.f_MultiLanguageStringToStringByLanguage1(PD.pepl_SecondName, 25) N'additionalInfo/nameOfCEO' --телефон контактного лица
		        --,dbo.f_MultiLanguageStringToStringByLanguage1(PA.pepl_SecondName, 25) N'additionalInfo/nameOfAccountant' --телефон контактного лица
			  FOR XML PATH(N'deliveryParty'), TYPE)
          FOR XML PATH(N'parties'), TYPE)      
      FOR XML PATH(N'partyInformation'), TYPE)
FROM KonturEDI.dbo.edi_Messages M
LEFT JOIN Partners       PS ON PS.part_ID = @part_ID_Sender
LEFT JOIN Notes          NS ON NS.note_obj_ID = PS.part_ID AND NS.note_nttp_ID = @nttp_ID_GLN
LEFT JOIN Firms           F ON F.firm_ID = PS.part_firm_ID 
LEFT JOIN Addresses       A ON A.addr_obj_ID = F.firm_ID AND addr_Type = 2 -- CASE WHEN T2.part_firm_ID IS NULL THEN 3 ELSE 2 END AdddrType  -- рабочий (ФЛ) или юридический (ЮЛ) адрес
LEFT JOIN People         PD ON PD.pepl_ID = F.firm_pepl_ID_Director 
LEFT JOIN People         PA ON PA.pepl_ID = F.firm_pepl_ID_Accountant

LEFT JOIN Partners       PR ON PR.part_ID = @part_ID_Recipient
LEFT JOIN Notes          NR ON NR.note_obj_ID = PR.part_ID AND NR.note_nttp_ID = @nttp_ID_GLN
WHERE M.messageId = @message_ID
FOR XML RAW(N'eDIMessage'))	

select CONVERT(XML, @Result	)
	
	/*    ,
	(
		SELECT
			@GLN_Sender N'sender',
			@GLN_Recipient N'recipient',
			'PARTIN' N'documentType'
			,NULL 'IsTest'
		FOR XML PATH(N'interchangeHeader'), TYPE
	),
	(SELECT 
 	'008' N'number' 
	   ,CONVERT(NVARCHAR(MAX), CONVERT(DATE, creationDateTime), 127) N'date'
	   
	,(SELECT 
 	 	 CONVERT(NVARCHAR(MAX), note_Value) N'gln' --gln поставщика
		,dbo.f_MultiLanguageStringToStringByLanguage1(part_Name, 25) N'organization/name' --наименование поставщика для ЮЛ	
		,dbo.f_MultiLanguageStringToStringByLanguage1(firm_INN, 25) N'organization/inn' --ИНН поставщика для ЮЛ
		,dbo.f_MultiLanguageStringToStringByLanguage1(firm_KPP, 25) N'organization/kpp' --КПП поставщика только для ЮЛ
		--российский адрес
            ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_RegionCode, 25) N'russianAddress/regionISOCode'
    	    ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Area, 25) N'russianAddress/district'
			,dbo.f_MultiLanguageStringToStringByLanguage1(addr_City, 25) N'russianAddress/city'
			,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Street, 25) N'russianAddress/street'
			,dbo.f_MultiLanguageStringToStringByLanguage1(addr_House, 25) N'russianAddress/house'
			,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Apartment, 25) N'russianAddress/flat'
			,dbo.f_MultiLanguageStringToStringByLanguage1(addr_PostCode, 25) N'russianAddress/postalCode'
		,dbo.f_MultiLanguageStringToStringByLanguage1(firm_phone, 25) N'additionalInfo/phone' --телефон контактного лица
		,dbo.f_MultiLanguageStringToStringByLanguage1(PD.pepl_SecondName, 25) N'additionalInfo/nameOfCEO' --телефон контактного лица
		,dbo.f_MultiLanguageStringToStringByLanguage1(PA.pepl_SecondName, 25) N'additionalInfo/nameOfAccountant' --телефон контактного лица
	FROM Partners       P
	LEFT JOIN Firms     F ON F.firm_ID = P.part_firm_ID 
	LEFT JOIN Addresses A ON A.addr_obj_ID = F.firm_ID AND addr_Type = 2 -- CASE WHEN T2.part_firm_ID IS NULL THEN 3 ELSE 2 END AdddrType  -- рабочий (ФЛ) или юридический (ЮЛ) адрес
	LEFT JOIN People   PD ON PD.pepl_ID = F.firm_pepl_ID_Director 
	LEFT JOIN People   PA ON PA.pepl_ID = F.firm_pepl_ID_Accountant
	LEFT JOIN Notes     N ON N.note_obj_ID = P.part_ID AND note_nttp_ID = @nttp_ID_GLN
    WHERE part_ID = @part_ID_Sender
	FOR XML PATH(N'headGLN'), TYPE) 
	FOR XML PATH(N'partyInformation'), TYPE)*/
--------------------------------------------------------------------------------
DECLARE @File SYSNAME, @R NVARCHAR(MAX)
SET @R = N'<?xml  version ="1.0"  encoding ="utf-8"?>'+@Result
SET @File = 'C:\kontur\Outbox\PARTIN_'+CAST(@message_Id AS NVARCHAR(MAX))+'.xml'
EXEC dbo.external_SaveToFile @File, @R
