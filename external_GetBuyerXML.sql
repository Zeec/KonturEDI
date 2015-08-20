IF OBJECT_ID(N'external_GetBuyerXML', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_GetBuyerXML
GO

CREATE PROCEDURE dbo.external_GetBuyerXML  (
    @part_ID UNIQUEIDENTIFIER,
	@BuyerXML XML OUTPUT)
AS
/*
    <!-- ������ ����� � ������� � ���������� -->
    <buyer>
      <gln>BuyerGln</gln> <!--gln ����������-->
      <organization>
        <name>Buyer</name>  <!--������������ ����������-->
        <inn>BuyerInn(10)</inn>  <!--��� ���������� ��� ��-->
        <kpp>BuyerKpp</kpp>  <!--��� ���������� ������ ��� ��-->
      </organization>
      <russianAddress>  <!--���������� �����-->
        <regionISOCode>RegionCode</regionISOCode>
        <district>district</district>
        <city>City</city>
        <settlement>Village</settlement>
        <street>Street</street>
        <house>House</house>
        <flat>Flat</flat>
        <postalCode>>PostalCode</postalCode>
      </russianAddress>
      <contactlInfo>
        <CEO>
          <orderContact>TelephoneNumber</orderContact> <!--������� ����������� ����-->
          <fax>FaxNumber</fax> <!--���� ����������� ����-->
          <email>Email</email> <!--email ����������� ����-->
        </CEO>
        <accountant>
          <orderContact>TelephoneNumber</orderContact> <!--������� ����������� ����-->
          <fax>FaxNumber</fax> <!--���� ����������� ����-->
          <email>Email</email> <!--email ����������� ����-->
        </accountant>
        <salesManager>
          <orderContact>TelephoneNumber</orderContact> <!--������� ����������� ����-->
          <fax>FaxNumber</fax> <!--���� ����������� ����-->
          <email>Email</email> <!--email ����������� ����-->
        </salesManager>
        <orderContact>
          <orderContact>TelephoneNumber</orderContact> <!--������� ����������� ����-->
          <fax>FaxNumber</fax> <!--���� ����������� ����-->
          <email>Email</email> <!--email ����������� ����-->
        </orderContact>
      </contactlInfo>
    </buyer>
    <!-- ����� ����� ������ � ���������� -->
*/

/*SELECT TOP 1 @part_ID = R.strqt_part_ID_Out
FROM KonturEDI.dbo.edi_Messages M
JOIN tp_StoreRequests           R ON R.strqt_ID = M.doc_ID
--JOIN tp_StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
WHERE M.messageId = @messageId*/

SET @BuyerXML = 
(
	SELECT 
	 	 dbo.f_MultiLanguageStringToStringByLanguage1(part_Description, 25) N'gln' --gln ����������
		,dbo.f_MultiLanguageStringToStringByLanguage1(part_Name, 25) N'organization/name' --������������ ���������� ��� ��	
		,dbo.f_MultiLanguageStringToStringByLanguage1(firm_INN, 25) N'organization/inn' --��� ���������� ��� ��
		,dbo.f_MultiLanguageStringToStringByLanguage1(firm_KPP, 25) N'organization/kpp' --��� ���������� ������ ��� ��
		--���������� �����
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_RegionCode, 25) N'russianAddress/regionISOCode'
    	,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Area, 25) N'russianAddress/district'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_City, 25) N'russianAddress/city'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Village, 25) N'russianAddress/settlement'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Street, 25) N'russianAddress/street'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_House, 25) N'russianAddress/house'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Apartment, 25) N'russianAddress/flat'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_PostCode, 25) N'russianAddress/postalCode'
		-- ���������� ����������
        ,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(PD.pepl_PhoneWork, ''), 25) N'contactlInfo/CEO/orderContact'--������� ����������� ����
        ,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(PD.pepl_PhoneCell, ''), 25) N'contactlInfo/CEO/fax'--���� ����������� ����
        ,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(PD.pepl_EMail, ''), 25) N'contactlInfo/CEO/email'--email ����������� ����
       
		
	FROM tp_Partners       P
	LEFT JOIN tp_Firms     F ON F.firm_ID = P.part_firm_ID
	LEFT JOIN tp_Addresses A ON A.addr_obj_ID = F.firm_ID AND addr_Type = 2 -- CASE WHEN T2.part_firm_ID IS NULL THEN 3 ELSE 2 END AdddrType  -- ������� (��) ��� ����������� (��) �����
	LEFT JOIN tp_People PD ON PD.pepl_ID = F.firm_pepl_ID_Director
	WHERE part_ID = @part_ID
	FOR XML PATH(N'buyer'), TYPE
)

