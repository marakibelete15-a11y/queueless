-- Large deterministic synthetic workload for planner demonstrations only.
-- Run after 001_synthetic_seed.sql on a local *_dev database with APP_MODE=demo.
-- The seed creates 20,000 historical visits and 10 total doctors over the last 90 days.

INSERT INTO doctor (doctor_id, clinic_id, name, specialty)
SELECT md5('large-doctor-' || n)::uuid, '10000000-0000-4000-8000-000000000001',
       'Dr Synthetic ' || lpad(n::text,2,'0'), 'Synthetic specialty ' || lpad(n::text,2,'0')
FROM generate_series(3,10) AS n
ON CONFLICT (doctor_id) DO NOTHING;

INSERT INTO doctor_schedule (schedule_id, clinic_id, doctor_id, title, weekday, start_time, end_time,
                             slot_minutes, effective_from, effective_until)
SELECT md5('large-schedule-' || d.doctor_id || '-' || weekday)::uuid,
       d.clinic_id, d.doctor_id, 'Synthetic weekday 10-minute schedule', weekday,
       '09:00', '17:00', 10,
       (clock_timestamp() AT TIME ZONE c.timezone)::date - 90, NULL
FROM doctor d JOIN clinic c USING (clinic_id) CROSS JOIN generate_series(1,5) AS weekday
WHERE d.clinic_id='10000000-0000-4000-8000-000000000001'
  AND d.doctor_id=ANY(ARRAY(SELECT md5('large-doctor-' || n)::uuid FROM generate_series(3,10) AS n))
ON CONFLICT (schedule_id) DO NOTHING;

INSERT INTO patient (patient_id, clinic_id, full_name, phone, is_minor, contact_person_name)
SELECT md5('large-patient-' || n)::uuid, '10000000-0000-4000-8000-000000000001',
       'Fictional Explain Patient ' || lpad(n::text,4,'0'),
       '+251001' || lpad(n::text,6,'0'), false, NULL
FROM generate_series(1,2000) AS n
ON CONFLICT (patient_id) DO NOTHING;

INSERT INTO slot (slot_id, clinic_id, doctor_id, schedule_id, title, start_at, end_at)
SELECT md5('large-slot-' || d.doctor_id || '-' || clinic_day || '-' || slot_no)::uuid,
       d.clinic_id, d.doctor_id, s.schedule_id, 'Synthetic explain slot',
       ((clinic_day + s.start_time + slot_no * s.slot_minutes * interval '1 minute') AT TIME ZONE c.timezone),
       ((clinic_day + s.start_time + (slot_no+1) * s.slot_minutes * interval '1 minute') AT TIME ZONE c.timezone)
FROM doctor d JOIN clinic c USING (clinic_id)
JOIN doctor_schedule s ON s.clinic_id=d.clinic_id AND s.doctor_id=d.doctor_id
CROSS JOIN generate_series(-89,14) AS day_offset
CROSS JOIN LATERAL (SELECT ((clock_timestamp() AT TIME ZONE c.timezone)::date + day_offset) AS clinic_day) day
CROSS JOIN LATERAL generate_series(0,
  ((extract(epoch FROM (s.end_time-s.start_time))/60)::integer / s.slot_minutes)-1) AS slot_no
WHERE d.clinic_id='10000000-0000-4000-8000-000000000001'
  AND s.weekday=extract(dow FROM day.clinic_day)::smallint
  AND NOT EXISTS (
    SELECT 1 FROM slot old
    WHERE old.doctor_id=d.doctor_id
      AND old.start_at < ((day.clinic_day+s.start_time+(slot_no+1)*s.slot_minutes*interval '1 minute') AT TIME ZONE c.timezone)
      AND old.end_at > ((day.clinic_day+s.start_time+slot_no*s.slot_minutes*interval '1 minute') AT TIME ZONE c.timezone)
  )
ON CONFLICT (doctor_id, start_at) DO NOTHING;

