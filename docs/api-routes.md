# QueueLess REST API Specification

All endpoints are versioned under `/api/v1`.

## 1. Response Envelope

Successful responses follow standard JSON structure:

```json
{
  "success": true,
  "data": {},
  "timestamp": "2026-10-26T20:15:00.000Z"
}
```

Error responses:

```json
{
  "success": false,
  "error": {
    "code": "SLOT_UNAVAILABLE",
    "message": "The selected time slot has already been booked."
  },
  "timestamp": "2026-10-26T20:15:00.000Z"
}
```

## 2. API Groups

### Health & Diagnostics

- `GET /api/v1/health`: Basic liveness and readiness probe.

### Public Endpoints (`/api/v1/public`)

- `GET /api/v1/public/doctors`: Retrieve active doctors and specialties.
- `GET /api/v1/public/slots`: Query available appointment slots for a doctor on a specific date.
- `POST /api/v1/public/bookings`: Book an appointment (enforces rate limiting and idempotency).
- `GET /api/v1/public/status/:reference`: Query real-time queue position and estimated arrival time.
- `POST /api/v1/public/cancel`: Cancel an appointment via booking reference and verification code.

### Authentication Endpoints (`/api/v1/auth`)

- `POST /api/v1/auth/login`: Staff login (returns session / secure cookie).
- `POST /api/v1/auth/logout`: Invalidate session.
- `GET /api/v1/auth/me`: Current session context and permissions.

### Queue Management (`/api/v1/queue`)

- `GET /api/v1/queue/board`: Public queue display feed (token numbers and status only).
- `GET /api/v1/queue/active`: Staff active queue dashboard.
- `POST /api/v1/queue/call-next`: Advance queue to next waiting patient.
- `POST /api/v1/queue/mark-no-show`: Mark patient as no-show after grace period.
- `POST /api/v1/queue/transfer`: Transfer patient to another doctor or triage stage.

### Visits & Patient Triage (`/api/v1/visits`)

- `POST /api/v1/visits/walkin`: Register unscheduled walk-in patient.
- `POST /api/v1/visits/checkin`: Check in booked patient on arrival.
- `PATCH /api/v1/visits/:id/complete`: Complete consultation.

### Administration (`/api/v1/admin`)

- `GET /api/v1/admin/clinic`: Clinic metadata and operating hours.
- `PUT /api/v1/admin/clinic`: Update clinic configuration.
- `GET /api/v1/admin/doctors`: Doctor roster administration.
- `POST /api/v1/admin/doctors`: Create doctor profile and schedule templates.
- `POST /api/v1/admin/backfill`: Retrospective entry of visits during offline outages.

### Reports & Audit Logs (`/api/v1/reports`)

- `GET /api/v1/reports/queue-analytics`: Daily throughput, average wait times, no-show rate.
- `GET /api/v1/reports/activity-log`: Query append-only audit trail (sanitized, no PII).
