<!-- SUBAGENT PROMPT

## Task: Implement Shared Code Architecture Fixes

You are implementing the "Recommended Approach: Layered Defense" from this document for the DailyCommuter project. Read this entire document for full context, then execute the steps below. You may deploy your own subagents for parallel work.

### Important constraints:
- The project's `ios/AGENTS.md` warns: do NOT modify `project.pbxproj` or `Info.plist` without explicit permission. You HAVE permission for the specific pbxproj changes described below (moving bridge files, adding build phase script, adding compilation condition).
- The `ctaTimes/` directory uses Xcode's `PBXFileSystemSynchronizedRootGroup`. Files there belong to `ctaTimesExtension` by default and are opted-in to `DailyCommuter` via membership exceptions. Understand this model before making changes.
- NEVER add `import React` or any React Native import to files in `ctaTimes/`.

### Step 1: Move FavoritesBridge out of ctaTimes/ (Solution 1)

**Goal:** Move `FavoritesBridge.swift` and `FavoritesBridge.m` from `ios/ctaTimes/App/` to `ios/DailyCommuter/Bridge/`.

**Filesystem changes:**
1. Create directory `ios/DailyCommuter/Bridge/`
2. Move `ios/ctaTimes/App/FavoritesBridge.swift` → `ios/DailyCommuter/Bridge/FavoritesBridge.swift`
3. Move `ios/ctaTimes/App/FavoritesBridge.m` → `ios/DailyCommuter/Bridge/FavoritesBridge.m`
4. Remove the now-empty `ios/ctaTimes/App/` directory

**project.pbxproj changes (this is the hard part — be precise):**
- The bridge files currently appear in TWO membership exception sets: one that ADDS them to `DailyCommuter`, and one that EXCLUDES them from `ctaTimesExtension`. Remove them from BOTH exception sets — they no longer live in the synced root group so exceptions don't apply.
- Add the two files as new `PBXFileReference` entries under the `DailyCommuter` group (not the ctaTimes synced group).
- Create a new `PBXGroup` for `Bridge/` under the `DailyCommuter` group containing both file references.
- Add both files to the `DailyCommuter` target's "Sources" build phase (`PBXSourcesBuildPhase`).
- Do NOT add them to the `ctaTimesExtension` target's build phase.

**No Swift/ObjC code changes needed.** The imports and types used in the bridge files are all available in the DailyCommuter target already.

**Verification:** After changes, grep the pbxproj for "FavoritesBridge" and confirm:
- No references in any `membershipExceptions` lists
- References exist in the DailyCommuter group and its Sources build phase
- No references in the ctaTimesExtension Sources build phase

### Step 2: Add APP_TARGET compilation condition (Solution 3, partial)

**Goal:** Add `APP_TARGET` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS` for the DailyCommuter target only.

**project.pbxproj changes:**
- Find the `DailyCommuter` target's build configurations (Debug and Release).
- In Debug: `SWIFT_ACTIVE_COMPILATION_CONDITIONS` should become `"$(inherited) DEBUG APP_TARGET"`
- In Release: `SWIFT_ACTIVE_COMPILATION_CONDITIONS` should become `"$(inherited) APP_TARGET"`
- Do NOT add this to the `ctaTimesExtension` target.

**No code changes needed yet** — this flag is for future use. Developers can use `#if APP_TARGET` when needed.

### Step 3: Add build phase validation script (Solution 6)

**Goal:** Add a "Run Script" build phase to `ctaTimesExtension` that catches forbidden React Native imports at build time.

**project.pbxproj changes:**
- Create a new `PBXShellScriptBuildPhase` entry for `ctaTimesExtension`.
- Name: `[Validate] No React imports in widget sources`
- Shell: `/bin/bash`
- Position: BEFORE the existing "Sources" compile phase in the ctaTimesExtension target's `buildPhases` array.
- Script: Use the script from Solution 6 in this document (the `find` + `grep` approach). Since Step 1 already moved FavoritesBridge out of `ctaTimes/`, no exclusions are needed.
- Set `alwaysOutOfDate = 1` (run every build, not just when inputs change).

### Step 4: Update documentation

- Update `CLAUDE.md` to mention:
  - FavoritesBridge now lives in `ios/DailyCommuter/Bridge/` (not `ctaTimes/App/`)
  - The `APP_TARGET` compilation condition is available for the DailyCommuter target
  - A build phase script validates no React imports exist in widget source files

### Execution order:
Steps 1, 2, and 3 all modify `project.pbxproj`. Read the file ONCE at the start, plan all changes, then apply them carefully. The pbxproj format is fragile — preserve exact whitespace and formatting patterns. Step 4 (docs) can be done in parallel.

