-- Synthetic frontend fixtures only. Password shared by the three demo users:
-- QueueLessDemo2026! (bcrypt cost 12); rotate it before any non-local use.
INSERT INTO clinic (clinic_id, name, address, phone, timezone)
VALUES ('10000000-0000-4000-8000-000000000001', 'QueueLess Fictional Clinic',
        'Synthetic Addis Ababa demo location', '+251000000001', 'Africa/Addis_Ababa')
ON CONFLICT (clinic_id) DO NOTHING;

INSERT INTO app_user (user_id, clinic_id, username, email, display_name, password_hash, role)
VALUES
  ('10000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000001','demo.receptionist','receptionist@example.invalid','Demo Receptionist','$2b$12$2Zvo7jmqa5pRzQ.667CLB.XkCo5Aiy8qzjhTwTn6xEwoadp0L/Vz6','receptionist'),
  ('10000000-0000-4000-8000-000000000011','10000000-0000-4000-8000-000000000001','demo.doctor','doctor@example.invalid','Dr Synthetic One','$2b$12$2Zvo7jmqa5pRzQ.667CLB.XkCo5Aiy8qzjhTwTn6xEwoadp0L/Vz6','doctor'),
  ('10000000-0000-4000-8000-000000000012','10000000-0000-4000-8000-000000000001','demo.administrator','administrator@example.invalid','Demo Administrator','$2b$12$2Zvo7jmqa5pRzQ.667CLB.XkCo5Aiy8qzjhTwTn6xEwoadp0L/Vz6','administrator')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO doctor (doctor_id, clinic_id, user_id, name, specialty)
VALUES
  ('10000000-0000-4000-8000-000000000020','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000011','Dr Synthetic One','General practice (synthetic)'),
  ('10000000-0000-4000-8000-000000000021','10000000-0000-4000-8000-000000000001',NULL,'Dr Synthetic Two',NULL)
ON CONFLICT (doctor_id) DO NOTHING;

INSERT INTO clinic_setting (clinic_id, key, value, updated_by)
VALUES
  ('10000000-0000-4000-8000-000000000001','queue_timing',
   '{"grace_window_minutes":15,"no_show_deadline_minutes":30,"resume_grace_minutes":10,"staff_activity_guard_minutes":10,"call_timeout_minutes":5,"day_end_sweep_time":"23:59"}'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','booking_policy',
   '{"cancellation_cutoff_hours":2,"booking_window_days":14,"booking_limit_per_phone":3}'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','consultation_policy',
   '{"default_consultation_minutes":10,"sample_size":20,"minimum_sample":5,"minimum_duration_minutes":1,"maximum_duration_minutes":90}'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','authentication_policy',
   '{"login_failures":5,"lockout_minutes":15,"session_idle_minutes":30,"session_absolute_hours":12,"temporary_password_hours":24}'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','refresh_intervals',
   '{"public_seconds":15,"staff_seconds":10}'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','enabled_languages', '["en","am","om"]'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','emergency_contact_numbers',
   '["+251000000001","+251000000002"]'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','application_mode','{"mode":"demo"}'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','backup_policy',
   '{"frequency":"daily","retention_days":14}'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','rate_limit_policy',
   '{"hashed_key_retention_hours":24}'::jsonb,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','retention.visits_days',NULL,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','retention.patients_days',NULL,
   '10000000-0000-4000-8000-000000000012'),
  ('10000000-0000-4000-8000-000000000001','retention.activity_log_days',NULL,
   '10000000-0000-4000-8000-000000000012')
ON CONFLICT (clinic_id, key) DO NOTHING;

INSERT INTO doctor_schedule (schedule_id, clinic_id, doctor_id, title, weekday, start_time, end_time, slot_minutes)
SELECT md5('demo-schedule-' || d.doctor_id || '-' || day_no)::uuid,
       d.clinic_id, d.doctor_id, 'Weekday synthetic clinic hours', day_no, '09:00', '17:00', 30
FROM doctor d CROSS JOIN generate_series(1,5) AS day_no
WHERE d.clinic_id='10000000-0000-4000-8000-000000000001'
ON CONFLICT (schedule_id) DO NOTHING;

