/* 
   After Years of working with SQL and SOAP - I find myself wanting to know more about the structure of JSON I'm working with
   so this is my first crack at grabbing some JSON that has a few nested levels - and seeing if I can sus out a crude ORM
   and why not use recursion while I'm at it!

   -- Understanding the output --
   given proper JSON it should return a structure that 
    starts with a Source
   followed by fields (or foreign keys) for a ROOT Table 
   followed by fields (or foreign keys) for each of the tables for which a FK is defined

   (Next iteration may try to sus out ID keys etc and create SQL to define a relational database for storing/serving JSON)
   NOTE: this script depends heavily on OPENJSON() to parse and categorize the key/value pairs in any given JSON
*/
-------------------------------------------------------------------------------------------------------
-- Step 1: some sufficiently nested (and varied key/value pairs in successive objects) JSON
--  to be able to verify that we're getting an object model that is "correct"
--  it SHOULD sus out key/value pairs that are in only one object 
--  this means that an object received would still have null values in some 
--  "fields" of a normalized relational database - but that should be OK - before JSON that was a thing
-------------------------------------------------------------------------------------------------------
DECLARE @nestedjson VarChar(max) = N'
[{"id": "AndersenFamily",
  "familyName": "AndersenFamily",
  "parents": [
      { "familyName": "Bakefield", "givenName": "Dobin" },
      { "familyName": "Giller", "givenName": "Den" }  ],
  "children": [      {
        "familyName": "Derriam",
        "givenName": "Bessie",
        "sex": "female",
        "grade": 2,
        "pets": [ { "petName": "Snowy", "breed": "minature mutt" },
                  { "petName": "Sharky", "breed": "fish" }        ]
      },      { 
        "familyName": "Jiller",
         "givenName": "Pila",
         "sex": "female",
         "grade": 7 }
  ],
  "address": { "state": "KY", "county": "Pinchollar", "city": "Sooeey" },
  "creationDate": 1431620463,
  "isRegistered": false,
  "petOwner": true
}
,{"id": "BandersenFamily",
  "familyName": "BandersenFamily",
  "parents": [
      { "familyName": "Wakefield", "givenName": "Robin" },
      { "familyName": "Miller", "givenName": "Ben" }
  ],
  "children": [      {
        "familyName": "Merriam",
        "givenName": "Jesse",
        "sex": "female",
        "grade": 1,
        "pets": [ { "petName": "Goofy" },
                  { "petName": "Shadow" }        ]      },
      { 
        "familyName": "Miller",
         "givenName": "Lisa",
         "sex": "female",
         "grade": 8 }  ],
  "address": { "state": "NY", "county": "Manhattan", "city": "NY" },
  "creationDate": 1431620462,
  "isRegistered": false,
  "isGISenthusiast": true 
}]'

------------------
-- Housekeeping: get the string into a function later, set up various tables we need to do things
DROP TABLE JsonORMGrokSOURCE
SELECT theSource=@nestedjson  INTO JsonORMGrokSOURCE

DROP TABLE nestData 
CREATE TABLE nestData (
   id int identity constraint netDataPK primary key
   ,parentid  int not null default -1
   ,nestlevel int not null
   ,nestKey   varchar(300) not null -- should be 4000 but I'm just optimizing for this demo...
   ,nestValue nvarchar(max)
   ,nestType  int not null
   ,compare1  VARCHAR(100)
   ,compare2  varchar(100)
)
GO
DROP TABLE nestDataTmp 
SELECT TOP 0 * INTO nestDataTmp FROM nestData
GO

------------------
-- If we've done this correctly - this only Parses a given blob of JSON once.  (any nested JSON will be parsed subsequently of course)
CREATE OR ALTER FUNCTION  grok1JsonBlob (
    @givenLevel INT,
   @givenParent INT,
   @givenJson varchar(max)
)
RETURNS TABLE
AS
RETURN
 SELECT nestLevel=@givenLevel, parentid = @givenParent, * FROM OPENJSON(@givenJson)
go

