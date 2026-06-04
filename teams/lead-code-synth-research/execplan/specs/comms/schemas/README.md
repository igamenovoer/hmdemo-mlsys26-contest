# Communication Schemas

## Purpose

This generated directory contains JSON Schema contracts for structured loop mail payloads.

## Contents

- `planning-cycle-start.schema.json`: Planner cycle start trigger payload.
- `optimization-assignment.schema.json`: Planner-to-Coder assignment payload.
- `coder-result.schema.json`: Coder-to-Synthesizer result payload.
- `research-request.schema.json`: managed-agent-to-Researcher request payload.
- `research-summary.schema.json`: Researcher reply payload.
- `synthesis-report.schema.json`: Synthesizer report payload for Evaluator and Planner.
- `evaluation-report.schema.json`: Evaluator-to-Planner evaluation payload.
- `failure-report.schema.json`: blocker failure payload to Planner.
- `gpu-wait-report.schema.json`: no-spare-GPU waiting payload to Planner.
- `operator-intervention.schema.json`: structured operator control payload.
