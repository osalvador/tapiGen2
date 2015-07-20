# tapiGen2
PL/SQL Table API Generator for Oracle

tapiGen2 aims to automate the creation of PLSQL TABLE APIs.

A table API, is a data access layer that provides the basic CRUD operations for a single table. The key principle, is to avoid repetition of SQL statements and consequently make it easier to optimize, maintain and enhance those statements. For this reason, a data access layer is critical. Some of us build apps that perform DML on individual tables, and so we find TAPIs useful. 

- [Let's start](#letsStart)<br/>    
- [What's New](#watsNew)<br/>
- [Getting started](#getStart)<br/>
    + [Install](#install)<br/>
    + [Usage](#usage)<br/>
- [Functions and procedures included](#functions)</br>
- [Procedure description](#procedureDesc)</br>
- [Special Thanks](#thanks)<br/>
- [Contributing](#contributing)<br/>
- [License](#license)

<a name="letsStart"></a>
## Let's start

Let's start by taking a look at a single row fetch, using its id - a very common operation. 

This would be typically done in 4 lines of code:
```sql   
SELECT *
INTO l_table_rec
FROM table_name
WHERE id = l_var_with_id;
```

Although its easy enough to write, there are few problems with this approach. 

1. This implicit cursor introduces a possible NO_DATA_FOUND exception that should be handled - that means more code. Explicit cursors would also require more code.
2. Each statement written like this, must be maintained, hence, if the table name is changed then all the statements must be updated.
3. If any of the statements written for this purpose, are not written exactly in the same way, Oracle may take a little longer to execute them.
         
The RT function in tapiGen was created for this very purpose and is used as 
follows:
   
    l_table_rec := table_name_te.rt(l_var_with_id);


That's it, one line! Granted there are many more lines behind the scenes, but
you did not have to write them nor must you maintain them. Errors are handled,
maintenance is easier, and if everyone uses this function, performance is
better. In fact, if you're using Oracle 11g, the function cache will be used 
for subsequent calls.

<a name="watsNew"></a>
## What's New in tapiGen2

tapiGen2 uses the template engine [tePLSQL](https://github.com/osalvador/tePLSQL) that simplifies the creation of code and allows it to be easily customizable.

It also adds new features to the generated API, and some of them are modified. Now , as an option, the framework [ logger ]( https://github.com/oraopensource/logger ) is used for exception handling

Also it includes:

  - Single column primary key restriction has been deleted. Now the primary key can contain from 0 to N columns. If the table has no primary key, parameter `unique_key` must be not null.   
  - The `tt` PIPELINED function has been implemented. This, returns an array of records and standardizes access to the tables, without losing the ability to make queries directly.
  - DML operations, based on the rowid, have been created to facilitate their use by API clients. `upd_rowid`, `web_upd_rowid`, `del_rowid` and `web_del_rowid` 
  - Audit columns will be injected as parameters and won't be mandatory.
  - Tables won't require a sequence restriction. In case that the used table has one, the code will have to be modified to add the `nextval()` statement. Under construction. 
  - SHA1 is used instead of MD5 hash, in Oracle 12c we will use SHA256.
  - The `put_apex_form_code` procedure has been removed.

<a name="getStart"></a>
## Getting started

<a name="install"></a>
### Install
Download and compile 

- tePLSQL.pks
- TAPI_GEN2.pks
- tePLSQL.pkb
- TAPI_GEN2.pkb

Execute on `DBMS_CRYPTO` grant are necessary. 

#### Logger
If you use logger for exception handling you may also: 

- Download logger  https://github.com/oraopensource/logger
- And follow the installation instruction https://github.com/OraOpenSource/Logger/blob/master/docs/Installation.md

Logger needs the following grants

    grant connect,create view, create job, create table, create sequence,
    create trigger, create procedure, create any context to existing_user;


<a name="usage"></a>
### Usage

#### Basic Example
Create Table API for DEPT table, without audit columns

```plsql
exec tapi_gen2.create_tapi_package (p_table_name => 'DEPT', p_compile_table_api => TRUE);
```

Result: 

    Creation of Table API package for DEPT table completed successfully!

#### With audit columns
Create Table API for EMP table assign custom audit columns. 

```plsql
exec tapi_gen2.create_tapi_package (p_table_name => 'EMP'
                                  , p_compile_table_api => FALSE
                                  , p_created_by_col_name => 'usr_create'
                                  , p_created_date_col_name => 'date_create'
                                  , p_modified_by_col_name => 'usr_update'
                                  , p_modified_date_col_name => 'date_update'
                                  , p_raise_exceptions => FALSE);
```

Because `p_compile_table_api` is set to `FALSE` tapiGen2 show source via `DBMS_OUTPUT`: 

```plsql
CREATE OR REPLACE PACKAGE tapi_DEPT
IS
   /**
   -- # TAPI_DEPT
   -- Generated by: tapiGen2 - DO NOT MODIFY!
   -- Website: github.com/osalvador/tapiGen2
   -- Created On: 15-JUL-2015 17:33
   -- Created By: TEST
   */

   --Scalar/Column types
   SUBTYPE hash_t IS varchar2 (40);   
   SUBTYPE deptno IS dept.deptno%TYPE;
   SUBTYPE dname IS dept.dname%TYPE;
   SUBTYPE loc IS dept.loc%TYPE;   

   --Record type
   TYPE dept_rt
   IS
      RECORD (
        deptno   dept.deptno%TYPE,
        dname   dept.dname%TYPE,
        loc   dept.loc%TYPE,
        hash               hash_t,
        row_id            VARCHAR2(64)
      );
.....
```

<a name="functions"></a>
## Functions and procedures that exist within each package that tapiGen2 creates

Here is a brief list of the various functions and procedures that exist within
each package that tapiGen creates: *(f) = function and (p) = procedure

1. ``rt`` (f) - Returns a record from the table. Uses function result cache in
11g.
2. ``rt_for_update`` (f) - Returns a record from the table and places a row level
lock on it.
3. ``tt`` (f) - Returns record Table as PIPELINED Function. 
Pipe-lining negates the need to build huge collections by piping rows out of the function as they are created, saving memory and allowing subsequent processing to start before all the rows are generated -- <cite>[Oracle Base Blog][1]</cite>
4. ``ins`` (p) - Inserts a row into the table. Automatically updates the audit
columns: created_by, created_date, modified_by, and modified_date.
5. ``upd`` (p) - Updates a row in the table. Automatically updates the audit
columns: modified_by, and modified_date.
6. ``web_upd`` (p) - Updates a row in the table. Performs an optimistic locking 
check prior to performing the update. Automatically updates the audit
columns: modified_by, and modified_date.
7. ``del`` (p) - Deletes a row from the table.
8. ``web_del`` (p) - Deletes a row from the table. Performs an optimistic locking check prior to performing the update.
9. ``hash`` (f) - Returns an SHA1 hash of a row in the table.
10. `upd_rowid` (p) - Same as `upd` but access directly to the row by rowid.
11. `web_upd_rowid` (p) - Same as `web_upd` but access directly to the row by rowid.
12. `del_rowid` (p) - Same as `del` but access directly to the row by rowid.
13. `web_del_rowid` (p) - Same as `web_del` but access directly to the row by rowid.
14. `hash_rowid` (f) - Same as `hash` but access directly to the row by rowid.


[1]:https://oracle-base.com/articles/misc/pipelined-table-functions#pipelined_table_functions

<a name="procedureDesc"></a>
## tapiGen2 procedure description
### CREATE_TAPI_PACKAGE

```plsql
PROCEDURE create_tapi_package (p_table_name               IN VARCHAR2
                               , p_compile_table_api        IN BOOLEAN DEFAULT TRUE
                               , p_unique_key               IN VARCHAR2 DEFAULT NULL
                               , p_created_by_col_name      IN VARCHAR2 DEFAULT NULL
                               , p_created_date_col_name    IN VARCHAR2 DEFAULT NULL
                               , p_modified_by_col_name     IN VARCHAR2 DEFAULT NULL
                               , p_modified_date_col_name   IN VARCHAR2 DEFAULT NULL
                               , p_raise_exceptions         IN BOOLEAN DEFAULT FALSE);
```

#### Description:
Create PL/SQL Table API

#### IN Parameters

| Name | Type | Description
|------|------|------------
| p_table_name | VARCHAR2 | must be NOT NULL
| p_compile_table_api | BOOLEAN | TRUE for compile generated package, FALSE to DBMS_OUTPUT the source
| p_unique_key | VARCHAR2 | If the table has no primary key, it indicates the column that will be used as a unique key
| p_created_by_col_name | VARCHAR2 | Custom audit column
| p_created_date_col_name | VARCHAR2 | Custom audit column
| p_modified_by_col_name | VARCHAR2 | Custom audit column
| p_modified_date_col_name | VARCHAR2 | Custom audit column
| p_raise_exceptions | BOOLEAN | TRUE to use logger for exception handling


#### Amendments

| When         | Who                      | What
|--------------|--------------------------|------------------
|16-JUL-2015   | osalvador                | Created
|20-JUL-2015   | osalvador                | Added logger exception handling

<a name="thanks"></a>
## Special thanks

tapiGen2 is the continuation of the Open Source project created by Daniel McGhan in 2008, [tapiGen](http://sourceforge.net/projects/tapigen/).

<a name="contributing"></a>
## Contributing

If you have any ideas, get in touch directly.

Please insert at the bottom of your commit message the following line, having in it your name and e-mail address .

    Signed-off-by: Your Name <you@example.org>

This can be automatically added to pull requests by committing with:

    git commit --signoff

<a name="license"></a>
## License

Copyright 2015 Oscar Salvador Magallanes 

tapiGen2 is under MIT license. 