### Verification:
After all changes, confirm:
- `FavoritesBridge.swift` and `.m` exist in `ios/DailyCommuter/Bridge/` and NOT in `ios/ctaTimes/App/`
- `grep -c "FavoritesBridge" ios/DailyCommuter.xcodeproj/project.pbxproj` shows the expected count (file refs + build phase entries, but no membershipExceptions)
- `grep "APP_TARGET" ios/DailyCommuter.xcodeproj/project.pbxproj` shows the compilation condition in DailyCommuter's build settings only
- `grep "No React imports" ios/DailyCommuter.xcodeproj/project.pbxproj` shows the build phase script exists

### Do NOT:
- Add `import React` to any file in `ctaTimes/`
- Change the widget extension's deployment target or bundle ID
- Run `expo prebuild`
- Commit changes (leave that to the user)

END SUBAGENT PROMPT -->

# Shared Code Architecture: App Target vs Widget Extension Target

## Problem Statement

The DailyCommuter project contains an Expo/React Native iOS app (`DailyCommuter` target) and a native WidgetKit extension (`ctaTimesExtension` target). Both targets compile Swift files from a shared directory, `ios/ctaTimes/`. This creates a fragile arrangement:

- **`FavoritesBridge.swift`** lives in `ios/ctaTimes/App/` and contains `import React` plus usage of `RCTPromiseResolveBlock` / `RCTPromiseRejectBlock`. The main app target links React Native and can compile this file. The widget extension target does **not** and **cannot** link React Native.
- The project uses Xcode's **PBXFileSystemSynchronizedRootGroup** for `ctaTimes/`, meaning all files in the directory are included in the `ctaTimesExtension` target **by default**. `FavoritesBridge.swift` and `FavoritesBridge.m` are listed as `membershipExceptions` to exclude them from the widget target, but this is invisible and easy to break.
- Developers and AI coding agents regularly add `import React` to files in this directory without realizing it will break the widget build.
- The widget extension has a deployment target of **iOS 18.4** vs the app's **iOS 15.1**, so availability of APIs differs and `#available` checks diverge between targets.

### Current Directory Layout

```
ios/
  DailyCommuter/                    # App-only files
    AppDelegate.swift               # import Expo, import React, import ReactAppDependencyProvider
    Info.plist
    ...
  DailyCommuter-Bridging-Header.h  # #import <React/RCTBridgeModule.h>
  ctaTimes/                         # Shared directory (synced root group)
    App/
      FavoritesBridge.swift         # import React  (PROBLEM FILE)
      FavoritesBridge.m             # #import <React/RCTBridgeModule.h>
    Core/
      Models/                       # Favorite, FavoriteDTO, Arrival, etc.
      Networking/                   # CTAService protocol + CTAServiceLive
      Persistence/                  # SharedStore (App Group JSON)
      Utilities/                    # Arrivals+Refresh, Logger (widget-only; not in DailyCommuter target)
    Features/
      TimesWidget/                  # Widget views, Provider, intents, CtaTimesView+Preview
    Stores/
      FavoritesStore.swift          # @MainActor store; compiled by both targets but only used by the app
    ctaTimesBundle.swift            # Widget @main entry point
    ...
```

### Current Target Membership (from project.pbxproj)

The `ctaTimes/` directory is a **PBXFileSystemSynchronizedRootGroup** owned by the `ctaTimesExtension` target. Files are explicitly opted-in to the `DailyCommuter` target via a membership exception list:

**Files added to DailyCommuter target (via exception):**
- `App/FavoritesBridge.m`, `App/FavoritesBridge.swift`
- All `Core/Models/` files
- `Core/Networking/CTAService.swift`, `Core/Networking/CTAServiceLive.swift`
- `Core/Persistence/SharedStore.swift`
- `Stores/FavoritesStore.swift`

**Notable: NOT added to DailyCommuter (widget-only):**
- `Core/Utilities/Logger.swift` (currently empty)
- `Core/Utilities/Arrivals+Refresh.swift` (widget refresh scheduling logic)

**Files excluded from ctaTimesExtension (via exception):**
- `App/FavoritesBridge.m`, `App/FavoritesBridge.swift`
- `Info.plist`

Everything else in `ctaTimes/` compiles for the widget extension by default.

---

## Solution 1: Move FavoritesBridge Out of the Shared Directory

