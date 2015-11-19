-- mdqu_ID = '6DD9B694-5916-2F47-9031-01B956A4238B'

EXEC tpsrv_Logon

IF EXISTS(SELECT * FROM tpsys_TableFields WHERE tpsysf_Name = 'edi_Status')
  DELETE FROM tpsys_TableFields WHERE tpsysf_Name = 'edi_Status'

INSERT INTO tpsys_TableFields (tpsysf_ID, tpsysf_DateCreate, tpsysf_Name, tpsysf_Description, tpsysf_Caption, tpsysf_IsLanguageInsensitive)
VALUES (NEWID(), GETDATE(), 'edi_Status', 'Статус поставщика', 'Статус поставщика', 0)

DECLARE 
  @mdqu_ID UNIQUEIDENTIFIER = '78F3C8B6-5375-814D-9A8A-B62353FC012A',
  @mod_ID  UNIQUEIDENTIFIER = '9C6C6733-CC79-4B22-B24E-E9DEB4BB62F1'

IF EXISTS(SELECT * FROM tp_ModuleQueries WHERE mdqu_ID = @mdqu_ID)
  DELETE FROM tp_ModuleQueries WHERE mdqu_ID = @mdqu_ID

INSERT INTO tp_ModuleQueries (
  mdqu_ID,
  mdqu_mod_ID,
  mdqu_QueryName,
  mdqu_Name,
  mdqu_Description,
  mdqu_SQL,
  mdqu_ModifySQLBefore,
  mdqu_ModifySQLAfter,
  mdqu_Streams,
  mdqu_Wizard,
  mdqu_WizardEditParams,
  mdqu_WizardParams,
  mdqu_ModuleParamNames)
VALUES (
@mdqu_ID,
@mod_ID,
NULL,
@mdqu_ID,
NULL,
'IF OBJECT_ID(''tempdb..#StoreRequests'') IS NOT NULL DROP TABLE #StoreRequests
IF OBJECT_ID(''tempdb..#StoreRequestsItemsCount'') IS NOT NULL DROP TABLE #StoreRequestsItemsCount

SELECT strqt_ID
INTO #StoreRequests
FROM StoreRequests
JOIN %Stores S                ON S.stor_ID = strqt_stor_ID_In
WHERE strqt_part_ID_Out IS NOT NULL
  AND (ISNULL(strqt_Date,GETDATE()) BETWEEN %DateBegin AND %DateEnd)
  AND (%AllDocuments = 1 OR strqt_usr_ID = dbo.tpsrv_GetUserID())

CREATE TABLE #StoreRequestsItemsCount (strqt_ID UNIQUEIDENTIFIER, percent_Count NUMERIC(18, 6))

INSERT INTO #StoreRequestsItemsCount(strqt_ID, percent_Count)
SELECT SRI.strqti_strqt_ID, AVG(CAST(CASE WHEN SRI.strqti_strqtist_ID = 2 THEN 1 ELSE ISNULL(SRI.strqti_strqtist_ID, 0) END AS NUMERIC(18, 6))) as percent_Count
FROM StoreRequestItems SRI
JOIN #StoreRequests    SR ON SRI.strqti_strqt_ID = SR.strqt_ID 
GROUP BY SRI.strqti_strqt_ID

--StoreRequests(strqt_ID)
SELECT SR.strqt_ID, strqt_DateInput, strqt_DateLimit, strqt_Date, strqt_Name, strqt_Description
    ,strqt_strqtyp_ID, strqtyp_ID, strqtyp_Name
    ,strqt_stor_ID_In AS ''strqt_stor_ID_RequestIn'', Store_ID_In.stor_ID AS ''stor_ID_RequestIn'', Store_ID_In.stor_Name AS ''stor_Name_RequestIn'', Store_ID_In.stor_del_ID AS ''stor_del_ID_RequestIn''
    ,strqt_part_ID_Out, part_ID AS ''part_ID_Out'', part_Name AS ''part_Name_Out'', part_del_ID AS ''part_del_ID_Out''
    ,strqt_usr_ID, usr_ID, usr_Name, usr_del_ID, usr_IsDisabled
    ,strqt_strqtst_ID, strqtst_ID, strqtst_Name, ''strqtst_NamePartner'' AS ''strqtst_ObjectFieldName''
    ,SRIC.percent_Count AS ''strqt_percent_input''
    ,RIGHT(CONVERT(NVARCHAR(MAX), N.note_Value), LEN(CONVERT(NVARCHAR(MAX), N.note_Value))-26)  ''edi_Status''
FROM StoreRequests                   SR
     JOIN #StoreRequests              S ON S.strqt_ID          = SR.strqt_ID
LEFT JOIN StoreRequestTypes             ON strqtyp_ID          = strqt_strqtyp_ID
LEFT JOIN Stores            Store_ID_In ON Store_ID_In.stor_ID = strqt_stor_ID_In
LEFT JOIN Users                         ON usr_ID              = strqt_usr_ID
LEFT JOIN StoreRequestStates            ON strqtst_ID          = strqt_strqtst_ID
LEFT JOIN Partners                      ON part_ID             = strqt_part_ID_Out
LEFT JOIN #StoreRequestsItemsCount SRIC ON SRIC.strqt_ID       = SR.strqt_ID
LEFT JOIN Notes                       N ON note_obj_ID = SR.strqt_ID AND note_nttp_ID = ''fc9f6de1-3cf3-5247-ae66-8efc7b40c5b8''

DROP TABLE #StoreRequests
DROP TABLE #StoreRequestsItemsCount','IF EXISTS(SELECT * FROM %StoreRequests.Deleted) BEGIN
    UPDATE U
    SET U.strqti_strqtist_ID = 0
    FROM %StoreRequests.Deleted D
    JOIN StoreRequestItems      I ON D.strqt_ID  = I.strqti_strqt_ID
    JOIN StoreRequestItemLinks  L ON I.strqti_ID = L.strqtil_strqti_ID_Dest
    JOIN StoreRequestItems      U ON U.strqti_ID = L.strqtil_strqti_ID_Src

    DELETE I
    FROM StoreRequestItemLinks  I
    JOIN StoreRequestItems      SRI ON SRI.strqti_ID = I.strqtil_strqti_ID_Dest
    JOIN %StoreRequests.Deleted D   ON D.strqt_ID    = SRI.strqti_strqt_ID

    DELETE D
    FROM StoreRequestItems D
    JOIN %StoreRequests.Deleted ON strqt_ID = strqti_strqt_ID
END','','StoreRequests(strqt_ID)',NULL,NULL,NULL,NULL)