# Development progress

## QueueLess Phase 2 database layer

- Filled migrations `001`–`008` with explicit UP and DOWN sections, clinic ownership, FK delete behavior, constraints, triggers and query indexes. The custom SQL runner now parses UP/DOWN and supports `npm run migrate:down`; runner checksums keep repeated development runs safe.
- Added the database role/grant provisioning script, minimal fictional seed, 20,000-visit/10-doctor synthetic explain seed, eight-query EXPLAIN suite, schema/retention documentation and administrator-approved retention cleanup routines.
- Fresh local PostgreSQL run applied all eight migrations, ran the minimal and large seeds, rolled all eight migrations DOWN in order, reapplied them, and reran both seeds. The final fresh seed counts were 20,007 visits, 10 doctors, 2,030 patients, 17,958 queue entries, 20,007 events and 20,001 audit rows. All seven visit statuses were present; retention values remained NULL.
- Integrity audit found zero foreign keys without a leading supporting index. The permitted data columns include only `clinic.address` (the required clinic contact field) and `visit.status`; no patient address, medical, identity-document, payment or GPS fields exist.
- The EXPLAIN suite on the large development fixture showed index scans for queue board, dashboard date counts, available slot conflict checks, booking reference, status token, ETA, newest audit and unread event queries. It showed no sequential scan of a large table. PostgreSQL may choose a sequential scan for small clinic/doctor lookup tables and tiny fixtures.
- Role provisioning SQL is present, but was not applied on the local server because the connected `maraki` database role lacks `CREATEROLE`; the task-local PostgreSQL server later stopped, and the sandbox does not permit opening replacement local sockets. Apply `database/roles/roles-and-grants.sql` as a database administrator in the target environment.
- `npm run lint` passes. `npm test` ran the unit suite successfully; the health integration test could not bind to `127.0.0.1` (`listen EPERM`) under sandbox socket restrictions.