**Concept:** Physically relocate `FavoritesBridge.swift` and `FavoritesBridge.m` from `ios/ctaTimes/App/` into a directory that belongs **only** to the DailyCommuter app target, such as `ios/DailyCommuter/Bridge/`.

### Implementation

**Directory structure after the move:**

```
ios/
  DailyCommuter/
    Bridge/
      FavoritesBridge.swift     # import React is safe here
      FavoritesBridge.m
    AppDelegate.swift
    ...
  ctaTimes/                     # Now truly widget-safe
    Core/
    Features/
    Stores/
    ...
```

**Xcode changes required:**
1. Create `ios/DailyCommuter/Bridge/` directory.
2. Move `FavoritesBridge.swift` and `FavoritesBridge.m` into it.
3. In `project.pbxproj`:
   - Remove `App/FavoritesBridge.m` and `App/FavoritesBridge.swift` from both `membershipExceptions` lists (they no longer live in the synced root group).
   - Add the two files as `PBXFileReference` entries under the `DailyCommuter` group.
   - Add them to the DailyCommuter `Sources` build phase.
4. The bridging header (`DailyCommuter-Bridging-Header.h`) remains unchanged because it already imports `<React/RCTBridgeModule.h>`.

**No code changes needed** -- `FavoritesBridge.swift` already references `FavoriteDTO`, `Favorite`, `FavoritesStore`, and `WidgetKit`, all of which are compiled into the DailyCommuter target via the existing membership exceptions.

### Pros
- **Eliminates the root cause.** Bridge code with `import React` physically lives in an app-only directory. No membership exception trickery needed.
- **Minimal code changes.** The Swift/ObjC source files remain identical; only their filesystem location changes.
- **Makes intent clear to humans and AI agents.** Files inside `ios/DailyCommuter/` obviously belong to the app. Files inside `ios/ctaTimes/` obviously belong to the widget.
- **Fast to implement.** A 15-minute change.

### Cons
- **Requires modifying `project.pbxproj`**, which the project's `AGENTS.md` warns against without explicit permission.
- **Does not prevent future mistakes in `ctaTimes/`.** A developer could still add `import React` to a shared file like `FavoritesStore.swift`, which would also break the widget build. This solution only fixes the immediate bridge file problem.
- **The `ctaTimes/App/` directory becomes empty** and should be removed to avoid confusion.

### Verdict
**Strongly recommended as the immediate fix.** This is the lowest-risk, highest-impact change. It should be combined with one of the preventive solutions below (e.g., Solution 6) for long-term safety.

---

## Solution 2: Local Swift Package for Shared Code

**Concept:** Extract the shared models, networking, persistence, and store code into a local Swift Package (`DailyCommuterShared`). Both the app target and the widget extension target add this package as a dependency. Bridge code stays outside the package, app-only.

### Implementation

**Package structure:**

```
ios/
  Packages/
    DailyCommuterShared/
      Package.swift
      Sources/
        DailyCommuterShared/
          Models/
            Favorite.swift
            FavoriteDTO.swift
            Arrival.swift
            ArrivalDTO.swift
            Mapping+Arrival.swift
            Mapping+Favorite.swift
          Networking/
            CTAService.swift
            CTAServiceLive.swift
          Persistence/
            SharedStore.swift
          Stores/
            FavoritesStore.swift
          Utilities/
            Arrivals+Refresh.swift
            Logger.swift
  DailyCommuter/
    Bridge/
      FavoritesBridge.swift     # import React -- app-only
      FavoritesBridge.m
    AppDelegate.swift
  ctaTimes/                     # Widget-only code
    Features/
      TimesWidget/
        CtaTimesView.swift
        Provider.swift
        ...
    ctaTimesBundle.swift
    ctaTimesControl.swift
    ctaTimesLiveActivity.swift
    AppIntent.swift
```

**Package.swift:**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DailyCommuterShared",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "DailyCommuterShared",
            targets: ["DailyCommuterShared"]),
    ],
    targets: [
        .target(
            name: "DailyCommuterShared",
            dependencies: []),
        .testTarget(
            name: "DailyCommuterSharedTests",
            dependencies: ["DailyCommuterShared"]),
    ]
)
```

**Xcode integration:**
1. Drag `Packages/DailyCommuterShared` into the Xcode project.
2. In both `DailyCommuter` and `ctaTimesExtension` targets, go to **General > Frameworks, Libraries, and Embedded Content** and add `DailyCommuterShared`.
3. In all source files that reference shared types, add `import DailyCommuterShared`.
4. Remove the shared files from `ctaTimes/` and update the synced root group.

This pattern is directly recommended by [Shopify's engineering team](https://shopify.engineering/lessons-building-ios-widgets), who created a `WidgetCore` framework for exactly this purpose: keeping testable, reusable code in a shared module while leaving only WidgetKit-specific configuration in the extension target.

### Pros
- **Architectural gold standard.** Clean module boundaries. Explicit imports. Testable in isolation.
- **Prevents the problem permanently.** The shared package has no access to React Native headers. `import React` would be a compile error inside the package.
- **Enables unit testing of shared logic** without needing to build the full app or widget targets.
- **Faster incremental builds.** SPM caches the package build artifact; only rebuilds when sources change.
- **Deployment target flexibility.** The package declares `platforms: [.iOS(.v15)]`, compatible with both targets. Each target can still use APIs above that baseline with `#available` checks.

