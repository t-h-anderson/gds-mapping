MATLAB Style Guide
Conventions for writing MATLAB across our projects. Distilled from `AppStatusStack` (modern reference), and the MathWorks MATLAB Coding Guidelines v1.0 (2025-04-30). Where any of these diverge, the rules below win for our code.
1. Project layout
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
Group by domain (`+statusMgr`, `+table`), not by kind (`+utils`, `+helpers` are smells).
No `private/` folders. Encapsulate with `SetAccess = protected` instead — it survives refactors better.
Tests live in a sibling `test/` tree, never alongside source. Mirror the `src/` package path under `+test/+unit/` (always) and `+test/+system/` (when warranted).
For `src/+pkg/+subpkg/MyClass.m` the unit test lives at `test/+test/+unit/+pkg/+subpkg/tMyClass.m` and the system test, if any, at `test/+test/+system/+pkg/+subpkg/tMyClass.m`.
`resources/` is reserved for MATLAB project files. Put shipped templates, fixtures, and icons elsewhere (e.g. `templates/`, `test/fixtures/`).
2. Naming
Kind	Style	Example
Class	`PascalCase`	`Stack`, `StatusType`
Function (.m)	`camelCase`	`prepFile`, `extractComponents`
Local variable	`camelCase`	`progressDlg`, `cleanupObj`
Property	`PascalCase`	`IsComplete`, `MessageShort`
Constant	`UPPER_SNAKE` inside a constants struct/class	`NLOAD`, `RAD`, `DEG`
Package	`lowercase`, prefixed `+`	`+statusMgr`
Enum member	`PascalCase`	`StatusType.Info`
Test file	`t` + unit name	`tFileLog.m`
Test method	`t` + behaviour	`tDefaultValues`, `tDisplayInfo`
Rules:
Do not use Hungarian prefixes (`i_`, `m_`, capital-`I`-for-interface). Type information lives in `arguments` blocks.
`snake_case` is reserved for adapter shims wrapping legacy Fortran/C names — keep the original symbol so cross-referencing the upstream source stays trivial.
Acronyms: treat them as words. In `camelCase`, the acronym at the start is fully lowercase and the next word's first letter capitalises normally (`htmlWrite`, not `htmlwrite` or `HTMLWrite`). Mid-name, either `createURL` or `createUrl` is acceptable — pick one per project and stay consistent.
Length cap: identifiers (variables, functions, classes, methods, properties) ≤ 32 characters. If you need more, you're describing the implementation, not the role — refactor.
Avoid shadowing names already on the MATLAB path (`sin`, `rand`, `sqrt`, etc.).
`UPPER_SNAKE_CASE` for constants is a deliberate deviation from the MathWorks "no underscores" rule. It makes constants visibly distinct from variables at the call site (`Constants.NLOAD` vs `nload`).
3. Function & method signatures
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
Positional args first (≤3), then a single `nvp` struct for everything else.
Always declare size and class: `(1,1) string`, `(1,:) double`, `(:,:) myPkg.Thing`.
Defaults belong in the `arguments` block, never in the body.
Use validation functions (`{mustBePositive}`, `{mustBeMember(x,["a","b"])}`, `{mustBeScalarOrEmpty}`) over hand-rolled checks.
Output names describe the value, not the type (`status`, not `outStruct`).
Output count ≤ 4. If you need more, return a struct or a value class.
`end` on every function, including local functions and nested ones. Implicit-end form is forbidden for new code.
Name-value names use `UpperCamelCase` (`LineWidth`, not `lineWidth`). Pass them with `Name=Value` syntax at call sites, not `"Name", Value`.
4. Strings, numbers, collections
`string` everywhere. Char arrays (`'...'`) only for interop with functions that demand them (`sprintf` format strings, some toolbox APIs).
Build string arrays with `[]`, not `{}`: `msgs = ["a"; "b"; "c"]`.
Prefer structs and string-keyed structs to `containers.Map`. Reach for `dictionary` only when keys are dynamic and large.
Numeric defaults are typed: `(1,1) double = 0`, not `= 0`.
Never `==` or `~=` on floating-point. Use `abs(a - b) < tol` or `isapprox` (R2024b+). Integer comparisons with `==` are fine.
Write floating-point literals with a leading zero: `0.1`, not `.1`.
5. Object-oriented patterns
Value class for plain data (`LOADS`, parameter bundles, DTOs).
Handle class for anything with identity, observers, or lifecycle (`Stack`, `Status`, UI controllers).
Properties default to `SetAccess = protected`. Public set access is opt-in and rare.
Use `SetObservable` deliberately — it enables `waitfor` / `listener`. Document the reason at the property.
Events declared `(NotifyAccess = protected)`; fire via `notify(obj, "EventName")`.
Abstract base classes use the `Abstract` modifier and live next to their concrete subclasses. We do not use a capital-`I` interface convention.
Avoid `Sealed`. Default is unsealed. Only seal a class when there is a concrete reason (custom indexing semantics, security boundary). Sealed-by-default is a refactor tax we don't want to pay.
Validate properties through the property block's size/class/`{mustBe…}` validators, not through a `set.Foo` method. Reserve `set.Foo` methods for transformation, not validation.
Avoid `get.Foo` methods for non-dependent properties. Dependent properties only when (a) the value is computed from other properties, (b) backward compatibility demands an alias, or (c) the get triggers a deliberate side effect.
Close blocks with trailing comments only for long classdefs: `end % methods`, `end % classdef`.
6. Loops & control flow
Don't grow arrays in a loop. Preallocate with `zeros`, `strings`, `repmat(seed, 1, n)`, or `createArray`. For complex classes where the "seed" instance is awkward to construct, collect into a cell array and concatenate at the end:
```matlab
  tmp = cell(1, n);
  for k = 1:n
      tmp{k} = MyClass(...);
  end
  result = [tmp{:}];
  ```
