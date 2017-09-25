CREATE EVENT TRIGGER keep_drop_ddl_timestamps ON sql_drop
   EXECUTE PROCEDURE keep_drop_command();

CREATE EVENT TRIGGER keep_ddl_timestamps ON ddl_command_end
   EXECUTE PROCEDURE keep_any_command();

SELECT initial_time_keeper();

ALTER EVENT TRIGGER keep_ddl_timestamps DISABLE;