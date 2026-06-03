-- Generated SQLite state schema for lead-code-synth-research.
CREATE TABLE IF NOT EXISTS runs (
  run_id TEXT PRIMARY KEY,
  run_state TEXT NOT NULL CHECK (run_state IN ('not_started','running','paused','recovering','stopped','completed','blocked')),
  execution_mode TEXT NOT NULL CHECK (execution_mode IN ('auto','manual')),
  kernel_scope TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  terminal_reason TEXT
);

CREATE TABLE IF NOT EXISTS participants (
  participant_id TEXT PRIMARY KEY,
  role TEXT NOT NULL,
  agent_id TEXT,
  active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS search_directions (
  search_direction_id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  status TEXT NOT NULL,
  description TEXT NOT NULL,
  research_requested INTEGER NOT NULL DEFAULT 0,
  operator_escalated INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(run_id) REFERENCES runs(run_id)
);

CREATE TABLE IF NOT EXISTS work_items (
  work_item_id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  search_direction_id TEXT NOT NULL,
  owner_participant_id TEXT NOT NULL,
  status TEXT NOT NULL,
  current_best_ref TEXT,
  created_mail_ref TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(run_id),
  FOREIGN KEY(search_direction_id) REFERENCES search_directions(search_direction_id)
);

CREATE TABLE IF NOT EXISTS attempts (
  attempt_id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  work_item_id TEXT NOT NULL,
  search_direction_id TEXT NOT NULL,
  participant_id TEXT NOT NULL,
  attempt_index INTEGER NOT NULL,
  outcome TEXT NOT NULL,
  evidence_ref TEXT,
  message_ref TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(run_id) REFERENCES runs(run_id),
  FOREIGN KEY(work_item_id) REFERENCES work_items(work_item_id)
);

CREATE TABLE IF NOT EXISTS current_best (
  run_id TEXT PRIMARY KEY,
  candidate_ref TEXT NOT NULL,
  promoted_by TEXT NOT NULL,
  timing_ref TEXT NOT NULL,
  correctness_ref TEXT NOT NULL,
  evidence_ref TEXT NOT NULL,
  promoted_at TEXT NOT NULL,
  FOREIGN KEY(run_id) REFERENCES runs(run_id)
);

CREATE TABLE IF NOT EXISTS mail_payloads (
  payload_id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  schema_id TEXT NOT NULL,
  sender TEXT NOT NULL,
  receiver TEXT NOT NULL,
  handoff_id TEXT NOT NULL,
  status TEXT NOT NULL,
  message_ref TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(run_id) REFERENCES runs(run_id)
);

CREATE TABLE IF NOT EXISTS operator_intent_events (
  event_id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  intent_kind TEXT NOT NULL,
  decision TEXT,
  message_ref TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(run_id) REFERENCES runs(run_id)
);

CREATE TABLE IF NOT EXISTS generic_events (
  event_id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  actor TEXT NOT NULL,
  event_kind TEXT NOT NULL,
  entity_ref TEXT,
  message_ref TEXT,
  artifact_ref TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(run_id) REFERENCES runs(run_id)
);
