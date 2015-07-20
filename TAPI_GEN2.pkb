/* Formatted on 20/07/2015 9:29:14 (QP5 v5.115.810.9015) */
CREATE OR REPLACE PACKAGE BODY tapi_gen2
AS
   --Global private variables
   g_vars              teplsql.t_assoc_array;
   g_unque_key         dbo_name_t;
   g_b_spec_template   VARCHAR2 (32767);
   g_b_body_template   VARCHAR2 (32767);

   PROCEDURE create_tapi_package (p_table_name               IN VARCHAR2
                                , p_compile_table_api        IN BOOLEAN DEFAULT TRUE
                                , p_unique_key               IN VARCHAR2 DEFAULT NULL
                                , p_created_by_col_name      IN VARCHAR2 DEFAULT NULL
                                , p_created_date_col_name    IN VARCHAR2 DEFAULT NULL
                                , p_modified_by_col_name     IN VARCHAR2 DEFAULT NULL
                                , p_modified_date_col_name   IN VARCHAR2 DEFAULT NULL )
   AS
      l_count        PLS_INTEGER := 0;
      l_table_name   dbo_name_t := LOWER (p_table_name);
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
      g_vars ('date') := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI');
      g_vars ('table_name') := l_table_name;
      g_vars ('user') := USER;
      g_vars ('created_by_col_name') := p_created_by_col_name;
      g_vars ('created_date_col_name') := p_created_date_col_name;
      g_vars ('modified_by_col_name') := p_modified_by_col_name;
      g_vars ('modified_date_col_name') := p_modified_date_col_name;
      g_vars ('result_cache') := 'RESULT_CACHE';

      FOR c1 IN (SELECT   *
                   FROM   user_tab_cols
                  WHERE   table_name = UPPER (l_table_name) AND data_type IN ('BLOB', 'CLOB'))
      LOOP
         g_vars ('result_cache') := '';
      END LOOP;

      --Define unique key if table don't hace primary key
      g_unque_key := p_unique_key;

      -- Spec --
      --Render template
      g_b_spec_template := teplsql.render (g_spec_template, g_vars);

      -- Body --
      --Render template
      g_b_body_template := teplsql.render (g_body_template, g_vars);

      IF p_compile_table_api
      THEN
         BEGIN
            EXECUTE IMMEDIATE g_b_spec_template;
         EXCEPTION
            WHEN OTHERS
            THEN
               raise_application_error (-20000, 'Spec compiled with error(s)! ' || SQLERRM);
         END;

         BEGIN
            EXECUTE IMMEDIATE g_b_body_template;
         EXCEPTION
            WHEN OTHERS
            THEN
               raise_application_error (-20000, ' Body compiled with error(s)! ' || SQLERRM);
         END;

         DBMS_OUTPUT.put_line('Creation of Table API package for ' || l_table_name || ' table completed successfully!');
      ELSE
         DBMS_OUTPUT.put_line (g_b_spec_template);
         DBMS_OUTPUT.put_line (g_b_body_template);
      END IF;
   END create_tapi_package;

   FUNCTION pk_col_name (p_table_name IN VARCHAR2)
      RETURN dbo_name_aat
      PIPELINED
   IS
      l_retval   dbo_name_t;
   BEGIN
      IF g_unque_key IS NOT NULL
      THEN
         PIPE ROW (LOWER (g_unque_key));
      ELSE
         FOR c1 IN (SELECT   LOWER (column_name) column_name
                      FROM   user_cons_columns
                     WHERE   UPPER (table_name) = UPPER (p_table_name)
                             AND constraint_name IN (SELECT   constraint_name
                                                       FROM   user_constraints
                                                      WHERE   constraint_type = 'P'))
         LOOP
            l_retval    := c1.column_name;
            PIPE ROW (l_retval);
         END LOOP;
      END IF;

      RETURN;
   END pk_col_name;


   FUNCTION tab_columns (p_table_name IN VARCHAR2, p_template IN VARCHAR2, p_delimiter IN VARCHAR2)
      RETURN VARCHAR2
   AS
      l_return   VARCHAR2 (32767);
      l_cont     PLS_INTEGER := 0;
   BEGIN
      FOR c1 IN (  SELECT   LOWER (column_name) column_name
                     FROM   user_tab_columns
                    WHERE   table_name = UPPER (p_table_name)
                 ORDER BY   column_id)
      LOOP
         l_cont      := l_cont + 1;

         IF l_cont > 1
         THEN
            l_return    := l_return || p_delimiter;
         END IF;

         l_return    := l_return || REPLACE (p_template, '${column_name}', c1.column_name);
      END LOOP;

      RETURN l_return;
   END tab_columns;

   FUNCTION pk_columns (p_table_name IN VARCHAR2, p_template IN VARCHAR2, p_delimiter IN VARCHAR2)
      RETURN VARCHAR2
   AS
      l_return   VARCHAR2 (32767);
      l_cont     PLS_INTEGER := 0;
   BEGIN
      FOR c1 IN (SELECT   COLUMN_VALUE column_name FROM table (tapi_gen2.pk_col_name (p_table_name)))
      LOOP
         l_cont      := l_cont + 1;

         IF l_cont > 1
         THEN
            l_return    := l_return || p_delimiter;
         END IF;

         l_return    := l_return || REPLACE (p_template, '${column_name}', c1.column_name);
      END LOOP;

      RETURN l_return;
   END pk_columns;


   FUNCTION tab_columns_sans_blobs (p_table_name IN VARCHAR2, p_template IN VARCHAR2, p_delimiter IN VARCHAR2)
      RETURN VARCHAR2
   AS
      l_return   VARCHAR2 (32767);
      l_cont     PLS_INTEGER := 0;
   BEGIN
      FOR c1 IN (  SELECT   LOWER (column_name) column_name
                     FROM   user_tab_columns
                    WHERE   table_name = UPPER (p_table_name)
                            AND column_name NOT IN (SELECT   column_name
                                                      FROM   user_tab_cols
                                                     WHERE   table_name = UPPER (p_table_name) AND data_type = 'BLOB')
                 ORDER BY   column_id)
      LOOP
         l_cont      := l_cont + 1;

         IF l_cont > 1
         THEN
            l_return    := l_return || p_delimiter;
         END IF;

         l_return    := l_return || REPLACE (p_template, '${column_name}', c1.column_name);
      END LOOP;

      RETURN l_return;
   END tab_columns_sans_blobs;

   FUNCTION tab_columns_for_upd (p_table_name IN VARCHAR2, p_template IN VARCHAR2, p_delimiter IN VARCHAR2)
      RETURN VARCHAR2
   AS
      l_return   VARCHAR2 (32767);
      l_cont     PLS_INTEGER := 0;
   BEGIN
      FOR c1 IN (  SELECT   LOWER (column_name) column_name
                     FROM   user_tab_columns
                    WHERE   table_name = UPPER (p_table_name)
                 ORDER BY   column_id)
      LOOP
         l_cont      := l_cont + 1;

         IF g_vars ('created_by_col_name') <> c1.column_name AND g_vars ('created_date_col_name') <> c1.column_name
         THEN
            IF l_cont > 1
            THEN
               l_return    := l_return || p_delimiter;
            END IF;


            IF g_vars ('modified_by_col_name') = c1.column_name
            THEN
               l_return    := l_return || c1.column_name || ' = USER /*dbax_core.g$username or apex_application.g_user*/';
            ELSIF g_vars ('modified_date_col_name') = c1.column_name
            THEN
               l_return    := l_return || c1.column_name || ' = SYSDATE';
            ELSE
               l_return    := l_return || REPLACE (p_template, '${column_name}', c1.column_name);
            END IF;
         END IF;
      END LOOP;

      RETURN l_return;
   END tab_columns_for_upd;
END tapi_gen2;
/