This is often faster than `repmat`-then-overwrite for non-trivial constructors.
Don't modify the loop iterator inside a `for` loop body. If you need to skip or reorder, use a `while` loop or filter the data first.
`switch` always has an `otherwise` branch. If `otherwise` is unreachable by construction, leave a one-line comment saying why.
Prefer early `return`/`continue` to deeper nesting. Guard clauses at the top of a function are clearer than wrapping the body in `if good then ... else error end`. We diverge from MathWorks here: their rule "minimise `break`/`continue`/`return`" pushes code into nested pyramids; ours doesn't.
Limit nesting of loops and conditionals to 5 levels. If you hit that, extract a helper.
7. Resource lifecycle
Reach for `onCleanup` whenever a function acquires a resource (file handle, dialog, transient state). It survives `error` and early `return`.
Use `matlab.lang.WeakReference` when a closure or child object needs to refer back to its owner — avoids GC cycles on handle classes.
When iterating to release handles, guard each element in `try/catch`; handle-array teardown is order-sensitive.
8. Errors
`error("pkg:unit:reason", "Human message: %s", detail)` — always with a colon-delimited identifier matching the package path.
`try/catch` is for converting errors (rethrowing as a different identifier, wrapping in a status object), not for swallowing them. An empty catch block needs a comment explaining why.
Wrap caught exceptions in `MException` directly; we do not maintain a custom exception hierarchy.
`assert` is reserved for invariants inside a function. Boundary validation belongs in `arguments`.
`throwAsCaller` is allowed — and preferred — in validation wrappers where the public method should appear as the error origin. We diverge from MathWorks here.
Error messages: state the problem, then the fix where one exists. `"RelTol must be a nonnegative scalar"` not `"bad arg"`.
9. Comments
Public-facing functions (`run`, `launch`, anything users call directly) get a help block: one-line H1 line, then inputs and outputs. Internal functions get a single one-line header if anything.
Inline comments explain why, not what. If you find yourself describing what a line does, rename the variable instead.
`%% Section` markers are for tests and scripts only. Production `.m` files don't need them — that's what folders and classes are for.
No tag comments referencing PRs, tickets, or "added for X". Those rot.
10. Tests
Framework: `matlab.unittest` (`matlab.uitest.TestCase` for app/UI tests). Never script-style tests.
File `tFoo.m` tests unit `Foo`. Method `tBehaviour` describes one behaviour.
Unit tests live under `test/+test/+unit/` mirroring the source package path; system tests under `test/+test/+system/` likewise.
Use built-in fixtures (`WorkingFolderFixture`, `PathFixture`) rather than `addpath`/`cd` in `setup`.
Parameterise with `properties (TestParameter)`; one struct field per case.
For function shadowing / mocking, use the `MockedFunctionFixture` pattern (see `matlab/test`) — don't monkey-patch by hand.
`TestClassSetup` for expensive one-off work; `TestMethodSetup` for per-test isolation.
11. Config & entry points
App config lives in `config.json` at the repo root, with `config.template.json` checked in. Load via a single `getConfig` helper that fails loudly when the file is missing.
One `.prj` file per repo, at the root, named after the project.
Keep `src/Main.m` (or equivalent) under ~30 lines: parse args, build the top-level object, hand off.
12. Formatting & whitespace
Indentation: 4 spaces, never tabs.
Line length ≤ 120 characters. Break long lines after a comma, after a space, or at a binary operator.
One statement per line.
No trailing whitespace.
One space either side of binary operators (`=`, `<`, `>=`, `&&`, `||`, `+`, `-`, etc.). We diverge from MathWorks here: their "spaces around `+`/`-` only on main terms" rule is too subjective to enforce. Pick consistency.
No spaces around `=` in `Name=Value` syntax: `plot(x, y, LineWidth=2)`.
No spaces around `*`, `/`, `\`, `^` and their element-wise variants.
No spaces around the colon operator: `2:2:10`, not `2 : 2 : 10`.
No spaces immediately inside `(...)`, `[...]`, `{...}`.
Space after `,` and `;` except at end of line.
One blank line between local functions, between method declarations, and between separate method/property blocks in a `classdef`. No blank lines at the start or end of a file.
No alignment padding. One space between identifier, size, type, and default. Aligning columns with extra spaces creates noisy diffs every time a longer name is added.
```matlab
  % Yes
  Signals (1,:) tmp.SimulinkSignal = tmp.SimulinkSignal.empty(1,0)
  Results (1,:) tmp.MappingResult = tmp.MappingResult.empty(1,0)
  RulesPath (1,1) string = ""

  % No — padded for column alignment
  Signals   (1,:) tmp.SimulinkSignal = ...
  Results   (1,:) tmp.MappingResult       = ...
  RulesPath (1,1) string = ""
  ```
Size tuples are tight: `(1,1)`, `(1,:)`, `(:,:)`, `empty(1,0)` — no spaces after the comma inside size specifiers. (The general "space after comma" rule applies to function argument lists and array literals, not to size tuples.)
13. Things we don't do
`global` variables.
`eval`, `evalin`, `assignin` outside of test fixtures.
`clear all` / `close all` / `clc` in committed code.
Suppressing warnings without a comment explaining which warning and why.
Re-exporting symbols just to shorten an import path — use the full package name.
`Sealed` classes by default — only when justified (see §5).
`varargin`/`varargout` to fake name-value arguments — use a proper `arguments` block.
Command-form syntax (`load foo.mat`, `clear x`) inside functions or methods; functional form only.
`addpath`/`rmpath` inside functions without resetting on exit (use `onCleanup`).
