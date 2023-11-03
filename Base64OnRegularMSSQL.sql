-- Encode the string "TestData" in Base64 to get "VGVzdERhdGE="
WITH 
 STEP1 AS ( SELECT TheText='TestData' UNION ALL SELECT TheText='TestData BOOYA' )
,STEP2 AS ( SELECT *, TheTextBin = CAST(TheText AS VARBINARY(MAX)) FROM STEP1 )
,STEP3 AS ( SELECT *, TheTextB64 = CAST(N'' AS XML).value('xs:base64Binary(xs:hexBinary(sql:column("TheTextBin")))', 'VARCHAR(MAX)') FROM STEP2 )
--,STEP4 AS ( SELECT *, TheTextDecoded = CAST(CAST(N'' AS XML).value('xs:base64Binary("TheTextB64")', 'VARBINARY(MAX)') AS VARCHAR(MAX)) FROM STEP3 )
,STEP4 AS (SELECT *, TheTextDecoded = CONVERT(VARCHAR(MAX), CAST('' AS XML).value('xs:base64Binary(sql:column("TheTextB64"))', 'VARBINARY(MAX)')) FROM STEP3 )

SELECT * FROM STEP4

-- yes yes - AzureSQL has nicer stuff - but sometimes you have to code in an older MSSQL platform - not everyone has all the cool tools all the time...
-- ORIGINAL FROM https://stackoverflow.com/questions/5082345/base64-encoding-in-sql-server-2005-t-sql
SELECT
    CAST(N'' AS XML).value(
          'xs:base64Binary(xs:hexBinary(sql:column("bin")))'
        , 'VARCHAR(MAX)'
    )   Base64Encoding
FROM (
    SELECT CAST('TestData' AS VARBINARY(MAX)) AS bin
) AS bin_sql_server_temp;

-- Decode the Base64-encoded string "VGVzdERhdGE=" to get back "TestData"
SELECT 
    CAST(
        CAST(N'' AS XML).value(
            'xs:base64Binary("VGVzdERhdGE=")'
          , 'VARBINARY(MAX)'
        ) 
        AS VARCHAR(MAX)
    )   ASCIIEncoding
;
