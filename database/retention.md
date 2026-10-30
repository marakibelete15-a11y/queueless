# QueueLess data retention and cleanup

All intervals below are operational behavior, not a legal retention determination. `retention.visits_days`, `retention.patients_days` and `retention.activity_log_days` are seeded as SQL `NULL`. Do not invent a duration: the clinic must set each after legal review. A database constraint trigger rejects setting `application_mode` to `pilot` while any retention value is NULL, and also rejects later clearing one while in pilot mode.

| Data | Cleanup rule |
| --- | --- |
| `rate_limit_counter` and its hashed IP/booking-reference keys | Delete rows whose `expires_at` is reached; set expiry no later than 24 hours after window start, per SRS NFR-4. The raw IP or booking reference is never stored in this table. |
| `session` | Delete after `expires_at`; enforce idle (30 minutes) and absolute (12 hours) expiry on each authenticated request. Expired session returns HTTP 401. |
| `visit.status_token` | Set an expiry 24 hours after a visit becomes final (`Completed`, `Cancelled`, or `No-Show`), then clear the token with `clear_expired_final_status_tokens()`. |
| Temporary passwords | Expire after 24 hours using `temp_password_expires_at`; require password change while `must_change_password` is true. |
| Backups | Daily backups, kept 14 days. `backup_policy` setting must retain the same schedule and duration. Backups must be protected and expired copies securely removed. |
| Visits, patients, activity log | Retention values remain NOT SET until clinic/legal review. A cleanup job only lists eligible rows; deletion requires an active administrator's persisted approval and `execute_retention_approval()` after the configured minimum age is met. |

`cleanup_expired_rate_limit_counters()` removes expired counters; ensure writers set `expires_at <= window_start + interval '24 hours'`. `cleanup_expired_sessions()` removes expired sessions. `clear_expired_final_status_tokens()` clears expired final status tokens. `apply_due_no_shows()` is the `noShowJob` database routine: it uses server time, skips locked rows, marks eligible appointments No-Show, increments visit version and appends event/audit rows. `queue_due_no_shows()` is a read-only candidate list. `ipCounterCleanup` invokes the rate-counter cleanup function. `retentionJob` runs the candidate listing below and requests administrator review; it never deletes records on its own.

## Administrator approval list

This lists old records for review only. Choose a category and cutoff based on the clinic's approved setting; this query is not a deletion command.

```sql
-- Candidate visit rows (repeat for patient or activity_log with its approved setting).
SELECT visit_id, clinic_id, patient_id, doctor_id, status, created_at
FROM visit
WHERE clinic_id = $1 AND created_at < $2
ORDER BY created_at
LIMIT 500;

-- Candidate patient rows with no remaining visit dependency.
SELECT p.patient_id, p.full_name, p.created_at
FROM patient p
WHERE p.clinic_id=$1 AND p.created_at<$2
  AND NOT EXISTS (SELECT 1 FROM visit v WHERE v.clinic_id=p.clinic_id AND v.patient_id=p.patient_id)
ORDER BY p.created_at LIMIT 500;

SELECT log_id, at, actor_user_id, action, target_type, target_id
FROM activity_log WHERE clinic_id=$1 AND at<$2 ORDER BY at LIMIT 500;
```

An active clinic administrator records `retention_approval` with category, eligible cutoff, reason and approval identity. The database trigger checks active administrator role. The application then runs `execute_retention_approval(approval_id)`; it verifies the configured retention window and an unexecuted approval. Visit cleanup first saves aggregate JSON counts by clinic/date/doctor (status names map to counts inside the JSON object) in `retention_visit_summary`, then removes dependent events and queue rows and visits in one transaction. Patient cleanup removes only old patients with no remaining visits. Activity-log deletion is allowed only within the approved security-definer routine; its append-only trigger blocks direct UPDATE/DELETE as a second layer. The routine appends an execution audit record and marks approval used. Anonymized/removal reporting retains only aggregate visit counts, never patient identity.

Expired or unknown status token responses must be identical to the generic “not found or expired” response used for an invalid `booking_ref`/phone pair. Do not reveal whether a token or booking reference exists. An expired session returns 401. Reports after approved visit removal use `retention_visit_summary` counts.

## Backup setting

`backup_policy` is seeded as `{"frequency":"daily","retention_days":14}`. Keep this value and the backup job aligned; do not set a different duration without a clinic-approved policy update. Backup retention is an operational setting and does not fill any of the legal visit/patient/audit retention values.