### Cons
- **Significant refactoring effort.** Every file that moves into the package needs `public` access modifiers on types, properties, and methods. Currently many types use `internal` (the default). Estimate 1-2 hours of access control adjustments.
- **`import DailyCommuterShared`** must be added to every file in both the app and widget that references shared types.
- **Expo/CocoaPods interaction.** The DailyCommuter target uses CocoaPods for React Native dependencies. Mixing CocoaPods with local SPM packages works in Xcode but can introduce edge cases with header search paths, especially when `use_frameworks!` is involved. Currently the project uses static libraries, which is safer.
- **Podfile changes may be needed** if the SPM package needs to be visible to Pods-managed targets.
- **Expo prebuild may overwrite project.pbxproj.** If using `npx expo prebuild`, the local package reference could be lost. This requires an Expo config plugin to re-inject it.

### Verdict
**Best long-term solution for a growing project.** The upfront cost is real but pays dividends in maintainability, testability, and developer safety. Recommended if you plan to expand the widget or add more native extensions.

---

## Solution 3: Conditional Compilation with Custom Flags

**Concept:** Add a custom `SWIFT_ACTIVE_COMPILATION_CONDITIONS` flag (e.g., `APP_TARGET`) to the DailyCommuter target only. Wrap all React-dependent code in `#if APP_TARGET` blocks.

### Implementation

**Step 1: Add the flag to the app target's build settings.**

In `project.pbxproj`, for both Debug and Release configurations of the `DailyCommuter` target, add `APP_TARGET` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS`:

```
SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG APP_TARGET";  // Debug
SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) APP_TARGET";        // Release
```

Alternatively, use the more elegant [Dave DeLong double-substitution technique](https://davedelong.com/blog/2019/04/09/conditional-compilation-part-3/) to derive the flag automatically from `APPLICATION_EXTENSION_API_ONLY`:

```
// In a shared .xcconfig:
_APP_EXTENSION_SWIFT_YES = BUILDING_FOR_APP_EXTENSION
_APP_EXTENSION_SWIFT_NO = APP_TARGET
APP_EXTENSION_SWIFT = $(_APP_EXTENSION_SWIFT_$(APPLICATION_EXTENSION_API_ONLY))
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) $(APP_EXTENSION_SWIFT)
```

**Step 2: Wrap React-dependent code.**

```swift
// FavoritesBridge.swift (stays in ctaTimes/App/)
#if APP_TARGET
import React
#endif
import Foundation
import Dispatch

#if canImport(WidgetKit)
import WidgetKit
#endif

#if APP_TARGET
@objc(FavoritesBridge)
final class FavoritesBridge: NSObject {
    private let queue = DispatchQueue(label: "FavoritesBridge.queue", qos: .utility)

