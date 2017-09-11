CREATE EVENT TRIGGER keep_drop_ddl ON sql_drop
   EXECUTE PROCEDURE keep_drop_command();

CREATE EVENT TRIGGER keep_ddl ON ddl_command_end
   EXECUTE PROCEDURE keep_any_command();


