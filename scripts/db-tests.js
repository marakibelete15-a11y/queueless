'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { Client } = require('pg');
const { runMigrations } = require('./migrate');
require('dotenv').config();

async function main() {
  const url = process.env.MIGRATION_DATABASE_URL || process.env.DATABASE_URL;
  const parsedUrl = url ? new URL(url) : null;
  const localHost =
    parsedUrl && ['', 'localhost', '127.0.0.1', '[::1]'].includes(parsedUrl.hostname);
  if (
    !parsedUrl ||
    !decodeURIComponent(parsedUrl.pathname.slice(1)).endsWith('_test') ||
    !localHost
  ) {
    throw new Error(
      'Database tests require a local MIGRATION_DATABASE_URL (or DATABASE_URL) pointing to a dedicated database whose name ends with _test.'
    );
  }
  await runMigrations({ databaseUrl: url });
  await runMigrations({ databaseUrl: url });
  const db = new Client({ connectionString: url });
  await db.connect();
  const { rows: versions } = await db.query(
    'SELECT version FROM public.schema_migrations ORDER BY version'
  );
  assert.equal(versions.length, 8, 'all eight numbered migrations are applied');
  const ids = Array.from({ length: 7 }, () => crypto.randomUUID());
  const [clinic, doctor, slot, patient] = ids;
  const day = '2098-01-05';
  const fail = async (sql, params = []) => {
    await db.query('SAVEPOINT expected_failure');
    try {
      await assert.rejects(db.query(sql, params));
    } finally {
      await db.query('ROLLBACK TO SAVEPOINT expected_failure');
      await db.query('RELEASE SAVEPOINT expected_failure');
    }
  };
  await db.query('BEGIN');
  try {
    const failedMigrationProbe = `migration_failure_probe_${crypto.randomUUID().replaceAll('-', '')}`;
    const failedMigrationVersion = `999_probe_${crypto.randomUUID().replaceAll('-', '')}.sql`;
    await db.query(`CREATE TABLE public.${failedMigrationProbe}(id integer)`);
    await db.query('INSERT INTO public.schema_migrations(version,sha256) VALUES ($1,$2)', [
      failedMigrationVersion,
      '0'.repeat(64),
    ]);
    await assert.rejects(db.query('SELECT 1 / 0'));
    await db.query('ROLLBACK');
    const { rows: probe } = await db.query('SELECT to_regclass($1) AS relation', [
      `public.${failedMigrationProbe}`,
    ]);
    assert.equal(probe[0].relation, null, 'failed migration transaction leaves no partial DDL');
    const { rows: historyProbe } = await db.query(
      'SELECT 1 FROM public.schema_migrations WHERE version=$1',
      [failedMigrationVersion]
    );
    assert.equal(historyProbe.length, 0, 'failed migration does not leave a success record');
    await db.query('BEGIN');
    await db.query('INSERT INTO clinic(id,name) VALUES ($1,$2)', [
      clinic,
      'Synthetic constraint test',
    ]);
    await db.query('INSERT INTO clinic_setting(clinic_id) VALUES ($1)', [clinic]);
    await db.query('INSERT INTO doctor(id,clinic_id,display_name) VALUES ($1,$2,$3)', [
      doctor,
      clinic,
      'Synthetic Doctor',
    ]);
    await db.query(
      'INSERT INTO slot(id,clinic_id,doctor_id,starts_at,ends_at) VALUES ($1,$2,$3,$4,$5)',
      [slot, clinic, doctor, `${day} 09:00+03`, `${day} 09:30+03`]
    );
    await db.query('INSERT INTO patient(id,clinic_id,display_name) VALUES ($1,$2,$3)', [
      patient,
      clinic,
      'Synthetic Patient',
    ]);
    const secondClinic = crypto.randomUUID();
    const secondPatient = crypto.randomUUID();
    await db.query('INSERT INTO clinic(id,name) VALUES ($1,$2)', [
      secondClinic,
      'Second synthetic clinic',
    ]);
    await db.query('INSERT INTO patient(id,clinic_id,display_name) VALUES ($1,$2,$3)', [
      secondPatient,
      secondClinic,
      'Synthetic patient at second clinic',
    ]);
    await fail(
      "INSERT INTO visit(clinic_id,patient_id,doctor_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,'Walk-in','Waiting',$5)",
      [clinic, secondPatient, doctor, 'TEST-CROSS-CLINIC-REFERENCE', day]
    );
    await db.query(
      'INSERT INTO doctor_day_queue(clinic_id,doctor_id,queue_date) VALUES ($1,$2,$3)',
      [clinic, doctor, day]
    );
    const active = [clinic, patient, doctor, slot, 'TEST-BOOK-REFERENCE-001', day];
    await db.query(
      "INSERT INTO visit(clinic_id,patient_id,doctor_id,slot_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,'Appointment','Booked',$6)",
      active
    );
    await fail(
      "INSERT INTO visit(clinic_id,patient_id,doctor_id,slot_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,'Appointment','Booked',$6)",
      [clinic, patient, doctor, slot, 'TEST-BOOK-REFERENCE-002', day]
    );
    await fail(
      "INSERT INTO visit(clinic_id,patient_id,doctor_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,'Walk-in','Skipped',$5)",
      [clinic, patient, doctor, 'TEST-INVALID-STATUS', day]
    );
    await fail(
      "INSERT INTO visit(clinic_id,patient_id,doctor_id,slot_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,'Appointment','Booked',$6)",
      [clinic, patient, doctor, slot, 'TEST-BOOK-REFERENCE-001', day]
    );
    await fail("UPDATE visit SET status='Waiting' WHERE booking_ref='TEST-BOOK-REFERENCE-001'");
    await db.query(
      "UPDATE visit SET status='Cancelled',cancellation_reason_code='TEST',version=version+1 WHERE booking_ref=$1",
      ['TEST-BOOK-REFERENCE-001']
    );
    await db.query(
      "INSERT INTO visit(clinic_id,patient_id,doctor_id,slot_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,'Appointment','Booked',$6)",
      [clinic, patient, doctor, slot, 'TEST-BOOK-REFERENCE-004', day]
    );
    const { rows: activeVisits } = await db.query('SELECT id FROM visit WHERE booking_ref=$1', [
      'TEST-BOOK-REFERENCE-004',
    ]);
    await fail(
      'INSERT INTO queue_entry(clinic_id,visit_id,doctor_id,queue_date,queue_no,sequence_no,effective_at) VALUES ($1,$2,$3,$4,2,2,now())',
      [clinic, activeVisits[0].id, doctor, day]
    );
    await db.query("UPDATE visit SET status='Waiting',version=version+1 WHERE id=$1", [
      activeVisits[0].id,
    ]);
    await db.query(
      'INSERT INTO visit(clinic_id,patient_id,doctor_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,$6,$7)',
      [clinic, patient, doctor, 'TEST-WALKIN-REFERENCE', 'Walk-in', 'Waiting', day]
    );
    const { rows: walkin } = await db.query('SELECT id FROM visit WHERE booking_ref=$1', [
      'TEST-WALKIN-REFERENCE',
    ]);
    await db.query(
      'INSERT INTO queue_entry(clinic_id,visit_id,doctor_id,queue_date,queue_no,sequence_no,effective_at) VALUES ($1,$2,$3,$4,1,1,now())',
      [clinic, walkin[0].id, doctor, day]
    );
    await fail(
      'INSERT INTO queue_entry(clinic_id,visit_id,doctor_id,queue_date,queue_no,sequence_no,effective_at,skip_count) VALUES ($1,$2,$3,$4,2,2,now(),3)',
      [clinic, activeVisits[0].id, doctor, day]
    );
    await fail(
      'INSERT INTO queue_entry(clinic_id,visit_id,doctor_id,queue_date,queue_no,sequence_no,effective_at) VALUES ($1,$2,$3,$4,2,2,now())',
      [clinic, walkin[0].id, doctor, day]
    );
    await fail(
      'INSERT INTO queue_entry(clinic_id,visit_id,doctor_id,queue_date,queue_no,sequence_no,effective_at) VALUES ($1,$2,$3,$4,1,2,now())',
      [clinic, activeVisits[0].id, doctor, day]
    );
    await fail(
      'INSERT INTO queue_entry(clinic_id,visit_id,doctor_id,queue_date,queue_no,sequence_no,effective_at) VALUES ($1,$2,$3,$4,2,1,now())',
      [clinic, activeVisits[0].id, doctor, day]
    );
    await db.query(
      'INSERT INTO visit(clinic_id,patient_id,doctor_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,$6,$7)',
      [clinic, patient, doctor, 'TEST-SECOND-WALKIN', 'Walk-in', 'Waiting', day]
    );
    const { rows: second } = await db.query('SELECT id FROM visit WHERE booking_ref=$1', [
      'TEST-SECOND-WALKIN',
    ]);
    await db.query(
      "INSERT INTO queue_entry(clinic_id,visit_id,doctor_id,queue_date,queue_no,sequence_no,effective_at,paper_ref) VALUES ($1,$2,$3,$4,2,2,now(),'PAPER-1')",
      [clinic, second[0].id, doctor, day]
    );
    await db.query("UPDATE visit SET status='Called',version=version+1 WHERE id=$1", [
      walkin[0].id,
    ]);
    await fail("UPDATE visit SET status='Called',version=version+1 WHERE id=$1", [second[0].id]);
    await db.query("UPDATE visit SET status='In Consultation',version=version+1 WHERE id=$1", [
      walkin[0].id,
    ]);
    await fail("UPDATE visit SET status='In Consultation',version=version+1 WHERE id=$1", [
      activeVisits[0].id,
    ]);
    await fail(
      "INSERT INTO queue_entry(clinic_id,visit_id,doctor_id,queue_date,queue_no,sequence_no,effective_at,paper_ref) VALUES ($1,$2,$3,$4,3,3,now(),'PAPER-1')",
      [clinic, activeVisits[0].id, doctor, day]
    );
    await fail(
      'INSERT INTO visit(clinic_id,patient_id,doctor_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,$6,$7)',
      [crypto.randomUUID(), patient, doctor, 'TEST-CROSS-CLINIC', 'Walk-in', 'Waiting', day]
    );
    await fail("INSERT INTO visit_event(clinic_id,visit_id,event_type) VALUES ($1,$2,'Called')", [
      clinic,
      crypto.randomUUID(),
    ]);
    await db.query("INSERT INTO activity_log(clinic_id,event_type) VALUES ($1,'TEST_IMMUTABLE')", [
      clinic,
    ]);
    await fail("UPDATE activity_log SET event_type='CHANGED' WHERE event_type='TEST_IMMUTABLE'");
    await db.query(
      "INSERT INTO visit_event(clinic_id,visit_id,event_type) VALUES ($1,$2,'Checked In')",
      [clinic, activeVisits[0].id]
    );
    await fail("UPDATE visit_event SET event_type='Changed' WHERE visit_id=$1", [
      activeVisits[0].id,
    ]);
    const { rows: appRole } = await db.query(
      "SELECT 1 FROM pg_roles WHERE rolname='queueless_app'"
    );
    if (appRole.length) {
      const { rows: privilege } = await db.query(
        "SELECT has_schema_privilege('queueless_app','public','CREATE') AS can_create_schema, has_table_privilege('queueless_app','public.activity_log','UPDATE') AS can_update_audit, has_table_privilege('queueless_app','public.activity_log','DELETE') AS can_delete_audit"
      );
      assert.deepEqual(privilege[0], {
        can_create_schema: false,
        can_update_audit: false,
        can_delete_audit: false,
      });
    }
    await db.query('ROLLBACK');
  } catch (error) {
    await db.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    await db.end();
  }
  await verifyConcurrentSlotBooking(url);
  console.info('Database migration and constraint checks passed.');
  console.info(
    'Deferred to Phase 3: normalized-phone appointment cap, workflow/authorization transitions, advisory-lock booking service, and idempotency-key request replay behavior.'
  );
}