    @objc(saveFavorites:resolver:rejecter:)
    func saveFavorites(_ dtosJson: String,
                       resolver resolve: @escaping RCTPromiseResolveBlock,
                       rejecter reject: @escaping RCTPromiseRejectBlock) {
        // ... entire implementation ...
    }
}
#endif
```

Similarly for `FavoritesBridge.m`:

```objc
#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(FavoritesBridge, NSObject)
RCT_EXTERN_METHOD(saveFavorites:(NSString *)dtosJson
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
+ (BOOL)requiresMainQueueSetup { return NO; }
@end
#endif
```

### Why `#if canImport(React)` Does Not Work

A common first instinct is to use `#if canImport(React)`. This is **unreliable** in this context because:
- `canImport` checks whether the module is discoverable at compile time, which depends on header search paths and module maps.
- In some CocoaPods configurations, the React module map is visible to all targets even if the framework itself is not linked. This causes `canImport(React)` to return `true` for the widget target, and then the linker fails.
- The behavior is not consistent across Xcode versions.

A custom `SWIFT_ACTIVE_COMPILATION_CONDITIONS` flag is deterministic and explicit.

### Pros
- **No file moves required.** Everything stays in place.
- **Familiar pattern.** Developers are used to `#if DEBUG`; `#if APP_TARGET` works the same way.
- **Can protect any file**, not just the bridge. If `import React` creeps into `FavoritesStore.swift`, the developer can wrap it.
- **Dave DeLong's double-substitution technique** makes the flag automatic, requiring no per-target manual configuration.

### Cons
- **Does not prevent the problem; only provides tools to cope with it.** A developer can still write `import React` outside of a `#if APP_TARGET` block. The widget build will break, and the developer must know to wrap it.
- **Code readability suffers.** `#if` blocks scattered through shared files obscure the logic.
- **Maintenance burden.** Every new bridge-related piece of code must be wrapped. Forgetting one line causes a build failure.
- **The ObjC bridge file is harder to conditionally compile** because `RCT_EXTERN_MODULE` is a macro that does not play well with `#if`.

### Verdict
**Useful as a supplementary technique** alongside Solution 1 or 2, but should not be the primary strategy. The flag is valuable for edge cases (e.g., using `UIApplication.shared` in shared code), but relying on it as the sole defense against React imports is fragile.

---

## Solution 4: Restructure with Explicit Target Directories

**Concept:** Abandon the single shared directory model. Create three distinct directory scopes: app-only, widget-only, and shared. Each maps to explicit Xcode target membership.

### Implementation

**Proposed directory structure:**

```
ios/
  DailyCommuter/                # App-only files
    AppDelegate.swift
    Bridge/
      FavoritesBridge.swift
      FavoritesBridge.m
  Shared/                       # New shared directory
    Models/
      Favorite.swift
      FavoriteDTO.swift
      Arrival.swift
      ArrivalDTO.swift
      Mapping+Arrival.swift
      Mapping+Favorite.swift
    Networking/
      CTAService.swift
      CTAServiceLive.swift
    Persistence/
      SharedStore.swift
    Stores/
      FavoritesStore.swift
    Utilities/
      Arrivals+Refresh.swift
      Logger.swift
  ctaTimes/                     # Widget-only files
    Features/
      TimesWidget/
        CtaTimesView.swift
        Provider.swift
        ...
    ctaTimesBundle.swift
    ctaTimesControl.swift
    ctaTimesLiveActivity.swift
    AppIntent.swift
    Assets.xcassets/
    Info.plist
```

**Xcode configuration:**
1. Convert `Shared/` into a folder reference or PBXFileSystemSynchronizedRootGroup that belongs to **both** targets.
2. `ctaTimes/` remains the synced root group for `ctaTimesExtension`.
3. `DailyCommuter/` contains app-only files (as it already does).
4. Remove the current membership exception approach entirely.

### Pros
- **Crystal clear intent.** Three directories, three purposes. Any developer or AI agent immediately understands the rules.
- **No membership exceptions needed.** Each directory maps to one or two targets by construction.
- **React imports in `Shared/` would still break the widget build**, but the physical separation makes the rule obvious: `Shared/` = no React.

### Cons
- **Largest `project.pbxproj` change.** Every file reference must be updated. High risk of merge conflicts.
- **Expo prebuild risk.** If Expo manages the `ios/` directory, a prebuild could overwrite the restructured layout.
- **Breaks git history** for all moved files (though `git log --follow` can trace them).
- **FavoritesStore.swift needs careful treatment.** It currently imports `WidgetKit` and `Network`, both of which are available on the widget target. If it gains a React dependency in the future, it must move to app-only. This is the same underlying risk, just with a clearer visual boundary.

### Verdict
**Good for projects with many shared files and complex target membership.** For DailyCommuter's current size (~20 shared files), this may be over-engineering. Solution 1 + Solution 6 achieves the same safety with less disruption.

---

## Solution 5: Protocol-Based Abstraction

**Concept:** Define protocols in shared code for any functionality that has React-dependent implementations. The shared code depends only on the protocol. The app target provides the concrete implementation that uses React.

### Implementation

**In shared code (`ctaTimes/Core/` or a shared package):**

```swift
// FavoritesSyncProtocol.swift -- shared, no React dependency
protocol FavoritesSyncing {
    func saveFavorites(_ dtosJson: String) async throws
}
```

**In app-only code (`ios/DailyCommuter/Bridge/`):**

```swift
// FavoritesBridge.swift -- app-only, imports React
import React
import Foundation

@objc(FavoritesBridge)
final class FavoritesBridge: NSObject, FavoritesSyncing {
    // ... existing implementation using RCTPromiseResolveBlock ...

    func saveFavorites(_ dtosJson: String) async throws {
        // Swift-native async wrapper around the bridge logic
    }
}
```

**In widget code**, no bridge is needed -- the widget reads directly from the App Group via `SharedStore`.

### Pros
- **Clean architecture.** Dependency inversion principle. Shared code never knows about React.
- **Testable.** Mock implementations of the protocol can be used in tests.
- **Future-proof.** If you later add a macOS target, a watchOS complication, or a second extension, each gets its own implementation of the protocol.

### Cons
- **Over-engineered for this specific case.** `FavoritesBridge` is only called from React Native JS code, which only runs in the app target. The widget never invokes the bridge; it reads from the App Group file. There is no shared code that needs to call through the bridge protocol.
- **Does not address the physical file layout problem.** The bridge file still needs to live somewhere that only the app target compiles.
- **Additional abstraction layer** adds complexity without a clear consumer. Protocols are useful when multiple implementations exist; here there is exactly one.

### Verdict
**Not recommended as a primary solution for this project.** The bridge is inherently an app-only concern. Protocol abstraction makes sense if shared code itself needs to invoke bridging behavior polymorphically, which is not the case here. However, the `CTAService` protocol already in the codebase is a good example of this pattern applied correctly (shared protocol, live implementation used by both targets).

---

## Solution 6: Build Phase Validation Script

**Concept:** Add a "Run Script" build phase to the `ctaTimesExtension` target that scans all Swift files compiled by the widget for forbidden imports (`import React`, `import ReactAppDependencyProvider`, etc.) and fails the build with a clear error message if any are found.

### Implementation

**Add to the ctaTimesExtension target as a "Run Script" build phase (before "Compile Sources"):**

```bash
#!/bin/bash
# Validate: No React Native imports in widget extension source files.
# This prevents accidental `import React` in shared code that would
# break the widget build.

FORBIDDEN_PATTERNS=(
    "^import React$"
    "^import React "
    "^import ReactAppDependencyProvider"
    "#import <React/"
    "RCTPromiseResolveBlock"
    "RCTPromiseRejectBlock"
    "RCTBridgeModule"
)

ERRORS_FOUND=0

# Scan all .swift and .m files in the ctaTimes directory
while IFS= read -r -d '' file; do
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
        if grep -qE "$pattern" "$file"; then
            echo "error: Forbidden React Native import found in widget-eligible file: $file"
            echo "error: Pattern matched: $pattern"
            echo "error: This file is compiled by the ctaTimesExtension target, which cannot link React Native."
            echo "error: Move React-dependent code to ios/DailyCommuter/Bridge/ or wrap it in #if APP_TARGET."
            ERRORS_FOUND=$((ERRORS_FOUND + 1))
        fi
    done
done < <(find "${SRCROOT}/ctaTimes" \( -name "*.swift" -o -name "*.m" \) -print0)

if [ $ERRORS_FOUND -gt 0 ]; then
    echo "error: Found $ERRORS_FOUND React Native import violation(s) in widget source files."
    exit 1
fi

echo "Widget source validation passed: no React Native imports found."
```

**Build phase configuration:**
- Name: `[Validate] No React imports in widget sources`
- Shell: `/bin/bash`
- Position: Before the `Sources` compile phase
- Input files: None (or use `${SRCROOT}/ctaTimes/**/*.swift` for incremental builds)
- Enable "Based on dependency analysis": No (run every build)

### Pros
- **Catches the problem at build time with a clear, actionable error message.** The developer (or AI agent) sees exactly which file is problematic and what to do about it.
- **Zero code changes required.** Purely additive build configuration.
- **Extremely fast.** `grep` over ~20 files takes milliseconds.
- **Catches mistakes by AI agents** who are the most frequent source of accidental `import React` additions.
- **Works regardless of which architectural solution is in place.** Serves as a safety net even after implementing Solution 1 or 2.

### Cons
- **Does not prevent the mistake; only catches it at build time.** The developer still writes the bad import, then gets a build error. However, the error message is immediate and clear.
- **Requires Solution 1 first (or a script exclusion).** As written, the script scans all `.swift` and `.m` files in `ctaTimes/`. If `FavoritesBridge.swift` and `FavoritesBridge.m` still live in `ctaTimes/App/`, the script will flag them as violations even though they are already excluded from the widget target via membership exceptions. Either implement Solution 1 first (moving them out), or add an exclusion for `App/FavoritesBridge.*` to the `find` command.
- **Requires `project.pbxproj` modification** to add the build phase.
- **Must be maintained** if the list of forbidden patterns changes.
- **Shell scripts in build phases are invisible** to developers who don't look at the Xcode build settings. Consider also adding a comment in `AGENTS.md` or the `ctaTimes/` directory.

### Verdict
**Highly recommended as a safety net** regardless of which primary solution you choose. This is cheap insurance. Even if you implement Solution 1 (moving the bridge out), this script will catch any future `import React` that sneaks into the remaining shared files. **Note:** if deployed without Solution 1, the script must exclude `ctaTimes/App/FavoritesBridge.*` to avoid false positives on the already-excluded bridge files.

---

## Solution 7: Xcode File Inspector Target Membership Best Practices

**Concept:** This is not a new solution but a set of practices for managing target membership correctly within the existing `PBXFileSystemSynchronizedRootGroup` approach.

### How Xcode's File System Synchronized Groups Work

The current project uses Xcode's newer **file system synchronized root groups** (introduced in Xcode 16). This means:
- The `ctaTimes/` directory is a synced root group owned by `ctaTimesExtension`.
- **Every file** added to `ctaTimes/` is automatically included in `ctaTimesExtension`'s compile sources.
- To include a file in the `DailyCommuter` target, it must be listed in a `PBXFileSystemSynchronizedBuildFileExceptionSet` with `target = DailyCommuter`.
- To exclude a file from `ctaTimesExtension`, it must be listed in a separate exception set with `target = ctaTimesExtension`.

**This is the root of the fragility.** New files default to widget-only. Adding them to the app requires a pbxproj edit. Excluding them from the widget requires another pbxproj edit. Both are invisible to developers who add files through the filesystem rather than through Xcode.

### Current Exception Sets

```
# Excluded from ctaTimesExtension:
App/FavoritesBridge.m
App/FavoritesBridge.swift
Info.plist

# Added to DailyCommuter:
App/FavoritesBridge.m
App/FavoritesBridge.swift
Core/Models/Arrival.swift
Core/Models/ArrivalDTO.swift
Core/Models/Favorite.swift
Core/Models/FavoriteDTO.swift
Core/Models/Mapping+Arrival.swift
Core/Models/Mapping+Favorite.swift
Core/Networking/CTAService.swift
Core/Networking/CTAServiceLive.swift
Core/Persistence/SharedStore.swift
Stores/FavoritesStore.swift
```

### Best Practices

1. **When adding a new shared file** (e.g., a new model), you must:
   - Add it via Xcode's Project Navigator (not via the filesystem) so Xcode prompts for target membership.
   - Check `DailyCommuter` in the target membership checkbox. The file already belongs to `ctaTimesExtension` by default (via the synced root group), so no checkbox needed for the extension.
   - Verify it appears in the DailyCommuter membership exception list in `project.pbxproj` (it will NOT appear in the ctaTimesExtension exclusion list, since it is not being excluded from the extension).

2. **When adding a widget-only file** (e.g., a new widget view):
   - Add it anywhere in `ctaTimes/` except `App/`.
   - It is automatically included in `ctaTimesExtension` by the synced root group.
   - Do **not** add it to the DailyCommuter target.

3. **When adding an app-only file** that uses React:
   - **Do not put it in `ctaTimes/`.** Place it in `ios/DailyCommuter/` instead.
   - If it must be in `ctaTimes/` for some reason, add it to the widget exclusion list.

4. **Add a comment to `AGENTS.md`** (or a `README` in `ctaTimes/`) documenting these rules.

### Pros
- **No structural changes needed.** Works with the existing layout.
- **Standard Xcode workflow.** Uses the tool as designed.

### Cons
- **Entirely reliant on developer discipline.** The rules are not enforced by the build system.
- **AI agents do not use Xcode's GUI.** They edit files via the filesystem and do not see target membership prompts.
- **The synced root group's default inclusion behavior is counterintuitive** for a directory that serves two targets with different capabilities.

### Verdict
**Necessary knowledge but insufficient as a standalone solution.** These practices should be documented and followed, but they must be backed by at least one enforcement mechanism (Solution 1 or 6).

---

## Recommended Approach: Layered Defense

For the DailyCommuter project at its current scale, the recommended approach combines three solutions:

### Immediate (30 minutes)

**Solution 1: Move FavoritesBridge to `ios/DailyCommuter/Bridge/`.**

This eliminates the most dangerous file from the shared directory with minimal risk. The bridge has no reason to live alongside widget code.

### Same Day (1 hour)

**Solution 6: Add the validation build phase script to `ctaTimesExtension`.**

This creates a permanent safety net that catches any `import React` in the widget-eligible directory, regardless of who or what adds it.

**Solution 3 (partial): Add `APP_TARGET` to DailyCommuter's `SWIFT_ACTIVE_COMPILATION_CONDITIONS`.**

Even if not used immediately, having the flag available means developers can use `#if APP_TARGET` as a surgical tool when needed (e.g., if a shared utility needs a UIKit API that is unavailable in extensions).

### Future (when project grows)

**Solution 2: Extract shared code into a local Swift Package.**

When the shared surface area grows (more models, more networking code, shared ViewModels), the package approach pays for itself. It also enables:
- Unit testing shared logic in isolation
- Snapshot testing widget views (as [Shopify recommends](https://shopify.engineering/lessons-building-ios-widgets))
- Sharing code with future targets (watchOS complication, macOS Catalyst, etc.)

---

## Comparison Matrix

| Criterion | Solution 1 (Move) | Solution 2 (SPM) | Solution 3 (Flags) | Solution 4 (Restructure) | Solution 5 (Protocols) | Solution 6 (Script) | Solution 7 (Membership) |
|---|---|---|---|---|---|---|---|
| **Prevents problem permanently** | Partially | Yes | No | Partially | No | No (catches it) | No |
| **Implementation effort** | Low | High | Low | High | Medium | Low | None |
| **Risk of breaking existing build** | Low | Medium | Low | High | Low | Low* | None |
| **Survives Expo prebuild** | Maybe | Needs plugin | Maybe | Maybe | N/A | Maybe | N/A |
| **Clear to AI agents** | Yes | Yes | Partially | Yes | No | Yes (error msg) | No |
| **Enables shared code testing** | No | Yes | No | No | Yes | No | No |
| **Scales to more extensions** | No | Yes | Yes | Yes | Yes | Yes | No |

\* Solution 6's script will fail the widget build if `FavoritesBridge.swift` still lives in `ctaTimes/App/` (it contains `import React`). Requires Solution 1 first, or an exclusion in the `find` command.

---

## References and Further Reading

- [Lessons From Building iOS Widgets - Shopify Engineering](https://shopify.engineering/lessons-building-ios-widgets) -- Shopify's WidgetCore module architecture
- [Conditional Compilation, Part 3: App Extensions - Dave DeLong](https://davedelong.com/blog/2019/04/09/conditional-compilation-part-3/) -- SWIFT_ACTIVE_COMPILATION_CONDITIONS double-substitution technique
- [Conditional Compilation, Part 2: Including and Excluding Source Files - Dave DeLong](https://davedelong.com/blog/2018/07/25/conditional-compilation-in-swift-part-2/) -- Build phase file exclusion
- [Using Compiler Directives in Swift - Swift by Sundell](https://www.swiftbysundell.com/articles/using-compiler-directives-in-swift/) -- #if canImport, custom flags
- [App Extensions - React Native Documentation](https://reactnative.dev/docs/app-extensions) -- Official RN guidance on extensions
- [How to Implement iOS Widgets in Expo Apps - Expo Blog](https://expo.dev/blog/how-to-implement-ios-widgets-in-expo-apps) -- Expo-specific widget integration
- [@bacons/apple-targets - Evan Bacon](https://github.com/EvanBacon/expo-apple-targets) -- Expo config plugin for managing Apple targets
- [react-native-widget-extension - bndkt](https://github.com/bndkt/react-native-widget-extension) -- Community library for RN widget extensions
- [Building Interactive Widgets in Expo-Managed React Native Apps - Peter Aron Toth](https://www.peterarontoth.com/posts/interactive-widgets-in-expo-managed-workflows) -- App Groups and custom modules
- [Local SPM Modularization - Guy Cohen](https://medium.com/@guycohendev/local-spm-part-2-mastering-modularization-with-swift-package-manager-xcode-15-16-d5a11ddd166c) -- Local Swift Package modularization patterns
- [Management of Native Code and React Native at Shopify](https://shopify.engineering/managing-native-code-react-native) -- Large-scale RN/native code coexistence
- [Running Custom Scripts During a Build - Apple Documentation](https://developer.apple.com/documentation/xcode/running-custom-scripts-during-a-build) -- Build phase script reference
- [Customizing the Build Phases of a Target - Apple Documentation](https://developer.apple.com/documentation/xcode/customizing-the-build-phases-of-a-target)
- [Apple Home Screen Widgets with Expo - Evan Bacon](https://evanbacon.dev/blog/apple-home-screen-widgets) -- Continuous Native Generation + widget targets