INSERT INTO slot (slot_id, clinic_id, doctor_id, schedule_id, title, start_at, end_at)
SELECT md5('demo-slot-' || d.doctor_id || '-' || clinic_day || '-' || slot_no)::uuid,
       d.clinic_id, d.doctor_id, s.schedule_id, 'Synthetic appointment slot',
       ((clinic_day + time '09:00' + slot_no * interval '30 minutes') AT TIME ZONE c.timezone),
       ((clinic_day + time '09:30' + slot_no * interval '30 minutes') AT TIME ZONE c.timezone)
FROM doctor d
JOIN clinic c USING (clinic_id)
CROSS JOIN generate_series(0,13) AS day_offset
CROSS JOIN generate_series(0,15) AS slot_no
CROSS JOIN LATERAL (SELECT ((clock_timestamp() AT TIME ZONE c.timezone)::date + day_offset) AS clinic_day) day
JOIN doctor_schedule s ON s.clinic_id=d.clinic_id AND s.doctor_id=d.doctor_id
  AND s.weekday=extract(dow FROM day.clinic_day)::smallint
WHERE d.clinic_id='10000000-0000-4000-8000-000000000001'
ON CONFLICT (doctor_id, start_at) DO NOTHING;

INSERT INTO doctor_day_queue (clinic_id, doctor_id, queue_date)
SELECT clinic_id, doctor_id, (clock_timestamp() AT TIME ZONE 'Africa/Addis_Ababa')::date
FROM doctor WHERE clinic_id='10000000-0000-4000-8000-000000000001'
ON CONFLICT (doctor_id, queue_date) DO NOTHING;

INSERT INTO patient (patient_id, clinic_id, full_name, phone, is_minor, contact_person_name)
SELECT md5('demo-patient-' || n)::uuid, '10000000-0000-4000-8000-000000000001',
       'Fictional Patient ' || lpad(n::text,2,'0'),
       '+251000' || lpad(n::text,6,'0'), n=2,
       CASE WHEN n=2 THEN 'Fictional Contact' ELSE NULL END
FROM generate_series(1,30) AS n
ON CONFLICT (patient_id) DO NOTHING;

WITH sample(ref, patient_no, doctor_no, slot_hour, slot_minute, state, reason) AS (
  VALUES
    ('A23456789B',1,1,11,0,'Booked',NULL::text),
    ('C23456789D',2,1,9,0,'Waiting',NULL::text),
    ('E23456789F',3,1,9,30,'Called',NULL::text),
    ('G23456789H',4,2,13,0,'In Consultation',NULL::text),
    ('J23456789K',5,2,13,30,'Completed',NULL::text),
    ('L23456789M',6,2,14,0,'Cancelled','STAFF_REQUEST'),
    ('N23456789P',7,2,14,30,'No-Show',NULL::text)
), today AS (
  SELECT (clock_timestamp() AT TIME ZONE 'Africa/Addis_Ababa')::date AS day
)
INSERT INTO visit (visit_id, clinic_id, patient_id, doctor_id, slot_id, type, status, booking_ref,
                   status_token, status_token_expires_at, booked_by, cancel_reason_code, visit_date)
SELECT md5('demo-visit-' || ref)::uuid, '10000000-0000-4000-8000-000000000001',
       md5('demo-patient-' || patient_no)::uuid,
       CASE doctor_no WHEN 1 THEN '10000000-0000-4000-8000-000000000020'::uuid ELSE '10000000-0000-4000-8000-000000000021'::uuid END,
       s.slot_id, 'appointment', state, ref, 'DEMO-' || ref,
       CASE WHEN state IN ('Completed','Cancelled','No-Show') THEN clock_timestamp()+interval '24 hours' END,
       '10000000-0000-4000-8000-000000000010',
       CASE WHEN state='Cancelled' THEN reason END, today.day
FROM sample x CROSS JOIN today
JOIN doctor d ON d.clinic_id='10000000-0000-4000-8000-000000000001' AND d.doctor_id=CASE doctor_no
  WHEN 1 THEN '10000000-0000-4000-8000-000000000020'::uuid ELSE '10000000-0000-4000-8000-000000000021'::uuid END