async function verifyConcurrentSlotBooking(url) {
  const fixture = new Client({ connectionString: url });
  await fixture.connect();
  const [clinic, doctor, patient, slot] = Array.from({ length: 4 }, () => crypto.randomUUID());
  const day = '2098-01-06';
  const first = new Client({ connectionString: url });
  const second = new Client({ connectionString: url });
  try {
    await fixture.query('INSERT INTO clinic(id,name) VALUES ($1,$2)', [
      clinic,
      'Synthetic concurrent booking test',
    ]);
    await fixture.query('INSERT INTO doctor(id,clinic_id,display_name) VALUES ($1,$2,$3)', [
      doctor,
      clinic,
      'Synthetic concurrent doctor',
    ]);
    await fixture.query('INSERT INTO patient(id,clinic_id,display_name) VALUES ($1,$2,$3)', [
      patient,
      clinic,
      'Synthetic concurrent patient',
    ]);
    await fixture.query(
      'INSERT INTO slot(id,clinic_id,doctor_id,starts_at,ends_at) VALUES ($1,$2,$3,$4,$5)',
      [slot, clinic, doctor, `${day} 09:00+03`, `${day} 09:30+03`]
    );
    await fixture.query(
      'INSERT INTO doctor_day_queue(clinic_id,doctor_id,queue_date) VALUES ($1,$2,$3)',
      [clinic, doctor, day]
    );
    const versionedVisit = crypto.randomUUID();
    await fixture.query(
      "INSERT INTO visit(id,clinic_id,patient_id,doctor_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,'Walk-in','Waiting',$6)",
      [versionedVisit, clinic, patient, doctor, `QUEUE-VERSION-${crypto.randomUUID()}`, day]
    );
    await Promise.all([first.connect(), second.connect()]);
    await first.query('BEGIN');
    await second.query('BEGIN');
    await first.query(
      'SELECT 1 FROM doctor_day_queue WHERE clinic_id=$1 AND doctor_id=$2 AND queue_date=$3 FOR UPDATE',
      [clinic, doctor, day]
    );
    const waitingForQueueLock = second.query(
      'SELECT 1 FROM doctor_day_queue WHERE clinic_id=$1 AND doctor_id=$2 AND queue_date=$3 FOR UPDATE',
      [clinic, doctor, day]
    );
    const changed = await first.query(
      'UPDATE visit SET version=version+1 WHERE id=$1 AND version=1',
      [versionedVisit]
    );
    assert.equal(changed.rowCount, 1, 'first queue operation claims the submitted visit version');
    await first.query('COMMIT');
    await waitingForQueueLock;
    const stale = await second.query(
      'UPDATE visit SET version=version+1 WHERE id=$1 AND version=1',
      [versionedVisit]
    );
    assert.equal(stale.rowCount, 0, 'second queue operation detects the stale visit version');
    await second.query('COMMIT');
    await first.query('BEGIN');
    await second.query('BEGIN');
    const addVisit = (client, ref) =>
      client.query(
        "INSERT INTO visit(clinic_id,patient_id,doctor_id,slot_id,booking_ref,visit_type,status,visit_date) VALUES ($1,$2,$3,$4,$5,'Appointment','Booked',$6)",
        [clinic, patient, doctor, slot, ref, day]
      );
    await addVisit(first, `CONCURRENT-${crypto.randomUUID()}`);
    const competingInsert = addVisit(second, `CONCURRENT-${crypto.randomUUID()}`);
    await first.query('COMMIT');
    await assert.rejects(competingInsert, error => error.code === '23505');
    await second.query('ROLLBACK');
    const { rows } = await fixture.query(
      "SELECT count(*)::int AS active FROM visit WHERE clinic_id=$1 AND slot_id=$2 AND status <> 'Cancelled'",
      [clinic, slot]
    );
    assert.equal(rows[0].active, 1, 'concurrent slot booking permits only one active appointment');
  } finally {
    await first.query('ROLLBACK').catch(() => {});
    await second.query('ROLLBACK').catch(() => {});
    await Promise.all([first.end(), second.end()]);
    await fixture.query('DELETE FROM visit WHERE clinic_id=$1', [clinic]).catch(() => {});
    await fixture
      .query('DELETE FROM doctor_day_queue WHERE clinic_id=$1', [clinic])
      .catch(() => {});
    await fixture.query('DELETE FROM slot WHERE clinic_id=$1', [clinic]).catch(() => {});
    await fixture.query('DELETE FROM patient WHERE clinic_id=$1', [clinic]).catch(() => {});
    await fixture.query('DELETE FROM doctor WHERE clinic_id=$1', [clinic]).catch(() => {});
    await fixture.query('DELETE FROM clinic WHERE id=$1', [clinic]).catch(() => {});
    await fixture.end();
  }
}

main().catch(error => {
  console.error(
    `[QueueLess DB tests] ${error.message || error.code || 'database connection failed'}`
  );
  process.exitCode = 1;
});