------------------
-- the Stored proc that will recurse through the JSON  to process any nested JSON
CREATE OR ALTER PROC GrokWithin1Json ( @givenLevel INT, @givenLimit INT, @givenParent INT, @givenJson varchar(max) ) 
AS
BEGIN 
IF @givenLevel < @givenLimit 
   BEGIN
   -- throw things into a temp table - so we can then filter it to process ONLY those records which have not yet been Groked
   TRUNCATE TABLE nestDataTmp
   INSERT INTO    nestDataTmp( nestLevel,  parentid,  nestKey,  nestValue,  nestType)
    SELECT * FROM dbo.grok1JsonBlob(@givenLevel, @givenParent, @givenJson) 
   UPDATE nestDataTmp SET compare2 = Concat('|',nestKey,'|',nestLevel)  -- Prepopulate so we're only doing it once...
   -- ONLY keep those which are new to process
   INSERT INTO nestData(  nestLevel,  parentid,  nestKey,  nestValue,  nestType, compare1, compare2)
    SELECT x.nestLevel, x.parentid, x.nestKey, x.nestValue, x.nestType 
    ,x.compare2, Concat('|',z.nestKey,'|',z.nestLevel)   
    FROM nestDataTmp x 
     LEFT JOIN nestData z ON x.parentid = z.parentid and x.nestKey = z.nestKey 
     WHERE x.compare2 <> Concat('|',z.nestKey,'|',z.nestLevel) 
   
   -- iterate through the ones in this level we just grabbed - recurse any nested JSON...
   SELECT * INTO #tmpData FROM NestData d WHERE d.nestlevel = @givenLevel AND ISJSON(d.nestValue) = 1 --(types 4 & 5 are/should be valid JSON arrays/objects)
   DECLARE @newLevel INT = @givenLevel + 1
   WHILE ((SELECT COUNT(*) FROM #tmpData) > 0)
      BEGIN
      DECLARE @thisJson varchar(max), @thisParent INT 
      SELECT TOP 1 @thisJson = nestValue, @thisParent = id FROM #tmpData nx ORDER BY id
      DELETE FROM #tmpData WHERE id = (SELECT TOP 1 id FROM #tmpData nx ORDER BY id)
      EXEC GrokWithin1Json @newLevel, @givenLimit, @thisParent, @thisJson
      END
   END
END
GO

------------------
-- Get our JSON and execute the Grok code...
DECLARE @nestedJson VarChar(max) = (SELECT theSource FROM JsonORMGrokSOURCE)
EXEC GrokWithin1Json 0, 25, 0, @nestedJson -- 

------------------
--- Organize and display the data we just created:
SELECT DISTINCT Level=nestLevel, TableName , FieldName=nestKey 
   FROM (
   -- tweaky tweaky..
   SELECT nestLevel, nestKey = CASE WHEN nestLevel = '0' THEN '0' ELSE nestKey END, TableName = ISNULL(TableName,'SOURCE')  
   FROM (
      SELECT a.* 
      ,TableName =
      CASE 
        WHEN a.nestlevel = 1                  THEN                                 -- Root  & Root FK
          CASE WHEN a.nestType in (5,4) THEN 'ROOT-FK:' + a.nestKey           
                                        ELSE 'ROOT' END
         WHEN B.nestType =4 AND C.nestType = 5 THEN '---'                          -- Arrays create the need to look at grandparents
         WHEN a.nesttype in (4,5)              THEN c.nestKey + '-FK:' + a.nestKey -- The parent/grandparent type combination that indicates a FK
         WHEN c.nestType   = 4                 THEN c.nestKey                      -- the grandparent holds our table name
         WHEN b.nestType in (4,5)              THEN b.nestKey                      -- the parent holds our table name
                                               ELSE 'HMM??'                        -- an option that should NEVER occur..
         END
      FROM      nestData a 
      LEFT JOIN nestData b ON a.parentid = b.id -- parent
      LEFT JOIN nestData c on b.parentid = c.id -- grandparent - since we need to look inside arrays
       ) wrap1  
   ) wrap2
WHERE TableName <> '---'          -- not needed 
ORDER BY nestlevel, TableName     -- to make it more readable... (if generating SQL code to create tables - would be necessary)

/* ------------------

on a basic dev workstation takes less than 1 second

Output: 
Level  TableName         FieldName
------ ----------------- -----------------
0      SOURCE            0
1      ROOT              creationDate
1      ROOT              familyName
1      ROOT              id
1      ROOT              isGISenthusiast
1      ROOT              isRegistered
1      ROOT              petOwner
1      ROOT-FK:address   address
1      ROOT-FK:children  children
1      ROOT-FK:parents   parents
2      address           city
2      address           county
2      address           state
3      children          familyName
3      children          givenName
3      children          grade
3      children          sex
3      children-FK:pets  pets
3      parents           familyName
3      parents           givenName
5      pets              breed
5      pets              petName        

Beyond the scope of this little script - determine the types of the key/value pairs contents... 
Maybe next kick at it - I could see it being useful if we were generating SQL tables to match some undefined JSON we're consuming

*/