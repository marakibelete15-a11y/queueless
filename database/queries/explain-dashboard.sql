-- Run after both synthetic seeds on queueless_dev. The seed runs ANALYZE.
-- Small fixtures may legitimately use sequential scans; at 20,000 visits these predicates
-- should use the documented selective indexes. Clinic/date values are local to the demo clinic.

-- 1. Queue board: doctor-day queue order (queue_entry_board_idx).
EXPLAIN (ANALYZE, BUFFERS)
WITH queue_params AS MATERIALIZED (
  SELECT '10000000-0000-4000-8000-000000000021'::uuid AS doctor_id,
         (clock_timestamp() AT TIME ZONE 'Africa/Addis_Ababa')::date AS queue_date
)
SELECT qe.queue_no, qe.sequence_no, qe.priority_flag, qe.effective_time, qe.arrived_at,
       v.status, p.full_name, d.name AS doctor_name
FROM queue_params qp
JOIN queue_entry qe ON qe.doctor_id=qp.doctor_id AND qe.queue_date=qp.queue_date
JOIN visit v ON v.clinic_id=qe.clinic_id AND v.visit_id=qe.visit_id
JOIN patient p ON p.clinic_id=v.clinic_id AND p.patient_id=v.patient_id
JOIN doctor d ON d.clinic_id=qe.clinic_id AND d.doctor_id=qe.doctor_id
ORDER BY qe.priority_flag DESC, qe.effective_time, qe.sequence_no;

-- 2. Dashboard status counts for all doctors today (visit_dashboard_day_idx).
EXPLAIN (ANALYZE, BUFFERS)
WITH clinic_today AS MATERIALIZED (
  SELECT (SELECT clinic_id FROM clinic ORDER BY clinic_id LIMIT 1) AS clinic_id,
         (clock_timestamp() AT TIME ZONE 'Africa/Addis_Ababa')::date AS visit_date
)
SELECT v.doctor_id, v.status, count(*) AS visits
FROM clinic_today t JOIN visit v ON v.clinic_id=t.clinic_id AND v.visit_date=t.visit_date
GROUP BY v.doctor_id, v.status;

-- 3. Available slots by doctor and clinic date; DB-1 partial unique index filters booked visits.
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.slot_id, s.start_at, s.end_at
FROM slot s
LEFT JOIN LATERAL (
  SELECT 1 AS booked
  FROM visit v
  WHERE v.slot_id=s.slot_id AND v.type='appointment' AND v.status <> 'Cancelled'
  LIMIT 1
) conflict ON true
WHERE s.doctor_id='10000000-0000-4000-8000-000000000021'
  AND s.start_at >= clock_timestamp()
  AND s.start_at < clock_timestamp()+interval '14 days'
  AND NOT s.is_blocked
  AND conflict.booked IS NULL
ORDER BY s.start_at;

-- 4. Public booking lookup (unique visit_booking_ref_uq).
EXPLAIN (ANALYZE, BUFFERS)
SELECT visit_id, status, visit_date, doctor_id
FROM visit WHERE booking_ref='A23456789B';

-- 5. Status page payload; invalid and expired tokens map to the same API response.
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.status, v.visit_date, v.status_token_expires_at, d.name AS doctor_name,
       p.full_name, qe.queue_no, qe.effective_time
FROM visit v JOIN doctor d ON d.clinic_id=v.clinic_id AND d.doctor_id=v.doctor_id
JOIN patient p ON p.clinic_id=v.clinic_id AND p.patient_id=v.patient_id
LEFT JOIN queue_entry qe ON qe.clinic_id=v.clinic_id AND qe.visit_id=v.visit_id
WHERE v.status_token='DEMO-C23456789D'
  AND (v.status_token_expires_at IS NULL OR v.status_token_expires_at > clock_timestamp());

-- 6. Recent completed, non-backfilled consultation duration sample (queue_entry_eta_idx).
EXPLAIN (ANALYZE, BUFFERS)
SELECT avg(extract(epoch FROM (completed_at-started_at))/60.0) AS mean_minutes
FROM (
  SELECT completed_at, started_at
  FROM queue_entry
  WHERE doctor_id='10000000-0000-4000-8000-000000000021'
    AND completed_at IS NOT NULL AND times_backfilled=false
  ORDER BY completed_at DESC LIMIT 20
) recent;

-- 7. Newest audit activity for the clinic (activity_log_newest_idx).
EXPLAIN (ANALYZE, BUFFERS)
SELECT at, actor_user_id, action, target_type, target_id, reason
FROM activity_log
WHERE clinic_id=(SELECT clinic_id FROM clinic ORDER BY clinic_id LIMIT 1)
ORDER BY at DESC LIMIT 50;

-- 8. Unread patient-visible events for a visit (visit_event_unread_idx).
EXPLAIN (ANALYZE, BUFFERS)
SELECT event_key, message_key, created_at
FROM visit_event
WHERE visit_id=(SELECT visit_id FROM visit WHERE booking_ref='C23456789D')
  AND is_read=false
ORDER BY created_at;