INSERT INTO doctor_day_queue (clinic_id, doctor_id, queue_date)
SELECT DISTINCT d.clinic_id, d.doctor_id,
       (s.start_at AT TIME ZONE c.timezone)::date
FROM doctor d JOIN clinic c USING (clinic_id) JOIN slot s ON s.clinic_id=d.clinic_id AND s.doctor_id=d.doctor_id
WHERE d.clinic_id='10000000-0000-4000-8000-000000000001'
  AND s.start_at >= clock_timestamp()-interval '90 days'
  AND s.start_at < clock_timestamp()
ON CONFLICT (doctor_id, queue_date) DO NOTHING;

DO $$
DECLARE usable_slots bigint;
BEGIN
  SELECT count(*) INTO usable_slots FROM slot s
  WHERE s.clinic_id='10000000-0000-4000-8000-000000000001'
    AND s.start_at >= clock_timestamp()-interval '90 days'
    AND s.start_at < clock_timestamp()
    AND NOT EXISTS (SELECT 1 FROM visit v WHERE v.slot_id=s.slot_id);
  IF usable_slots < 20000 AND NOT EXISTS (
    SELECT 1 FROM visit_event WHERE event_key='seed.large_explain_fixture'
  ) THEN RAISE EXCEPTION 'large seed requires at least 20,000 unused historical slots; found %', usable_slots; END IF;
END $$;

WITH eligible AS (
  SELECT s.*, row_number() OVER (ORDER BY md5(s.slot_id::text)) AS sample_no
  FROM slot s
  WHERE s.clinic_id='10000000-0000-4000-8000-000000000001'
    AND s.start_at >= clock_timestamp()-interval '90 days'
    AND s.start_at < clock_timestamp()
    AND NOT EXISTS (SELECT 1 FROM visit v WHERE v.slot_id=s.slot_id)
), sample AS (
  SELECT e.*, ((hashtextextended(e.slot_id::text, 42) % 100 + 100) % 100)::integer AS bucket,
         ((e.start_at AT TIME ZONE 'Africa/Addis_Ababa')::date) AS clinic_day,
         row_number() OVER (PARTITION BY e.doctor_id, (e.start_at AT TIME ZONE 'Africa/Addis_Ababa')::date
                            ORDER BY e.start_at) AS sequence
  FROM eligible e WHERE e.sample_no <= 20000
)
INSERT INTO visit (visit_id, clinic_id, patient_id, doctor_id, slot_id, type, status, booking_ref,
                   booked_by, cancel_reason_code, visit_date, created_at)
SELECT md5('large-visit-' || x.slot_id)::uuid, x.clinic_id,
       md5('large-patient-' || (((x.sample_no-1) % 2000)+1))::uuid,
       x.doctor_id, x.slot_id, 'appointment',
       CASE WHEN x.bucket < 5 THEN 'Cancelled' WHEN x.bucket < 10 THEN 'No-Show' ELSE 'Completed' END,
       generate_booking_ref(), '10000000-0000-4000-8000-000000000012',
       CASE WHEN x.bucket < 5 THEN 'STAFF_REQUEST' END, x.clinic_day, x.start_at-interval '7 days'
FROM sample x
WHERE NOT EXISTS (SELECT 1 FROM visit_event WHERE event_key='seed.large_explain_fixture')
ON CONFLICT (visit_id) DO NOTHING;

