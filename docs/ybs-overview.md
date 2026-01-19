# YBS Framework Overview

## What YBS Does

YBS (Yelich Build System) is a framework for building software systems with AI agents.

**Core principle:** Specifications are the source of truth. Code is generated from specs.

**Key features:**
- AI agents build complete systems autonomously from written specifications
- Zero interruptions after initial configuration
- Full traceability: every line of code references its specification
- Reproducible builds: same specs + same steps = identical output
- Language and platform agnostic

---

## How It Works

### 1. Write Specifications (WHAT to build)

Create markdown files describing what the system should do:

```
specs/
├── technical/           # Architecture, APIs, data models
├── functional/          # Features, user workflows
├── business/            # Requirements, success metrics
└── testing/             # Test plans, acceptance criteria
```

### 2. Write Build Steps (HOW to build it)

Create sequential build steps as markdown files:

```
steps/
├── STEPS_ORDER.txt              # Execution order
├── ybs-step_000000000000.md     # Step 0: Configuration (always first)
├── ybs-step_<guid>.md           # Step 1: Project setup
├── ybs-step_<guid>.md           # Step 2: Core implementation
└── ...                          # More steps
```

Each step contains:
- **Objectives** - What this step accomplishes
- **Instructions** - Detailed commands and actions
- **Verification** - How to verify the step succeeded

### 3. Run Step 0 (Configuration)

Step 0 asks questions and creates `BUILD_CONFIG.json`:

```json
{
  "values": {
    "language": "Python",
    "enable_tests": true,
    "platform": "all"
  }
}
```

This config file enables fully autonomous execution of all remaining steps.

### 4. AI Agent Executes Steps 1-N

For each step, the AI agent:
1. Reads the step file
2. Replaces configuration placeholders with values from BUILD_CONFIG.json
3. Executes instructions
4. Runs verification checks
5. Proceeds automatically to next step (no prompts)

---

## Directory Structure

```
system-name/
├── README.md                    # System overview
├── CLAUDE.md                    # AI agent instructions
├── specs/                       # Specifications (WHAT)
│   ├── technical/
│   ├── functional/
│   └── testing/
├── steps/                       # Build steps (HOW)
│   ├── STEPS_ORDER.txt
│   ├── ybs-step_000000000000.md
│   └── ybs-step_<guid>.md
└── builds/                      # Build workspaces
    └── build-name/
        ├── BUILD_CONFIG.json    # Configuration values
        ├── BUILD_STATUS.md      # Progress tracking
        ├── [source code]        # Generated code
        └── [tests]              # Generated tests
```

---

## How to Use YBS

### As a Human

1. **Write specifications** describing what you want built
2. **Create build steps** describing how to build it
3. **Point an AI agent** at the system directory
4. **AI builds it autonomously** from your specs

### As an AI Agent

1. **Check for SESSION.md** in build directory (crash recovery)
2. **Execute Step 0** - Read BUILD_CONFIG.json or ask questions to create it
3. **Execute Steps 1-N sequentially:**
   - Read step file
   - Replace {{CONFIG:key}} with values
   - Execute instructions
   - Run verification
   - Proceed to next step
4. **Update status** in BUILD_STATUS.md after each step
5. **Mark complete** when all steps pass verification

---

## Key Concepts

### Configuration-First Design

Step 0 collects ALL decisions upfront. Steps 1-N run without asking questions.

If BUILD_CONFIG.json exists, Step 0 skips all questions and loads existing config.

### Verification-Driven Execution

Every step has explicit verification criteria:
- Commands that must succeed
- Files that must exist
- Tests that must pass
- Expected output patterns

AI agent verifies each step before proceeding.

### Traceability

Every source file references its specification:

```python
# Implements: calculator-spec.md § 2.1 (Core Operations)
def add(a, b):
    return a + b
```

This enables:
- Understanding WHY code exists
- Updating code when specs change
- Regenerating code from specs

### Crash Recovery

SESSION.md tracks progress. If interrupted, AI agent resumes from last checkpoint.

---

## Example: Calculator System

**Specs:** Define a CLI calculator with add, subtract, multiply, divide operations

**Steps:**
- Step 0: Collect configuration (language choice, enable tests)
- Step 1: Create project structure
- Step 2: Implement calculator module
- Step 3: Implement parser module
- Step 4: Implement CLI interface
- Step 5-7: Write tests
- Step 8: Write documentation
- Step 9: Final verification

**Result:** Complete, tested, documented calculator in chosen language

**Time:** ~3 hours of autonomous AI execution

---

## Core Value

**Write specifications once. AI agents build complete systems autonomously, in any language, with full traceability and reproducibility.**

YBS separates "what to build" (specs) from "how to build it" (steps) from "the built artifact" (code).

This enables:
- AI agents to build autonomously
- Specs to remain current
- Systems to be rebuilt in different languages
- Code to be regenerated from specs at any time
