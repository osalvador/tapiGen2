/* Formatted on 16/09/2015 9:35:19 (QP5 v5.115.810.9015) */
CREATE OR REPLACE PACKAGE BODY tapi_gen2
AS
   --Global private variables
   g_unque_key   dbo_name_t;

   PROCEDURE create_tapi_package (p_table_name               IN VARCHAR2
                                , p_compile_table_api        IN BOOLEAN DEFAULT TRUE
                                , p_unique_key               IN VARCHAR2 DEFAULT NULL
                                , p_created_by_col_name      IN VARCHAR2 DEFAULT NULL
                                , p_created_date_col_name    IN VARCHAR2 DEFAULT NULL
                                , p_modified_by_col_name     IN VARCHAR2 DEFAULT NULL
                                , p_modified_date_col_name   IN VARCHAR2 DEFAULT NULL
                                , p_raise_exceptions         IN BOOLEAN DEFAULT FALSE )
   AS
      l_count        PLS_INTEGER := 0;
      l_table_name   dbo_name_t := LOWER (p_table_name);
      l_vars         teplsql.t_assoc_array;
      l_spec_tapi    CLOB;
      l_body_tapi    CLOB;
   BEGIN
      /*Validations*/

      --check_table_exists
      SELECT   COUNT ( * )
        INTO   l_count
        FROM   user_tables
       WHERE   UPPER (table_name) = UPPER (l_table_name);

      IF l_count = 0
      THEN
         raise_application_error (-20000, 'Table ' || l_table_name || ' does not exist!');
      END IF;

      --Check table hash PK or p_unique_key is not null
      IF p_unique_key IS NULL
      THEN
         SELECT   COUNT ( * )
           INTO   l_count
           FROM   user_constraints
          WHERE   UPPER (table_name) = UPPER (l_table_name) AND constraint_type = 'P';

         IF l_count = 0
         THEN
            raise_application_error (-20000
                                   ,    'Table '
                                     || l_table_name
                                     || ' does not have a Primary Key'
                                     || ' and P_UNIQUE_KEY parameter is null');
         END IF;
      END IF;

      --Init variables for render template
      l_vars ('date') := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI');
      l_vars ('table_name') := l_table_name;
      l_vars ('user') := USER;
      l_vars ('created_by_col_name') := p_created_by_col_name;
      l_vars ('created_date_col_name') := p_created_date_col_name;
      l_vars ('modified_by_col_name') := p_modified_by_col_name;
      l_vars ('modified_date_col_name') := p_modified_date_col_name;
      l_vars ('result_cache') := 'RESULT_CACHE';

      IF p_raise_exceptions
      THEN
         l_vars ('raise_exceptions') := 'TRUE';
      ELSE
         l_vars ('raise_exceptions') := '';
      END IF;

      --If the table hash LOBS columns, disable result_cache.
      FOR c1 IN (SELECT   *
                   FROM   user_tab_cols
                  WHERE   table_name = UPPER (l_table_name) AND data_type IN ('BLOB', 'CLOB'))
      LOOP
         l_vars ('result_cache') := '';
      END LOOP;

      --Define unique key if table don't hace primary key
      g_unque_key := p_unique_key;

      -- Spec --
      --Process template
      l_spec_tapi := teplsql.process (l_vars, 'spec', 'TAPI_GEN2');

      -- Body --
      --Process template
      l_body_tapi := teplsql.process (l_vars, 'body', 'TAPI_GEN2');

      IF p_compile_table_api
      THEN
         BEGIN
            EXECUTE IMMEDIATE l_spec_tapi;
         EXCEPTION
            WHEN OTHERS
            THEN
               DBMS_OUTPUT.put_line (l_spec_tapi);
               raise_application_error (-20000, 'Spec compiled with error(s)! ' || SQLERRM);
         END;

         BEGIN
            EXECUTE IMMEDIATE l_body_tapi;
         EXCEPTION
            WHEN OTHERS
            THEN
               raise_application_error (-20000, ' Body compiled with error(s)! ' || SQLERRM);
         END;

         DBMS_OUTPUT.put_line('Creation of Table API package for ' || l_table_name || ' table completed successfully!');
      ELSE
         DBMS_OUTPUT.put_line (l_spec_tapi);
         DBMS_OUTPUT.put_line (l_body_tapi);
      END IF;
   END create_tapi_package;


   FUNCTION get_all_columns (p_tab_name VARCHAR2)
      RETURN column_tt
   IS
      l_tt   column_tt;
   BEGIN
        SELECT   c.table_name
               , LOWER (c.column_name)
               , c.nullable
               , '' constraint_type
          BULK   COLLECT
          INTO   l_tt
          FROM   user_tab_columns c
         WHERE   c.table_name = UPPER (p_tab_name)
      ORDER BY   c.column_id;

      RETURN l_tt;
   END;

   FUNCTION get_pk_columns (p_tab_name VARCHAR2)
      RETURN column_tt
   IS
      l_tt   column_tt;
   BEGIN
      IF g_unque_key IS NOT NULL
      THEN
         IF NOT l_tt.EXISTS (1)
         THEN
            l_tt        := column_tt (NULL);
         END IF;

         l_tt (1).table_name := p_tab_name;
         l_tt (1).column_name := LOWER (g_unque_key);
         l_tt (1).nullable := 'N';
         l_tt (1).constraint_type := 'P';
      ELSE
           SELECT   c.table_name
                  , LOWER (c.column_name)
                  , c.nullable
                  , cs.constraint_type
             BULK   COLLECT
             INTO   l_tt
             FROM         user_tab_columns c
                       LEFT JOIN
                          user_cons_columns cc
                       ON c.table_name = cc.table_name AND c.column_name = cc.column_name
                    LEFT JOIN
                       user_constraints cs
                    ON cc.constraint_name = cs.constraint_name
            WHERE   c.table_name = UPPER (p_tab_name) AND cs.constraint_type = 'P'
         ORDER BY   c.column_id;
      END IF;

      RETURN l_tt;
   END;


   FUNCTION get_noblob_columns (p_tab_name VARCHAR2)
      RETURN column_tt
   IS
      l_tt   column_tt;
   BEGIN
        SELECT   c.table_name
               , LOWER (c.column_name)
               , c.nullable
               , '' constraint_type
          BULK   COLLECT
          INTO   l_tt
          FROM   user_tab_columns c
         WHERE   table_name = UPPER (p_tab_name)
                 AND column_name NOT IN (SELECT   column_name
                                           FROM   user_tab_cols
                                          WHERE   table_name = UPPER (p_tab_name) AND data_type = 'BLOB')
      ORDER BY   column_id;

      RETURN l_tt;
   END;
END tapi_gen2;
/
