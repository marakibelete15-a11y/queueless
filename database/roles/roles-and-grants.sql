-- Run only in a dedicated QueueLess database as its database administrator.
-- Set login passwords interactively with psql's \password command; never store them here.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='queueless_owner') THEN
    EXECUTE 'CREATE ROLE queueless_owner LOGIN';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='queueless_app') THEN
    EXECUTE 'CREATE ROLE queueless_app LOGIN';
  END IF;
END $$;
ALTER ROLE queueless_owner LOGIN;
ALTER ROLE queueless_app LOGIN;

DO $$ BEGIN
  EXECUTE format('ALTER DATABASE %I OWNER TO queueless_owner', current_database());
END $$;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
ALTER SCHEMA public OWNER TO queueless_owner;
GRANT USAGE, CREATE ON SCHEMA public TO queueless_owner;
REVOKE CREATE ON SCHEMA public FROM queueless_app;

DO $$ BEGIN
  EXECUTE format('REVOKE CREATE ON DATABASE %I FROM queueless_app', current_database());
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO queueless_app', current_database());
END $$;

-- This provisioning file is run by the local database administrator after migrations.
-- Transfer existing schema objects so future DDL and SECURITY DEFINER cleanup run as the migration owner.
DO $$ DECLARE obj record;
BEGIN
  FOR obj IN SELECT schemaname, tablename FROM pg_tables WHERE schemaname='public' LOOP
    EXECUTE format('ALTER TABLE %I.%I OWNER TO queueless_owner', obj.schemaname, obj.tablename);
  END LOOP;
  FOR obj IN SELECT sequence_schema, sequence_name FROM information_schema.sequences WHERE sequence_schema='public' LOOP
    EXECUTE format('ALTER SEQUENCE %I.%I OWNER TO queueless_owner', obj.sequence_schema, obj.sequence_name);
  END LOOP;
  FOR obj IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' LOOP
    EXECUTE format('ALTER FUNCTION %s OWNER TO queueless_owner', obj.signature);
  END LOOP;
END $$;
GRANT USAGE ON SCHEMA public TO queueless_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO queueless_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO queueless_app;

-- Business history is changed through approved workflows, never direct application DELETE.
REVOKE DELETE ON TABLE visit, patient, queue_entry, visit_event, retention_visit_summary FROM queueless_app;
REVOKE UPDATE, DELETE ON TABLE activity_log FROM queueless_app;
REVOKE UPDATE, DELETE ON TABLE retention_approval FROM queueless_app;
REVOKE ALL ON TABLE schema_migrations FROM queueless_app;

-- Event read state is the only visit_event field the application may update.
REVOKE UPDATE ON TABLE visit_event FROM queueless_app;
GRANT UPDATE (is_read) ON TABLE visit_event TO queueless_app;

GRANT EXECUTE ON FUNCTION cleanup_expired_rate_limit_counters() TO queueless_app;
GRANT EXECUTE ON FUNCTION cleanup_expired_sessions() TO queueless_app;
GRANT EXECUTE ON FUNCTION clear_expired_final_status_tokens() TO queueless_app;
GRANT EXECUTE ON FUNCTION queue_due_no_shows() TO queueless_app;
GRANT EXECUTE ON FUNCTION apply_due_no_shows() TO queueless_app;
GRANT EXECUTE ON FUNCTION execute_retention_approval(uuid) TO queueless_app;

-- Future DDL by the migration role gets reviewed, least-privilege DML defaults.
ALTER DEFAULT PRIVILEGES FOR ROLE queueless_owner IN SCHEMA public
  GRANT SELECT, INSERT ON TABLES TO queueless_app;
ALTER DEFAULT PRIVILEGES FOR ROLE queueless_owner IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO queueless_app;
ALTER DEFAULT PRIVILEGES FOR ROLE queueless_owner IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
