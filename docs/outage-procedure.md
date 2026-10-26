# QueueLess Offline Outage & Recovery Procedure

## 1. Purpose

In low-connectivity healthcare facilities or during unexpected power/network outages, clinic operations must continue seamlessly on paper tokens or local offline log sheets. This document defines the protocol for handling downtime and subsequent digital backfill.

## 2. Operating During an Outage (Offline Fallback)

1. **Reception Protocol**:
   - Reception staff switch to pre-printed physical queue cards stamped with current clinic date.
   - Record patient arrival time, doctor assignment, and physical token ID on the offline emergency ledger (`docs/templates/offline-ledger-template.pdf`).
2. **Consultation Protocol**:
   - Doctors record call time, start time, and completion time on the patient visit slip.
3. **Queue Board Notice**:
   - If digital display fails, switch to manual magnetic/chalk queue board displaying active token numbers.

## 3. Post-Outage Recovery (Digital Backfill)

Once connectivity and system power are restored:

1. **System Health Verification**:
   - Verify server status via `GET /api/v1/health`.
   - Verify database synchronization via `npm run migrate`.
2. **Access Backfill Portal**:
   - Authenticated staff with `receptionist` or `admin` roles navigate to `/staff/backfill.html`.
3. **Data Entry Requirements**:
   - Enter retrospective visits using `/api/v1/admin/backfill`.
   - All backfill records require:
     - Original actual arrival timestamp (converted to UTC).
     - Actual consultation duration.
     - Staff user ID responsible for backfill.
     - Outage incident identifier.
4. **Audit Log Verification**:
   - Verify append-only entries in `activity_log` under event type `VISIT_BACKFILLED`.
