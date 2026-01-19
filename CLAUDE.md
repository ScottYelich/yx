# AI Agent Guide for YX System

## System Overview

**System Name:** YX
**Type:** UDP-based networking protocol
**Purpose:** Secure, payload-agnostic transport layer for distributed systems

## Session Management

**IMPORTANT:** At startup, check for session files in `scratch/`:
- `scratch/SESSION.md` - Contains crash recovery state and context
- If found: Read and resume from saved state
- If not found: Start fresh session

All session files and temporary notes are kept in `scratch/` directory.

## YBS Build Instructions

This is a YBS (Yelich Build System) managed system. Follow these steps:

### 1. Understand the System

Read the specifications in order:
- `specs/technical/yx-protocol-spec.md` - Core protocol specification
- Additional specs as they are created

### 2. Execute the Build

1. **Check for crash recovery:**
   - Look for `SESSION.md` in the target build directory
   - If found, resume from the saved state

2. **Execute Step 0 (Configuration):**
   - Check if `BUILD_CONFIG.json` exists in the build directory
   - If exists: Load configuration, skip questions
   - If not exists: Ask configuration questions, create BUILD_CONFIG.json

3. **Execute Steps 1-N autonomously:**
   - Read each step file from `steps/` in order (see `steps/STEPS_ORDER.txt`)
   - Replace all `{{CONFIG:key}}` placeholders with values from BUILD_CONFIG.json
   - Execute instructions
   - Run verification
   - Proceed automatically to next step (no prompts)

4. **Update status after each step:**
   - Update `BUILD_STATUS.md` with progress
   - Update `SESSION.md` for crash recovery
   - Create step-DONE file in `docs/build-history/`

### 3. Build Completion

The build is complete when:
- All steps have executed successfully
- All verification criteria pass
- BUILD_STATUS.md shows 100% complete
- All tests pass (if applicable)
- Traceability ≥80%

### 4. Important Rules

- **Always execute Step 0 first** - No exceptions
- **Never skip verification** - Run all verification checks
- **Retry failed steps** - Up to 3 attempts per step
- **Proceed autonomously** - No "ready for next step?" prompts
- **Maintain traceability** - All code must reference specifications
- **Update status files** - Keep BUILD_STATUS.md and SESSION.md current

## Path References

- **YBS Framework:** `../ybs/` (reference documentation)
- **AlgoTrader (example system):** `../sdts/scott/algotrader/`
- **Current system:** `/Users/scottyelich/stuff/algotrader25/2025/yx/`

## Notes

- YX protocol specification already written
- Build steps need to be created
- Multiple build targets possible: Python, Swift, Rust, Go, etc.
