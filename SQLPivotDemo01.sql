---
--- a simple Pivot example using random data generated from https://github.com/gitberry/SQLSnippets/blob/main/generateRandomDataTake01.sql
---
WITH 
 Base AS (SELECT * FROM MyRawData)
,Summary1 AS (
 SELECT 
   ForRow         = ForRow
  ,ForColumn      = ForColumn
  ,ForValue       = Sum(ForValue)
  ,ForValueAvg    = Avg(ForValue)
  ,ForValueCnt    = Count(ForValue)
  ,ForValueCntAll = Count(*)
  FROM BASE
  GROUP BY ForRow, ForColumn
  )
--SELECT * FROM Summary1 -- This will tell you things about the data - for example null values can affect counts etc...
------------------------------------
,Pivot1 AS (
 SELECT  
   ForRow    
  ,[Amtel]   
  ,[Smarkle] 
  ,[Whanty]  
 FROM (SELECT ForColumn, ForValue, ForRow FROM Summary1) AS MyData 
 PIVOT (Sum(ForValue) FOR ForColumn in (
 [Amtel]      
,[Smarkle]  
,[Whanty]  
)) AS MyPivot )
------------------------------------
,Pivot2 AS (
 SELECT  
   ForRow    
  ,[Amtel]   
  ,[Smarkle] 
  ,[Whanty]  
 FROM (SELECT ForColumn, ForValueCnt, ForRow FROM Summary1) AS MyData 
 PIVOT (Sum(ForValueCnt) FOR ForColumn in (
 [Amtel]      
,[Smarkle]  
,[Whanty]  
)) AS MyPivot )
------------------------------------
,Pivot3 AS (
 SELECT  
   ForRow    
  ,[Amtel]   
  ,[Smarkle] 
  ,[Whanty]  
 FROM (SELECT ForColumn, ForValueCntAll, ForRow FROM Summary1) AS MyData 
 PIVOT (Sum(ForValueCntAll) FOR ForColumn in (
 [Amtel]      
,[Smarkle]  
,[Whanty]  
)) AS MyPivot )
------------------------------------
-- some possible results depending on what you're wanting to do...
-- to make the nulls more palatable.. SELECT ForRow, S1=Isnull(Amtel,0),S2=ISNULL(Smarkle,0), S3=ISNULL(Whanty,0) FROM Pivot1
--  or invisible: SELECT ForRow, S1=Isnull(concat(Amtel,''),''),S2=ISNULL(concat('',Smarkle),''), S3=ISNULL(concat('',Whanty),'') FROM Pivot1
--SELECT * FROM Pivot1 -- to demonstrate summing..
--SELECT * FROM Pivot2 -- To demonstrate counting
--SELECT * FROM Pivot3 -- this is primarily here to demonstrate how count must be used VERY judiciously...
