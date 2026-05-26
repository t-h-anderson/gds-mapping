# MATLAB Style Guide

Conventions for writing MATLAB across our projects. Distilled from `AppStatusStack` (modern reference) and `eds-matlab`. Where the two diverge, the modern style wins for new code.

## 1. Project layout

```
src/
  +pkg/                  ← top-level namespace
    +subpkg/             ← nest by domain, not by file type
      MyClass.m
      myFunction.m
  Main.m                 ← thin entry points at src root
test/
  +test/
    +unit/               ← mirrors src/ namespacing under here
      +pkg/+subpkg/
        tMyClass.m       ← one test file per unit, "t" prefix
    +system/             ← cross-module / integration tests, same mirror
      +pkg/+subpkg/
        tMyClass.m       ← only when system-level coverage is needed
doc/                     ← markdown only, no generated HTML
deploy/                  ← packaging scripts, .prj artefacts
MyProject.prj            ← canonical project file at repo root
```

Rules:
- Group by **domain** (`+statusMgr`, `+eds`, `+fortran`), not by kind (`+utils`, `+helpers` are smells).
- No `private/` folders. Encapsulate with `SetAccess = protected` instead — it survives refactors better.
- Tests live in a sibling `test/` tree, never alongside source. Mirror the `src/` package path under `+test/+unit/` (always) and `+test/+system/` (when warranted).
- For `src/+pkg/+subpkg/MyClass.m` the unit test lives at `test/+test/+unit/+pkg/+subpkg/tMyClass.m` and the system test, if any, at `test/+test/+system/+pkg/+subpkg/tMyClass.m`.
- `resources/` is reserved for MATLAB project files. Put shipped templates, fixtures, and icons elsewhere (e.g. `templates/`, `test/fixtures/`).

## 2. Naming

| Kind | Style | Example |
|---|---|---|
| Class | `PascalCase` | `Stack`, `StatusType` |
| Function (.m) | `camelCase` | `prepFile`, `extractComponents` |
| Local variable | `camelCase` | `progressDlg`, `cleanupObj` |
| Property | `PascalCase` | `IsComplete`, `MessageShort` |
| Constant | `UPPER_SNAKE` inside a constants struct/class | `NLOAD`, `RAD`, `DEG` |
| Package | `lowercase`, prefixed `+` | `+statusMgr`, `+gev` |
| Enum member | `PascalCase` | `StatusType.Info` |
| Test file | `t` + unit name | `tFileLog.m` |
| Test method | `t` + behaviour | `tDefaultValues`, `tDisplayInfo` |

Do **not** use Hungarian prefixes (`i_`, `m_`, capital-`I`-for-interface). Type information lives in `arguments` blocks.

`snake_case` is reserved for adapter shims wrapping legacy Fortran/C names — keep the original symbol so cross-referencing the upstream source stays trivial.

## 3. Function & method signatures

Every public function and method declares an `arguments` block. No exceptions for new code.

```matlab
function [status, cleanupObj] = addStatus(objs, type, nvp)
    arguments
        objs (1,:) statusMgr.Stack
        type (1,1) statusMgr.StatusType = statusMgr.StatusType.Info
        nvp.Identifier (1,1) string = ""
        nvp.Message    (1,1) string = ""
    end
    ...
end
```

Rules:
- Positional args first (≤3), then a single `nvp` struct for everything else.
- Always declare size **and** class: `(1,1) string`, `(1,:) double`, `(:,:) myPkg.Thing`.
- Defaults belong in the `arguments` block, never in the body.
- Use validation functions (`{mustBePositive}`, `{mustBeMember(x,["a","b"])}`, `{mustBeScalarOrEmpty}`) over hand-rolled checks.
- Output names describe the value, not the type (`status`, not `outStruct`).

## 4. Strings, numbers, collections

- **`string` everywhere.** Char arrays (`'...'`) only for interop with functions that demand them (`sprintf` format strings, some toolbox APIs).
- Build string arrays with `[]`, not `{}`: `msgs = ["a"; "b"; "c"]`.
- Prefer structs and string-keyed structs to `containers.Map`. Reach for `dictionary` only when keys are dynamic and large.
- Numeric defaults are typed: `(1,1) double = 0`, not `= 0`.

## 5. Object-oriented patterns

- **Value class** for plain data (`LOADS`, parameter bundles, DTOs).
- **Handle class** for anything with identity, observers, or lifecycle (`Stack`, `Status`, UI controllers).
- Properties default to `SetAccess = protected`. Public set access is opt-in and rare.
- Use `SetObservable` deliberately — it enables `waitfor` / `listener`. Document the reason at the property.
- Events declared `(NotifyAccess = protected)`; fire via `notify(obj, "EventName")`.
- Abstract base classes use the `Abstract` modifier and live next to their concrete subclasses. We do not use a capital-`I` interface convention.
- Close blocks with trailing comments only for long classdefs: `end % methods`, `end % classdef`.

## 6. Resource lifecycle

- Reach for `onCleanup` whenever a function acquires a resource (file handle, dialog, transient state). It survives `error` and early `return`.
- Use `matlab.lang.WeakReference` when a closure or child object needs to refer back to its owner — avoids GC cycles on handle classes.
- When iterating to release handles, guard each element in `try/catch`; handle-array teardown is order-sensitive.

## 7. Errors

- `error("pkg:unit:reason", "Human message: %s", detail)` — always with a colon-delimited identifier matching the package path.
- `try/catch` is for **converting** errors (rethrowing as a different identifier, wrapping in a status object), not for swallowing them.
- Wrap caught exceptions in `MException` directly; we do not maintain a custom exception hierarchy.
- `assert` is reserved for invariants inside a function. Boundary validation belongs in `arguments`.

## 8. Comments

- One-line header on every function/class summarising the role. Skip the auto-generated `% MYFUNC ...` template if it adds nothing.
- Inline comments explain **why**, not **what**. If you find yourself describing what a line does, rename the variable instead.
- `%% Section` markers are for tests and scripts only. Production `.m` files don't need them — that's what folders and classes are for.
- No tag comments referencing PRs, tickets, or "added for X". Those rot.

## 9. Tests

- Framework: `matlab.unittest` (`matlab.uitest.TestCase` for app/UI tests). Never script-style tests.
- File `tFoo.m` tests unit `Foo`. Method `tBehaviour` describes one behaviour.
- Unit tests live under `test/+test/+unit/` mirroring the source package path; system tests under `test/+test/+system/` likewise.
- Use built-in fixtures (`WorkingFolderFixture`, `PathFixture`) rather than `addpath`/`cd` in `setup`.
- Parameterise with `properties (TestParameter)`; one struct field per case.
- For function shadowing / mocking, use the `MockedFunctionFixture` pattern (see `eds-matlab/test`) — don't monkey-patch by hand.
- `TestClassSetup` for expensive one-off work; `TestMethodSetup` for per-test isolation.

## 10. Config & entry points

- App config lives in `config.json` at the repo root, with `config.template.json` checked in. Load via a single `getConfig` helper that fails loudly when the file is missing.
- One `.prj` file per repo, at the root, named after the project.
- Keep `src/Main.m` (or equivalent) under ~30 lines: parse args, build the top-level object, hand off.

## 11. Things we don't do

- `global` variables.
- `eval`, `evalin`, `assignin` outside of test fixtures.
- `clear all` / `close all` / `clc` in committed code.
- Suppressing warnings without a comment explaining which warning and why.
- Re-exporting symbols just to shorten an import path — use the full package name.
