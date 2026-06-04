PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS control_state (
    run_id TEXT PRIMARY KEY,
    run_state TEXT NOT NULL CHECK (run_state IN ('not_started', 'running', 'paused', 'recovering', 'stopped')),
    execution_mode TEXT NOT NULL CHECK (execution_mode IN ('auto', 'manual')),
    plan_revision TEXT NOT NULL,
    operator_stop_requested INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS participants (
    participant_id TEXT PRIMARY KEY,
    role_id TEXT NOT NULL,
    managed_agent INTEGER NOT NULL,
    workspace_required INTEGER NOT NULL,
    mailbox_required INTEGER NOT NULL,
    workspace_ref TEXT,
    mailbox_ref TEXT,
    status TEXT NOT NULL DEFAULT 'planned'
);

CREATE TABLE IF NOT EXISTS planning_cycles (
    cycle_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    status TEXT NOT NULL CHECK (status IN ('planned', 'dispatching', 'collecting', 'synthesizing', 'evaluating', 'closed', 'deferred')),
    planner_id TEXT NOT NULL REFERENCES participants(participant_id),
    current_best_ref TEXT,
    continuation_decision TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS assignments (
    assignment_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    cycle_id TEXT NOT NULL REFERENCES planning_cycles(cycle_id),
    owner_participant_id TEXT NOT NULL REFERENCES participants(participant_id),
    coder_slot TEXT NOT NULL,
    direction TEXT NOT NULL,
    allowed_edit_surface TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('proposed', 'implementing', 'submitted', 'waiting_for_gpu', 'retry_pending', 'failed', 'synthesized', 'closed')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    current_best_ref TEXT,
    evidence_expectations TEXT,
    risk_notes TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS candidates (
    candidate_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    cycle_id TEXT NOT NULL REFERENCES planning_cycles(cycle_id),
    assignment_id TEXT REFERENCES assignments(assignment_id),
    source_participant_id TEXT REFERENCES participants(participant_id),
    project_cli_variant_ref TEXT NOT NULL,
    workspace_path TEXT NOT NULL,
    changed_files_summary TEXT,
    lineage_ref TEXT,
    status TEXT NOT NULL CHECK (status IN ('exploratory', 'submitted', 'synthesized', 'submitted_for_promotion', 'accepted_by_evaluator', 'rejected', 'current_best', 'preserved_idea')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS evidence_refs (
    evidence_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    candidate_id TEXT REFERENCES candidates(candidate_id),
    assignment_id TEXT REFERENCES assignments(assignment_id),
    producer_participant_id TEXT REFERENCES participants(participant_id),
    evidence_type TEXT NOT NULL,
    artifact_ref TEXT NOT NULL,
    summary TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS artifacts (
    artifact_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    artifact_type TEXT NOT NULL,
    path TEXT NOT NULL,
    owner_participant_id TEXT REFERENCES participants(participant_id),
    description TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS mail_payloads (
    payload_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    schema_id TEXT NOT NULL,
    schema_version TEXT NOT NULL,
    kind TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    receiver_id TEXT NOT NULL,
    route_id TEXT,
    entity_ref TEXT,
    status TEXT NOT NULL CHECK (status IN ('created', 'validated', 'rendered', 'sent', 'received', 'processed', 'archived', 'failed', 'repaired')),
    rendered_artifact_ref TEXT,
    mail_ref TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS attempts (
    attempt_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    assignment_id TEXT NOT NULL REFERENCES assignments(assignment_id),
    participant_id TEXT NOT NULL REFERENCES participants(participant_id),
    bounded_attempt_index INTEGER NOT NULL DEFAULT 1,
    local_check_status TEXT,
    gpu_selection_evidence_ref TEXT,
    commands_run_summary TEXT,
    stop_point TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS retry_records (
    retry_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    assignment_id TEXT REFERENCES assignments(assignment_id),
    participant_id TEXT REFERENCES participants(participant_id),
    blocker_type TEXT NOT NULL,
    retry_count INTEGER NOT NULL,
    evidence_ref TEXT,
    status TEXT NOT NULL CHECK (status IN ('retry_pending', 'failure_reported', 'resolved')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS waiting_for_gpu (
    wait_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    assignment_id TEXT REFERENCES assignments(assignment_id),
    participant_id TEXT REFERENCES participants(participant_id),
    blocked_action TEXT NOT NULL,
    attempted_gpu_selection_evidence_ref TEXT,
    next_wakeup_need TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('waiting', 'retrying', 'resolved', 'superseded')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS research_summaries (
    request_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    requester_id TEXT NOT NULL REFERENCES participants(participant_id),
    source_scope_used TEXT NOT NULL,
    local_refs TEXT,
    network_refs TEXT,
    summary_artifact_ref TEXT,
    risk_notes TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS profile_reports (
    profile_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    invoking_participant_id TEXT NOT NULL REFERENCES participants(participant_id),
    target_candidate_id TEXT REFERENCES candidates(candidate_id),
    target_workload TEXT,
    selected_gpu_evidence_ref TEXT,
    metrics_summary TEXT,
    bottleneck_attribution TEXT,
    artifact_ref TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS synthesis_reports (
    synthesis_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    cycle_id TEXT NOT NULL REFERENCES planning_cycles(cycle_id),
    selected_candidate_id TEXT REFERENCES candidates(candidate_id),
    project_cli_variant_ref TEXT,
    planner_context_only INTEGER NOT NULL DEFAULT 1,
    lineage_summary TEXT,
    preserved_ideas TEXT,
    evidence_bundle_ref TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS evaluation_reports (
    evaluation_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    candidate_id TEXT NOT NULL REFERENCES candidates(candidate_id),
    project_cli_variant_ref TEXT NOT NULL,
    decision TEXT NOT NULL CHECK (decision IN ('accepted', 'rejected')),
    official_timing_provenance TEXT,
    correctness_status TEXT NOT NULL,
    speedup_or_latency_summary TEXT,
    anti_hacking_review TEXT,
    rejection_reason TEXT,
    recommended_planner_followup TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS current_best_history (
    current_best_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    candidate_id TEXT NOT NULL REFERENCES candidates(candidate_id),
    evaluation_id TEXT NOT NULL REFERENCES evaluation_reports(evaluation_id),
    previous_best_ref TEXT,
    project_cli_variant_ref TEXT NOT NULL,
    written_by_participant_id TEXT NOT NULL REFERENCES participants(participant_id),
    written_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS operator_intent_events (
    operator_event_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES control_state(run_id),
    action TEXT NOT NULL,
    target_refs TEXT,
    rationale TEXT,
    applied_run_state TEXT,
    applied_execution_mode TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_assignments_cycle_status ON assignments(cycle_id, status);
CREATE INDEX IF NOT EXISTS idx_candidates_cycle_status ON candidates(cycle_id, status);
CREATE INDEX IF NOT EXISTS idx_mail_payloads_schema_status ON mail_payloads(schema_id, status);
CREATE INDEX IF NOT EXISTS idx_waiting_for_gpu_status ON waiting_for_gpu(status);
CREATE INDEX IF NOT EXISTS idx_retry_records_status ON retry_records(status);
