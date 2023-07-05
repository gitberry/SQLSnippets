-----------------
-- In my testing journeys over the years - I've regularly needed "fake" names and profile information to populate databases
-- so that our testers could go deep without viewing actual private information.  (I've worked decades in a bonded 
-- environment and occassionally had to work with real PI data and it always left me with a sense of extreme responsibility 
-- to ensure the privacy was maintained.
-- This led me to create dummy data whenever possible to do so.

-- this Script: From a list populated with (actual) city names gleaned from somewhere
--  plus some prefixes and suffixes - I can generate a much larger list of (actual) and real sounding city names.
-- This was tested on a list with 7600 simply one word city namnes, 4k complex (ie multiple word),
--   , and 17 prefixes (ie Mount, Happy etc) and 200 suffixes (ie Heights, Lake)
-- AN EXTRA SQL CHALLENGE: do this without looping - all within a select statement.
-- End result - some city names will be "real" - and others will be mashups of prefixes etc...
-- Extras - a little bit of stats on running it multiple times and seeing how much collision there is. 

-- todo: ensure scatalogical is accounted for - at this point - no scatalogical info in source tables - but...
-- todo: add a something mcsomethingface generator... just for fun
-- todo: add silly name generator ie Anita Beer, Ima Fallin, Bobby Floatswell etc...

WITH Base AS (
SELECT DISTINCT * FROM (
          SELECT baseID=ABS(CHECKSUM(NEWID())) /*, * */ FROM STRING_SPLIT(REPLICATE(',',8000),',') --maximum 8000 if you want more - do a union - should always generate a bit more than what you need and do a TOP at end 
UNION ALL SELECT baseID=ABS(CHECKSUM(NEWID())) /*, * */ FROM STRING_SPLIT(REPLICATE(',',8000),',')
UNION ALL SELECT baseID=ABS(CHECKSUM(NEWID())) /*, * */ FROM STRING_SPLIT(REPLICATE(',',8000),',')
) N
)
,B0 AS (SELECT RowId   = ROW_NUMBER()OVER(ORDER BY (SELECT 0)), * FROM BASE)
,B1 AS (SELECT TOP 100 percent * FROM B0 ORDER BY baseID ASC)
--,WLSimpleCity AS (SELECT RowId   = ROW_NUMBER()OVER(ORDER BY (SELECT 0)),  * FROM WordList wlx WHERE wlx.IsCity = 1 AND wlx.IfCityKind = 'Simple' )
,WLComplexCity AS (SELECT RowId   = ROW_NUMBER()OVER(ORDER BY (SELECT 0)),  * FROM WordList wlx WHERE wlx.IsCity = 1 AND wlx.IfCityKind = 'Complex' )
,WLCityPrefix AS (SELECT RowId   = ROW_NUMBER()OVER(ORDER BY (SELECT 0)),  * FROM WordList wlx WHERE wlx.IsCityPrefix = 1 )
,WLCitySuffix AS (SELECT RowId   = ROW_NUMBER()OVER(ORDER BY (SELECT 0)),  * FROM WordList wlx WHERE wlx.IsCitySuffix = 1 )
,WLSimpleCity AS (
 SELECT TOP 1000000 -- pick a little more than what you want (max will be base count * simple cnt)
  RowId   = ROW_NUMBER()OVER(ORDER BY (SELECT 0))
 , prefixRowNo=1+Abs(CHECKSUM(NewID()))%(SELECT count(*) FROM WLCityPrefix)
 , suffixRowNo=1+Abs(CHECKSUM(NewID()))%(SELECT count(*) FROM WLCitySuffix)
 , randomizer = abs(CHECKSUM(NEWID())) % 4
 ,  * 
 FROM base bb, WordList wlx WHERE wlx.IsCity = 1 AND wlx.IfCityKind = 'Simple' 
 )

-- generate names using simple names as a base divided randomly amongst 4 variations:
-- 1) name only, 2) prefix plus name, 3) name plus suffix and 4) prefix plus name plus suffix.
-- TODO: Make distributions weighted - so that some prefixes and suffixes get more
,SimpleGenerate AS (
 SELECT 
 DISTINCT 
--   c.RowId
--   ,c.*
-- ,prefix=prefix.Element
-- ,suffix = suffix.Element
-- ,
 CityName = CASE WHEN randomizer = 0 THEN c.ELEMENT
                  WHEN randomizer = 1 THEN CONCAT(c.ELEMENT,' ', suffix.Element)
                  WHEN randomizer = 2 THEN CONCAT(prefix.Element, ' ', c.ELEMENT)
				  ELSE CONCAT(prefix.Element, ' ', c.ELEMENT,' ', suffix.Element) END
 FROM WLSimpleCity c 
LEFT JOIN WLCityPrefix prefix ON prefix.RowId = c.prefixRowNo 
LEFT JOIN WLCitySuffix suffix ON suffix.RowId = c.suffixRowNo 
)

-- stats - based on my source data (listed above) my collision went from 88% Distinct with 2 runs of SimpleGenerate to 81% with 3 runs and 77% with 4 runs. 
--         these would vary a bit - but would always round to those numbers. 
-- on a simple developers version of SQL on a i7 with 64G RAM - would take about 4 seconds. 
SELECT CNT, DistinctCityName, Ratio=cast(DistinctCityName  as DECIMAL) /CNT FROM (
SELECT CNT=COUNT(*), DistinctCityName = COUNT(DISTINCT CityName) 
FROM (
SELECT CityName, Tag='S1' FROM SimpleGenerate
UNION ALL 
SELECT CityName, Tag='S2' FROM SimpleGenerate
UNION ALL 
SELECT CityName, Tag='S3' FROM SimpleGenerate
UNION ALL 
SELECT CityName, Tag='S4' FROM SimpleGenerate
UNION ALL 
select CityName = Element, Tag='C1' from WLComplexCity
) N
) N2


-- stats on input word list:
--select IsCity, IfCityKind, IsCityPrefix, IsCitySuffix, cnt=Count(*) from WordList wl WHERE wl.isCity = 1 or wl.IsCityPrefix = 1 or wl.IsCitySuffix = 1 group by IsCity, IfCityKind, IsCityPrefix, IsCitySuffix
--IsCity IfCityKind                                         IsCityPrefix IsCitySuffix cnt
-------- -------------------------------------------------- ------------ ------------ -----------
--0                                                         0            1            198
--1      Complex                                            0            0            4438
--1      Simple                                             0            0            7605
--0                                                         1            0            7
--0                                                         1            1            10
