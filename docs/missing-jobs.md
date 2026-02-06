# Missing Jobs & Real-Time Updates Gap Analysis

This document catalogs all scenarios in StellArb where automatic state transitions or real-time UI updates are missing, requiring users to manually refresh.

---

## Critical Gaps (High Priority)

### 1. Ship Arrivals
**File:** `app/models/ship.rb:478-491`

- **Problem:** `check_arrival!` method exists but is never called automatically
- **Fields:** `arrival_at`, `destination_system_id`, `pending_intent`
- **User Impact:** Ship stays "in_transit" after arrival time passes until page refresh
- **Fix Needed:**
  - Call `check_arrival!` on page load (before_action)
  - Add background job to process arrivals
  - Broadcast via Turbo Streams when ship arrives

### 2. Recruit Pool Expiration
**File:** `app/models/recruit.rb:54-96`

- **Problem:** Recruits expire but expiration isn't actively processed
- **Fields:** `available_at`, `expires_at`
- **User Impact:** Expired recruits shown in pool until refresh
- **Fix Needed:**
  - Filter expired recruits in queries (scopes exist but may not be used everywhere)
  - Broadcast pool updates via Turbo Streams

### 3. NPC Aging & Death
**File:** `app/models/hired_recruit.rb:280-351`

- **Problem:** Aging jobs exist but are NOT scheduled
- **Jobs:** `NpcAgingJob`, `NpcAgeProgressionJob`
- **Fields:** `age_days`, `lifespan_days`
- **User Impact:** NPCs never age, never retire, never die
- **Fix Needed:**
  - Schedule `NpcAgeProgressionJob` daily via Solid Queue
  - Schedule `NpcAgingJob` to process retirements/deaths

### 4. Pip Infestation Escalation
**File:** `app/jobs/pip_escalation_job.rb`

- **Problem:** Job exists but is NOT scheduled
- **Fields:** `Incident.resolved_at`
- **User Impact:** Pip infestations don't spread to adjacent assets
- **Fix Needed:**
  - Schedule `PipEscalationJob` on recurring interval

---

## Medium Priority Gaps

### 5. Building Construction Completion
**File:** `app/models/building.rb`

- **Problem:** No method to check/transition construction completion
- **Fields:** `construction_ends_at`, `status`
- **User Impact:** Building shows "under_construction" after completion time
- **Fix Needed:**
  - Create `check_construction_complete!` method
  - Call on page load or via background job
  - Broadcast completion via Turbo Streams

### 6. Recruiter Pool Rotation
**File:** `app/jobs/recruiter_refresh_job.rb`

- **Problem:** Only triggers on server boot, not recurring
- **Initializer:** `config/initializers/recruiter_refresh.rb`
- **User Impact:** Pool refreshes once on startup, then inconsistently
- **Fix Needed:**
  - Configure recurring Solid Queue task

---

## Views Without Auto-Update

These views display time-sensitive data but require manual refresh:

| View | Data Shown | Auto-Update? |
|------|------------|--------------|
| `ships/show.html.erb` | Arrival ETA countdown | No |
| `ships/index.html.erb` | Ship statuses, in-transit | No |
| `navigation/index.html.erb` | In-transit box with ETA | No |
| `buildings/show.html.erb` | Construction countdown | No |
| `buildings/index.html.erb` | Construction progress | No |
| `recruiters/index.html.erb` | Recruit expiration timers | No |

---

## Background Jobs Status

| Job | Purpose | Scheduled? |
|-----|---------|------------|
| `RecruiterRefreshJob` | Refresh recruit pool | Partial (boot only) |
| `NpcAgingJob` | Process retirements/deaths | NO |
| `NpcAgeProgressionJob` | Daily age increment | NO |
| `PipEscalationJob` | Spread pip infestations | NO |
| `PipInfestationJob` | Handle pip events | NO |

---

## Infrastructure Status

### ActionCable
- **Configured:** Yes (SolidCable adapter in `config/cable.yml`)
- **Channels Created:** None (`app/channels/` doesn't exist)
- **Status:** Ready but unused

### Turbo Streams
- **Partial Use:** Message unread badge broadcasts work
- **Missing:** No broadcasts for ships, buildings, recruits, navigation

---

## Schema Fields Needing Auto-Transition Logic

| Field | Model | Auto-Check Exists? |
|-------|-------|-------------------|
| `arrival_at` | Ship | No - `check_arrival!` uncalled |
| `expires_at` | Recruit | No |
| `available_at` | Recruit | No |
| `construction_ends_at` | Building | No - no method exists |
| `age_days` | HiredRecruit | No - job unscheduled |
| `lifespan_days` | HiredRecruit | No - job unscheduled |
| `resolved_at` | Incident | No - job unscheduled |
| `disabled_at` | Ship | No auto-enable |
| `disabled_at` | Building | No auto-enable |

---

## Summary

**Root Causes:**
1. Background jobs defined but not scheduled in Solid Queue
2. Check/transition methods exist but nothing calls them
3. ActionCable infrastructure unused
4. No Turbo Stream broadcasts for state changes

**Quick Wins (Minimal Effort):**
- Add `before_action` to call `check_arrival!` on navigation/ships controllers
- Filter expired recruits in all recruiter queries

**Full Solution:**
- Configure Solid Queue recurring tasks for all jobs
- Create ActionCable channels for Ships, Buildings, Recruits
- Add Turbo Stream broadcasts on state transitions
- Optionally: Add JavaScript countdown timers with auto-refresh
