# StellArb - Claude Code Configuration

AI-assisted development configuration for the Stellar Arbitrage project.

## Project Overview

StellArb is a massive multiplayer online strategy game bridging the fast-paced trading of *Dope Wars* with the logistical depth of *Eve Online* — without the spreadsheet fatigue.

**Key Documents:**
- [Product Requirements (PRD)](docs/PRD.md) — Full game design specification with success criteria

## Agents

### Codebase Research Agents
From [humanlayer/humanlayer](https://github.com/humanlayer/humanlayer):

| Agent | Purpose |
|-------|---------|
| `codebase-analyzer` | Deep analysis of how specific code works |
| `codebase-locator` | Find where files and components live |
| `codebase-pattern-finder` | Discover existing patterns to follow |
| `web-search-researcher` | External documentation and resource lookup |

### 37signals Rails Agents
From [ThibautBaissac/rails_ai_agents](https://github.com/ThibautBaissac/rails_ai_agents):

| Agent | Purpose |
|-------|---------|
| `api-agent` | API endpoint design and implementation |
| `auth-agent` | Authentication patterns and security |
| `caching-agent` | Caching strategies and implementation |
| `concerns-agent` | Shared concerns and mixins |
| `crud-agent` | Standard CRUD operations |
| `events-agent` | Event-driven architecture patterns |
| `implement-agent` | General implementation guidance |
| `jobs-agent` | Background job patterns |
| `mailer-agent` | Email and notification patterns |
| `migration-agent` | Database migrations and schema changes |
| `model-agent` | ActiveRecord models and relationships |
| `multi-tenant-agent` | Multi-tenancy patterns |
| `refactoring-agent` | Code refactoring strategies |
| `review-agent` | Code review and quality checks |
| `state-records-agent` | State machine patterns |
| `stimulus-agent` | Stimulus.js controller patterns |
| `test-agent` | Testing strategies and patterns |
| `turbo-agent` | Turbo Streams and Frames patterns |

## Commands

| Command | Purpose |
|---------|---------|
| `/research_codebase` | Document and explain existing code without suggesting changes. Creates research documents in `thoughts/shared/research/` |
| `/create_plan` | Interactive planning workflow to create detailed implementation plans in `thoughts/shared/plans/` |
| `/implement_plan` | Execute implementation plans phase by phase with verification checkpoints |

## Setup

Create a `thoughts/` directory structure in your project:
```bash
mkdir -p thoughts/shared/research thoughts/shared/plans
```

Use the commands in Claude Code:
```
/research_codebase
/create_plan
/implement_plan thoughts/shared/plans/2025-01-08-feature-name.md
```

## StellArb Development Philosophy

### Success Criteria Driven
Every feature in the PRD includes success criteria with:
- **Done when:** Checkboxes that can be verified
- **Measured by:** Specific metrics and verify commands
- **Fails if:** Pre-mortem conditions that must NOT happen
- **Verify with:** Commands to run for automated testing

### Procedural Generation
The game uses deterministic procedural generation:
- Same seed → same output, always
- Nothing stored until "realized" by player action
- All generation must be pure functions (no DB reads)

### CLI-First Interface
- VI-style keyboard navigation (j/k/Enter/Esc)
- <50ms render times
- Breadcrumb navigation for nested views

## Architecture Notes

**Tech Stack (Planned):**
- Ruby on Rails backend
- PostgreSQL with JSONB for procedural asset attributes
- Text-based CLI interface (no 3D rendering)
- WebSocket for real-time updates

**Key Systems:**
1. Procedural Generation Engine (Section 5.1)
2. Economy & Resources (Section 4)
3. UI Navigation (Section 16)
4. Data Persistence (Section 12)

## Philosophy

- **Research first**: Understand before changing
- **Plan before implementing**: Get alignment on approach
- **Phase-based implementation**: Incremental, verifiable progress
- **Human checkpoints**: Manual verification between phases
- **Success criteria**: Every feature must be testable

## Credits

- Base commands and research agents: [humanlayer/humanlayer](https://github.com/humanlayer/humanlayer)
- 37signals Rails agents: [ThibautBaissac/rails_ai_agents](https://github.com/ThibautBaissac/rails_ai_agents)
