# YX Protocol — Python Implementation

**Status**: ✅ Reference implementation complete (`canonical/python/`)
**Protocol spec**: [`../protocol/specs/`](../protocol/specs/)

## What This Is

The Python implementation of the YX protocol. It is the **reference implementation**
that generates canonical test vectors used by all other implementations.

## Structure

```
python/
├── specs/                    # Python-specific implementation specs
│   ├── technical/
│   │   ├── _BASE.md          # Python coding standards
│   │   └── ybs-spec_3f7a9c2e1b4d.md  # Module design & dependency decisions
│   └── testing/
│       ├── _BASE.md          # pytest standards
│       └── ybs-spec_8b2d5e9f1a3c.md  # Python testing strategy
└── steps/                    # YBS build steps
    ├── STEPS_ORDER.txt
    ├── ybs-step_000000000000.md    # Step 0: Python build configuration
    └── ybs-step_<guid>.md         # Steps 1-15
```

## Build Instructions

1. Start at the `yx/` project root
2. Execute Step 0: `python/steps/ybs-step_000000000000.md`
3. Follow the step sequence in `python/steps/STEPS_ORDER.txt`
4. Build output lands in `builds/<build_name>/`

## Canonical Reference

The completed reference implementation lives in `canonical/python/`.
It was promoted from `builds/python-impl/` after passing all verification criteria.

## Key Design Decisions

See `specs/technical/ybs-spec_3f7a9c2e1b4d.md` for Python-specific choices.
See `../protocol/specs/architecture/ybs-decisions.md` for protocol-level ADRs.
