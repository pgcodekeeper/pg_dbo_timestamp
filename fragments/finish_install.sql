CREATE EVENT TRIGGER dbots_tg_on_drop_event ON sql_drop
   EXECUTE PROCEDURE dbots_on_drop_event();

CREATE EVENT TRIGGER dbots_tg_on_ddl_event ON ddl_command_end
   EXECUTE PROCEDURE dbots_on_ddl_event();

SELECT dbots_init_timestamps();

ALTER EVENT TRIGGER dbots_tg_on_ddl_event DISABLE;