JOIN slot s ON s.clinic_id=d.clinic_id AND s.doctor_id=d.doctor_id
  AND s.start_at=(today.day + make_time(slot_hour,slot_minute,0)) AT TIME ZONE 'Africa/Addis_Ababa'
ON CONFLICT (visit_id) DO NOTHING;

INSERT INTO queue_entry (queue_entry_id, visit_id, clinic_id, doctor_id, queue_date, queue_no, sequence_no,
  effective_time, priority_flag, priority_reason, priority_set_at, skip_count, arrived_at, called_at,
  started_at, completed_at, times_backfilled, backfilled_at, backfilled_by)
SELECT md5('demo-entry-' || v.booking_ref)::uuid, v.visit_id, v.clinic_id, v.doctor_id, v.visit_date,
       row_number() OVER (PARTITION BY v.doctor_id ORDER BY v.booking_ref)::integer,
       row_number() OVER (PARTITION BY v.doctor_id ORDER BY v.booking_ref)::integer,
       clock_timestamp()-interval '45 minutes', v.status='Waiting',
       CASE WHEN v.status='Waiting' THEN 'Synthetic demo priority' END,
       CASE WHEN v.status='Waiting' THEN clock_timestamp()-interval '45 minutes' END,
       CASE WHEN v.status='Waiting' THEN 1 ELSE 0 END,
       clock_timestamp()-interval '40 minutes',
       CASE WHEN v.status IN ('Called','In Consultation','Completed') THEN clock_timestamp()-interval '30 minutes' END,
       CASE WHEN v.status IN ('In Consultation','Completed') THEN clock_timestamp()-interval '20 minutes' END,
       CASE WHEN v.status='Completed' THEN clock_timestamp()-interval '10 minutes' END,
       v.status='Waiting',
       CASE WHEN v.status='Waiting' THEN clock_timestamp() END,
       CASE WHEN v.status='Waiting' THEN '10000000-0000-4000-8000-000000000010'::uuid END
FROM visit v WHERE v.clinic_id='10000000-0000-4000-8000-000000000001'
  AND v.status IN ('Waiting','Called','In Consultation','Completed')
ON CONFLICT (visit_id) DO NOTHING;

UPDATE doctor_day_queue q SET
  next_queue_no=GREATEST(q.next_queue_no, COALESCE((SELECT max(e.queue_no)+1 FROM queue_entry e
    WHERE e.clinic_id=q.clinic_id AND e.doctor_id=q.doctor_id AND e.queue_date=q.queue_date),1)),
  next_sequence_no=GREATEST(q.next_sequence_no, COALESCE((SELECT max(e.sequence_no)+1 FROM queue_entry e
    WHERE e.clinic_id=q.clinic_id AND e.doctor_id=q.doctor_id AND e.queue_date=q.queue_date),1))
WHERE q.clinic_id='10000000-0000-4000-8000-000000000001';

INSERT INTO visit_event (event_id, clinic_id, visit_id, actor_user_id, event_key, message_key, is_read)
SELECT md5('demo-event-' || v.booking_ref)::uuid, v.clinic_id, v.visit_id,
       '10000000-0000-4000-8000-000000000010', 'visit.' || lower(replace(v.status,' ','_')),
       'visit.' || lower(replace(v.status,' ','_')), v.status='Completed'
FROM visit v WHERE v.clinic_id='10000000-0000-4000-8000-000000000001'
ON CONFLICT (event_id) DO NOTHING;

INSERT INTO clinic_notice (notice_id, clinic_id, kind, text)
VALUES ('10000000-0000-4000-8000-000000000100','10000000-0000-4000-8000-000000000001','emergency',
        'Emergency contact placeholders: +251000000001 / +251000000002. Fictional numbers; verify before use.')
ON CONFLICT (notice_id) DO NOTHING;

INSERT INTO activity_log (clinic_id, actor_user_id, action, target_type, target_id, reason)
SELECT '10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000012',
       'seed.synthetic_loaded','seed','001_synthetic_seed.sql','Synthetic local frontend fixtures only'
WHERE NOT EXISTS (SELECT 1 FROM activity_log WHERE clinic_id='10000000-0000-4000-8000-000000000001'
  AND action='seed.synthetic_loaded' AND target_id='001_synthetic_seed.sql');