WITH selected AS (
  SELECT v.*, s.start_at,
         row_number() OVER (PARTITION BY v.doctor_id, v.visit_date ORDER BY s.start_at)::integer
           + COALESCE((SELECT max(q.queue_no) FROM queue_entry q WHERE q.clinic_id=v.clinic_id
             AND q.doctor_id=v.doctor_id AND q.queue_date=v.visit_date),0)::integer AS seq
  FROM visit v JOIN slot s ON s.clinic_id=v.clinic_id AND s.slot_id=v.slot_id
  WHERE v.clinic_id='10000000-0000-4000-8000-000000000001'
    AND v.visit_id=md5('large-visit-' || s.slot_id)::uuid
    AND v.status='Completed'
), inserted AS (
  INSERT INTO queue_entry (queue_entry_id, visit_id, clinic_id, doctor_id, queue_date, queue_no, sequence_no,
    effective_time, arrived_at, called_at, started_at, completed_at, times_backfilled, backfilled_at, backfilled_by)
  SELECT md5('large-entry-' || visit_id)::uuid, visit_id, clinic_id, doctor_id, visit_date, seq, seq,
         start_at, start_at+interval '1 minute', start_at+interval '2 minutes',
         start_at+interval '3 minutes', start_at+interval '13 minutes',
         visit_date <> (clock_timestamp() AT TIME ZONE 'Africa/Addis_Ababa')::date,
         CASE WHEN visit_date <> (clock_timestamp() AT TIME ZONE 'Africa/Addis_Ababa')::date THEN clock_timestamp() END,
         CASE WHEN visit_date <> (clock_timestamp() AT TIME ZONE 'Africa/Addis_Ababa')::date
           THEN '10000000-0000-4000-8000-000000000010'::uuid END
  FROM selected ON CONFLICT (visit_id) DO NOTHING RETURNING visit_id
)
SELECT count(*) AS queue_entries_added FROM inserted;

INSERT INTO visit_event (event_id, clinic_id, visit_id, actor_user_id, event_key, message_key, is_read)
SELECT md5('large-event-' || v.visit_id)::uuid, v.clinic_id, v.visit_id,
       '10000000-0000-4000-8000-000000000012', 'seed.large_explain_fixture',
       'visit.' || lower(replace(v.status,' ','_')), false
FROM visit v WHERE v.clinic_id='10000000-0000-4000-8000-000000000001'
  AND v.visit_id=md5('large-visit-' || v.slot_id)::uuid
ON CONFLICT (event_id) DO NOTHING;

INSERT INTO activity_log (clinic_id, actor_user_id, action, target_type, target_id, reason)
SELECT v.clinic_id, '10000000-0000-4000-8000-000000000012', 'seed.large_visit', 'visit', v.visit_id::text,
       'Synthetic large planner fixture'
FROM visit v WHERE v.clinic_id='10000000-0000-4000-8000-000000000001'
  AND v.visit_id=md5('large-visit-' || v.slot_id)::uuid
  AND NOT EXISTS (SELECT 1 FROM activity_log a WHERE a.action='seed.large_visit' AND a.target_id=v.visit_id::text);

UPDATE doctor_day_queue q SET
  next_queue_no=GREATEST(q.next_queue_no,COALESCE((SELECT max(e.queue_no)+1 FROM queue_entry e
    WHERE e.clinic_id=q.clinic_id AND e.doctor_id=q.doctor_id AND e.queue_date=q.queue_date),1)),
  next_sequence_no=GREATEST(q.next_sequence_no,COALESCE((SELECT max(e.sequence_no)+1 FROM queue_entry e
    WHERE e.clinic_id=q.clinic_id AND e.doctor_id=q.doctor_id AND e.queue_date=q.queue_date),1))
WHERE q.clinic_id='10000000-0000-4000-8000-000000000001'
  AND (q.next_queue_no <= (SELECT max(e.queue_no) FROM queue_entry e WHERE e.clinic_id=q.clinic_id AND e.doctor_id=q.doctor_id AND e.queue_date=q.queue_date)
    OR q.next_sequence_no <= (SELECT max(e.sequence_no) FROM queue_entry e WHERE e.clinic_id=q.clinic_id AND e.doctor_id=q.doctor_id AND e.queue_date=q.queue_date));

ANALYZE clinic;
ANALYZE app_user;
ANALYZE doctor;
ANALYZE slot;
ANALYZE patient;
ANALYZE visit;
ANALYZE queue_entry;
ANALYZE visit_event;
ANALYZE activity_log;
