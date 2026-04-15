<!-- SUBAGENT PROMPT

## Task: Implement Xcode Project Format Safeguards

You are implementing the "Recommended Strategy" from this document for the DailyCommuter project. Read this entire document for full context, then execute the steps below. You may deploy your own subagents for parallel work.

### What you CAN do (no permission needed):
1. **Pin the EAS Build image** — Edit `eas.json` to add `"ios": { "image": "macos-sequoia-15.5-xcode-16.4" }` to each build profile (`development`, `preview`, `production`). This is a safe, additive JSON change.
2. **Add a GitHub Actions CI check** — Create `.github/workflows/validate-pbxproj.yml` using the workflow in Solution 2. This is a new file, purely additive.
3. **Add a pre-commit hook** — Install Husky (`bun add -d husky && bunx husky init`) and create `.husky/pre-commit` using the script from Solution 1, Option B.

### What you CANNOT do (requires Xcode):
- **Convert PBXFileSystemSynchronizedRootGroup to PBXGroup** (Solution 3b) — This MUST be done manually in Xcode by right-clicking the `ctaTimes` folder and selecting "Convert to Group." Do NOT hand-edit `project.pbxproj` for this.

### Critical ordering constraint:
The committed `project.pbxproj` ALREADY contains `PBXFileSystemSynchronizedRootGroup`. The CI check and pre-commit hook both reject this. Since Solution 3b (the Xcode manual step) hasn't been done yet, you MUST deploy the hooks/CI with ONLY the objectVersion check enabled. Comment out or remove the `PBXFileSystemSynchronizedRootGroup` checks and leave a TODO comment explaining they should be uncommented after the manual Xcode conversion is done.

### Implementation checklist:
- [ ] Edit `eas.json` — add `ios.image` to all three build profiles
- [ ] Create `.github/workflows/validate-pbxproj.yml` — objectVersion check only (PBXFileSystemSynchronizedRootGroup check commented out with TODO)
- [ ] Install Husky and create `.husky/pre-commit` — objectVersion check only (same caveat)
- [ ] Update `CLAUDE.md` "Known Build Issues" section to mention the new safeguards
- [ ] Verify: `cat eas.json` shows the image fields, `.husky/pre-commit` exists and is executable, workflow file is valid YAML

### Do NOT:
- Modify `project.pbxproj` or any `Info.plist`
- Run `expo prebuild`
- Change any Swift source files
- Commit changes (leave that to the user)

END SUBAGENT PROMPT -->

# Preventing Xcode from Silently Upgrading the Project File Format

## Problem Statement

When a developer opens an Expo-generated `project.pbxproj` (originally at `objectVersion = 54`) in Xcode 16.x, Xcode silently upgrades the project format. Two things happen:

1. `objectVersion` is bumped (e.g., from 54 to 70)
2. New ISA types like `PBXFileSystemSynchronizedRootGroup` are introduced

These changes break builds on older Xcode versions and on EAS Build servers running earlier images. In the DailyCommuter project, the widget extension (`ctaTimes`) was added in Xcode 16.3, which introduced `objectVersion = 70` and `PBXFileSystemSynchronizedRootGroup`. The objectVersion was manually lowered to 60, but the `PBXFileSystemSynchronizedRootGroup` reference remained, locking the project to Xcode 16+.

### objectVersion Compatibility Reference

| objectVersion | Minimum Xcode Version |
|:---:|:---|
| 77 | Xcode 16.0 (with project compatibility explicitly set to Xcode 16.0) |
| 71 | Xcode 16.2 |
| 70 | Xcode 16.0 |
| 63 | Xcode 15.3 |
| 60 | Xcode 15.0 |
| 56 | Xcode 14.0 |
| 55 | Xcode 13.0 |
| 54 | Xcode 12.0 |

Source: [CocoaPods/Xcodeproj constants.rb](https://github.com/CocoaPods/Xcodeproj/blob/master/lib/xcodeproj/constants.rb)

### Current State of This Project

File: `ios/DailyCommuter.xcodeproj/project.pbxproj`

- `objectVersion = 60` (committed in `c42efdb`, requires Xcode 15.0+)
- **However**, opening the project in Xcode 16.3 silently changes the working tree back to `objectVersion = 70` (this has already happened in the current unstaged changes)
- `compatibilityVersion = "Xcode 15.0"` (does not actually enforce compatibility -- the synchronized groups override this)
- Contains `PBXFileSystemSynchronizedRootGroup` for the `ctaTimes` widget folder (this was NOT removed when objectVersion was lowered to 60, so the project still effectively requires Xcode 16+)
- Contains `PBXFileSystemSynchronizedBuildFileExceptionSet` entries for build membership exceptions
- The `ctaTimesExtension` native target references `fileSystemSynchronizedGroups`

**Note:** The committed objectVersion is 60, but the presence of `PBXFileSystemSynchronizedRootGroup` means the project requires Xcode 16+ regardless of the objectVersion number. Lowering objectVersion alone was insufficient -- the synchronized group ISA types must also be removed for true Xcode 15 compatibility.

---

## Solution 1: Git Pre-Commit Hook

**Category: Prevention / Detection**

A pre-commit hook can block any commit that changes the `objectVersion` to an unapproved value or introduces `PBXFileSystemSynchronizedRootGroup`.

### Implementation

#### Option A: Raw Git Hook (no dependencies)

Create the file `.git/hooks/pre-commit` (or use a shared script referenced by the hook):

```bash
#!/bin/bash
# .git/hooks/pre-commit
# Prevent Xcode project format upgrades from being committed

PBXPROJ="ios/DailyCommuter.xcodeproj/project.pbxproj"
ALLOWED_OBJECT_VERSION="60"

# Only check if the pbxproj is staged
if git diff --cached --name-only | grep -q "$PBXPROJ"; then

  # Check objectVersion
  STAGED_VERSION=$(git show :$PBXPROJ | grep -m1 'objectVersion' | sed 's/[^0-9]//g')
  if [ "$STAGED_VERSION" != "$ALLOWED_OBJECT_VERSION" ]; then
    echo "ERROR: objectVersion in project.pbxproj is $STAGED_VERSION (expected $ALLOWED_OBJECT_VERSION)"
    echo "Xcode may have silently upgraded your project format."
    echo "Revert the objectVersion change before committing."
    exit 1
  fi

  # Check for Xcode 16-only ISA types
  if git show :$PBXPROJ | grep -q 'PBXFileSystemSynchronizedRootGroup'; then
    echo "ERROR: project.pbxproj contains PBXFileSystemSynchronizedRootGroup"
    echo "This ISA type requires Xcode 16+ and will break older build environments."
    echo "In Xcode, right-click the folder and choose 'Convert to Group' to remove it."
    exit 1
  fi

  echo "project.pbxproj format check passed (objectVersion=$ALLOWED_OBJECT_VERSION)"
fi
```

Make it executable: `chmod +x .git/hooks/pre-commit`

#### Option B: Using Husky (shareable via package.json)

Install Husky:

```bash
bun add -d husky
bunx husky init
```

Create `.husky/pre-commit`:

```bash
#!/bin/bash

PBXPROJ="ios/DailyCommuter.xcodeproj/project.pbxproj"
ALLOWED_OBJECT_VERSION="60"

if git diff --cached --name-only | grep -q "$PBXPROJ"; then
  STAGED_VERSION=$(git show :$PBXPROJ | grep -m1 'objectVersion' | sed 's/[^0-9]//g')

  if [ "$STAGED_VERSION" != "$ALLOWED_OBJECT_VERSION" ]; then
    echo "BLOCKED: objectVersion changed to $STAGED_VERSION (must be $ALLOWED_OBJECT_VERSION)"
    exit 1
  fi

  if git show :$PBXPROJ | grep -q 'PBXFileSystemSynchronizedRootGroup'; then
    echo "BLOCKED: PBXFileSystemSynchronizedRootGroup detected (Xcode 16+ only)"
    exit 1
  fi
fi
```

#### Option C: Using Lefthook (lightweight alternative)

Install Lefthook:

```bash
bun add -d lefthook
bunx lefthook install
```

Create `lefthook.yml`:

```yaml
pre-commit:
  commands:
    check-pbxproj:
      glob: "ios/**/*.pbxproj"
      run: |
        PBXPROJ="ios/DailyCommuter.xcodeproj/project.pbxproj"
        VERSION=$(git show :$PBXPROJ | grep -m1 'objectVersion' | sed 's/[^0-9]//g')
        if [ "$VERSION" != "60" ]; then
          echo "objectVersion is $VERSION, expected 60"
          exit 1
        fi
        if git show :$PBXPROJ | grep -q 'PBXFileSystemSynchronizedRootGroup'; then
          echo "PBXFileSystemSynchronizedRootGroup detected"
          exit 1
        fi
```

**Note:** Unlike Options A and B which use `git show :$PBXPROJ` to read the staged file content, Lefthook's `glob` filter only determines *whether* the command runs (based on staged files matching the pattern). The `run` script itself must still explicitly read the staged content via `git show :$PBXPROJ` to avoid checking the working tree, which may differ from what is being committed.

### Pros
- Catches the problem at commit time, before it enters the repository
- Zero cost in CI -- fails fast on the developer's machine
- Husky/Lefthook versions are automatically installed for all team members via `prepare` scripts

### Cons
- Git hooks can be bypassed with `--no-verify`
- Raw `.git/hooks` scripts are not version-controlled (must be copied manually or symlinked)
- Does not fix the problem, only blocks the symptom

### Important Caveat for This Project

The committed `project.pbxproj` already contains `PBXFileSystemSynchronizedRootGroup`. If you deploy these hooks as written (checking for both objectVersion AND synchronized groups), they will block **all** commits that touch `project.pbxproj` until Solution 3b is completed (converting the synchronized folder to a group). To use these hooks immediately, either:
- Remove the `PBXFileSystemSynchronizedRootGroup` check and only enforce the objectVersion, or
- Complete Solution 3b first, then deploy the hooks

### Verdict
**Workaround.** Essential as a first line of defense but must be paired with a CI check (Solution 2) since hooks can be skipped.

---

## Solution 2: CI Check (GitHub Actions)

**Category: Prevention / Enforcement**

A CI job that validates the pbxproj format on every pull request provides an enforceable gate that cannot be bypassed.

### Implementation

Create `.github/workflows/validate-pbxproj.yml`:

```yaml
name: Validate Xcode Project Format

on:
  pull_request:
    paths:
      - 'ios/**/*.pbxproj'

jobs:
  check-pbxproj-format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check objectVersion
        run: |
          PBXPROJ="ios/DailyCommuter.xcodeproj/project.pbxproj"
          ALLOWED_VERSION="60"

          CURRENT_VERSION=$(grep -m1 'objectVersion' "$PBXPROJ" | sed 's/[^0-9]//g')
          echo "objectVersion found: $CURRENT_VERSION"

          if [ "$CURRENT_VERSION" != "$ALLOWED_VERSION" ]; then
            echo "::error file=$PBXPROJ::objectVersion is $CURRENT_VERSION, expected $ALLOWED_VERSION. Xcode may have silently upgraded the project format."
            exit 1
          fi

      - name: Check for Xcode 16-only ISA types
        run: |
          PBXPROJ="ios/DailyCommuter.xcodeproj/project.pbxproj"

          if grep -q 'PBXFileSystemSynchronizedRootGroup' "$PBXPROJ"; then
            echo "::error file=$PBXPROJ::Contains PBXFileSystemSynchronizedRootGroup (Xcode 16+ only). Right-click the folder in Xcode and choose 'Convert to Group'."
            exit 1
          fi

          if grep -q 'PBXFileSystemSynchronizedBuildFileExceptionSet' "$PBXPROJ"; then
            echo "::error file=$PBXPROJ::Contains PBXFileSystemSynchronizedBuildFileExceptionSet (Xcode 16+ only)."
            exit 1
          fi

      - name: Validation passed
        run: echo "Xcode project format is valid (objectVersion=60, no synchronized groups)"
```

Then in GitHub repository settings, mark `check-pbxproj-format` as a required status check for the `main` branch.

### Pros
- Cannot be bypassed (when set as a required status check)
- Runs on `ubuntu-latest` (cheap, fast -- no macOS runner needed since it is just text parsing)
- Annotates the exact file and line in the PR diff
- Triggered only when pbxproj files change (via `paths` filter)

### Cons
- Feedback is delayed until CI runs (not instant like a git hook)
- Requires GitHub Actions configuration and branch protection rules
- Does not prevent the developer from having to fix the problem locally

### Important Caveat for This Project

The same caveat as Solution 1 applies: the committed `project.pbxproj` already contains `PBXFileSystemSynchronizedRootGroup` and `PBXFileSystemSynchronizedBuildFileExceptionSet`. Deploying this CI check as written would immediately fail on any PR that touches the pbxproj. Complete Solution 3b first, or initially only check the objectVersion.

### Verdict
**Workaround, but enforceable.** This is the single most important safeguard. Pair it with Solution 1 for fast local feedback.

---

## Solution 3: Xcode Settings to Prevent Auto-Migration

**Category: Root Cause Prevention**

### What Xcode Actually Does

Xcode does not provide a user-facing preference to disable project format upgrades. The migration happens silently in two scenarios:

1. **Adding a new target** (e.g., a Widget Extension) -- Xcode creates the target using the latest format features available in the running Xcode version
2. **"Update to Recommended Settings"** -- the yellow warning banner in the project navigator triggers format upgrades when accepted

### Available Mitigations

#### 3a. Never Accept "Update to Recommended Settings" for Format Changes

When Xcode shows the "Update to recommended settings" warning, click "Review changes" and carefully inspect what it proposes. Uncheck any changes to `objectVersion` or project format. Only accept individual build setting recommendations.

#### 3b. Convert Synchronized Folders to Groups

If Xcode has already created a `PBXFileSystemSynchronizedRootGroup`, you can convert it back:

1. In Xcode's Project Navigator, right-click the `ctaTimes` folder
2. Select **"Convert to Group"**
3. This replaces `PBXFileSystemSynchronizedRootGroup` with a traditional `PBXGroup` and individual `PBXFileReference` entries
4. Manually set `objectVersion` back to `60` in the pbxproj file

#### 3c. Avoid Converting Groups to Folders (Buildable Folders)

In Xcode 16+, the Project Navigator offers a "Convert to Folder" context menu item that turns a traditional `PBXGroup` into a `PBXFileSystemSynchronizedRootGroup` (also called a "buildable folder" or "synchronized group"). This is **not** the same as the older "Create folder reference" option. Synchronized groups/buildable folders automatically track files on disk without individual `PBXFileReference` entries, which reduces merge conflicts but introduces the Xcode 16-only ISA type. When adding new files or folders to a target, always use "Create groups" and never use "Convert to Folder".

### Pros
- Addresses the root cause (human behavior in Xcode)
- No tooling required

### Cons
- Relies on developer discipline -- easy to forget or miss
- No setting or flag exists to disable this globally
- Xcode is opaque about when it modifies the format
- New team members will not know about this unless documented

### Verdict
**Not a fix.** There is no Xcode setting to prevent format upgrades. This is documentation/training only.

---

## Solution 4: Pin Xcode Version in EAS Build Configuration

**Category: Build Environment Control**

Rather than preventing the format upgrade, ensure the build server always has a compatible Xcode version.

### Implementation

In `eas.json`, add the `image` field to each build profile:

```json
{
  "cli": {
    "version": ">= 16.4.0",
    "appVersionSource": "remote"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "ios": {
        "image": "macos-sequoia-15.5-xcode-16.4"
      }
    },
    "preview": {
      "distribution": "internal",
      "ios": {
        "image": "macos-sequoia-15.5-xcode-16.4"
      }
    },
    "production": {
      "autoIncrement": true,
      "environment": "production",
      "ios": {
        "image": "macos-sequoia-15.5-xcode-16.4"
      }
    }
  },
  "submit": {
    "production": {}
  }
}
```

### Available EAS Build Images (Xcode 16.x)

| Image Name | macOS | Xcode |
|:---|:---|:---|
| `macos-sequoia-15.6-xcode-16.4` | Sequoia 15.6 | 16.4 |
| `macos-sequoia-15.5-xcode-16.4` | Sequoia 15.5 | 16.4 (`sdk-53`) |
| `macos-sequoia-15.4-xcode-16.3` | Sequoia 15.4.1 | 16.3 |
| `macos-sequoia-15.3-xcode-16.2` | Sequoia 15.3 | 16.2 (`sdk-52`) |
| `macos-sonoma-14.6-xcode-16.1` | Sonoma 14.6 | 16.1 |
| `macos-sonoma-14.6-xcode-16.0` | Sonoma 14.6 | 16.0 |

You can also use aliases like `latest`, `auto`, or `sdk-53`. Using the full image name guarantees a consistent environment.

Since the project currently contains `PBXFileSystemSynchronizedRootGroup` (even though the committed `objectVersion` is 60), it effectively requires Xcode 16.0 or later. Any of the images above will work. For Expo SDK 53, the `sdk-53` alias (`macos-sequoia-15.5-xcode-16.4`) is the recommended choice.

### Pros
- Guarantees the EAS build server has a compatible Xcode version
- Simple one-line configuration change per build profile
- Eliminates the "works locally, fails on CI" class of bugs
- Required anyway since Apple mandates iOS 18 SDK (Xcode 16+) for App Store submissions starting April 2025

### Cons
- Does not prevent the format from being upgraded further (e.g., objectVersion 77)
- Must be manually updated when new Xcode images are available
- Locks all builds to a specific Xcode version, potentially missing security patches or SDK improvements

### Verdict
**Permanent fix for EAS Build compatibility.** This is the most direct way to ensure your project file format matches the build server's Xcode version. However, it does not prevent further silent upgrades from developer machines.

---

## Solution 5: Expo Prebuild Strategies

**Category: Regeneration / Config Plugins**

### 5a. Using `expo prebuild --clean` to Regenerate

Running `npx expo prebuild --clean` deletes the entire `ios/` directory and regenerates it from `app.json` and config plugins. This resets `objectVersion` to whatever the current Expo SDK's template uses.

```bash
npx expo prebuild -p ios --clean
```

**The problem:** The widget extension (`ctaTimes`) was added manually in Xcode, not through a config plugin. Running `--clean` would delete the widget extension entirely. This approach only works if all native code is managed through config plugins.

### 5b. Config Plugin to Enforce objectVersion

Create a custom config plugin that forces the objectVersion back to a safe value after prebuild:

Create `plugins/withObjectVersion.js`:

```javascript
const { withXcodeProject } = require('@expo/config-plugins');

/**
 * Config plugin to enforce a specific objectVersion in the Xcode project.
 * Prevents Xcode from silently upgrading the project format.
 *
 * @param {object} config - Expo config
 * @param {number} targetVersion - The objectVersion to enforce (default: 60)
 */
const withObjectVersion = (config, targetVersion = 60) => {
  return withXcodeProject(config, async (config) => {
    const xcodeProject = config.modResults;

    // The xcode npm package parses pbxproj into xcodeProject.hash.project
    if (xcodeProject.hash && xcodeProject.hash.project) {
      const currentVersion = xcodeProject.hash.project.objectVersion;
      if (currentVersion !== String(targetVersion)) {
        console.log(
          `[withObjectVersion] Changing objectVersion from ${currentVersion} to ${targetVersion}`
        );
        xcodeProject.hash.project.objectVersion = String(targetVersion);
      }
    }

    return config;
  });
};

module.exports = withObjectVersion;
```

Register it in `app.json`:

```json
{
  "expo": {
    "plugins": [
      ["./plugins/withObjectVersion", 60],
      "expo-router",
      ...
    ]
  }
}
```

**Important caveat:** This plugin changes the objectVersion number but does NOT remove `PBXFileSystemSynchronizedRootGroup` entries. The `xcode` npm package used by `withXcodeProject` may not fully understand these ISA types, which means they could persist or cause parse errors. You would need a more aggressive plugin that also does string-level replacement of the pbxproj to strip out synchronized groups and replace them with traditional `PBXGroup` entries.

### 5c. Config Plugin to Manage the Widget Extension

Rather than manually adding the widget in Xcode, use a config plugin to inject it during prebuild. This way, `expo prebuild --clean` becomes safe to use:

**Option 1: `@bacons/apple-targets` (by Evan Bacon)**

```bash
bun add @bacons/apple-targets
```

Create a `targets/ctaTimes/expo-target.config.js`:

```javascript
/** @type {import('@bacons/apple-targets').Config} */
module.exports = {
  type: 'widget',
  name: 'ctaTimes',
  // Additional configuration...
};
```

Move the Swift widget source files into `targets/ctaTimes/` and register the plugin in `app.json`:

```json
{
  "expo": {
    "plugins": [
      "@bacons/apple-targets",
      ...
    ]
  }
}
```

Now `npx expo prebuild --clean` regenerates the project including the widget target, and the objectVersion is controlled by the template.

**Option 2: `react-native-widget-extension`**

```bash
bun add react-native-widget-extension
```

This plugin automates WidgetKit extension setup and can be configured in `app.json`.

### Pros
- 5a: Full regeneration guarantees a clean project format
- 5b: Can enforce objectVersion programmatically during prebuild
- 5c: Makes the widget extension survive `prebuild --clean`, enabling full CNG (Continuous Native Generation)

### Cons
- 5a: Destroys manually-added native code (widget extension)
- 5b: Changing objectVersion without also fixing ISA types can create an inconsistent project file
- 5c: Requires migrating the existing widget to a config plugin structure, which is significant effort
- 5c: Third-party plugins may not support every Xcode feature used in the widget

### Verdict
- **5a:** Only viable if combined with 5c.
- **5b:** Partial workaround. Useful as a safety net but does not address PBXFileSystemSynchronizedRootGroup.
- **5c:** **Permanent fix.** This is the most robust long-term solution for Expo projects. By managing the widget through a config plugin, the entire `ios/` directory becomes regenerable, and Xcode never gets the chance to silently upgrade the format.

---

## Solution 6: Post-Save Scripts or Xcode Behaviors

**Category: Automated Reversion**

### 6a. Xcode Behavior Script

Xcode has a "Behaviors" system (Xcode > Behaviors > Edit Behaviors) that triggers scripts on events like "Build Starts" or "Build Succeeds". However:

- There is no "File Saved" or "Project Saved" behavior trigger
- Build behaviors run too late to prevent format changes from being written

### 6b. File System Watcher (fswatch / watchman)

Use a file watcher to monitor the pbxproj file and automatically revert objectVersion changes:

```bash
# Install fswatch (macOS)
brew install fswatch

# Watch and auto-fix (run in a background terminal)
fswatch -o ios/DailyCommuter.xcodeproj/project.pbxproj | while read; do
  CURRENT=$(grep -m1 'objectVersion' ios/DailyCommuter.xcodeproj/project.pbxproj | sed 's/[^0-9]//g')
  if [ "$CURRENT" != "60" ]; then
    echo "[pbxproj-watcher] objectVersion changed to $CURRENT, reverting to 60..."
    sed -i '' 's/objectVersion = [0-9]*/objectVersion = 60/' ios/DailyCommuter.xcodeproj/project.pbxproj
  fi
done
```

You could wrap this in a package.json script:

```json
{
  "scripts": {
    "watch:pbxproj": "fswatch -o ios/DailyCommuter.xcodeproj/project.pbxproj | while read; do sed -i '' 's/objectVersion = [0-9]*/objectVersion = 60/' ios/DailyCommuter.xcodeproj/project.pbxproj; done"
  }
}
```

### Pros
- Automatically reverts changes without developer intervention
- Can run in background during development

### Cons
- Race condition: modifying the file while Xcode has it open can cause Xcode to reload or show "file modified externally" dialogs
- Does not fix the PBXFileSystemSynchronizedRootGroup issue (only reverts objectVersion number)
- Requires developer to remember to start the watcher
- Fragile: Xcode may overwrite the reversion on next save
- Can corrupt the project file if the sed replacement happens mid-write

### Verdict
**Fragile workaround. Not recommended.** The race conditions and potential for corruption outweigh the convenience.

---

## Solution 7: Alternative Project Structures

**Category: Architecture / Isolation**

### 7a. Separate Xcode Project for the Widget

Keep the widget extension in its own `.xcodeproj` and reference it from the main workspace:

1. Create a new Xcode project `ctaTimesWidget.xcodeproj` in a directory outside `ios/`
2. Add it to the workspace (or create a new one) alongside `DailyCommuter.xcodeproj`
3. Add the widget product as a dependency of the main app target

This isolates the widget's project format from the Expo-managed project. The widget project can use objectVersion 70+ freely, while the main project stays at whatever Expo generates.

**Problem:** This is complex to maintain, and EAS Build/`expo prebuild` do not natively support multi-project workspaces with external dependencies. CocoaPods already creates a workspace, and adding another project to it requires manual Podfile configuration.

### 7b. Keep Widget Outside the `ios/` Directory

Using `@bacons/apple-targets` (Solution 5c), the widget source lives in `targets/ctaTimes/` at the project root, outside the `ios/` directory. The config plugin links it into the Xcode project during prebuild. This means:

- `expo prebuild --clean` can safely regenerate `ios/`
- The widget code is never directly modified by Xcode's project format
- objectVersion is controlled by the prebuild template

### 7c. Git Submodule for the Widget

Place the widget in a separate git repository and include it as a submodule. The main project references it but does not control its project format.

### Pros
- 7a: Complete isolation between Expo-managed and manually-managed project files
- 7b: Clean separation, compatible with CNG workflow
- 7c: Independent version control for the widget

### Cons
- 7a: Very complex, poor support from Expo/EAS tooling, manual workspace management
- 7b: Requires migrating to `@bacons/apple-targets` (same as Solution 5c)
- 7c: Adds complexity of submodule management, does not work well with EAS Build

### Verdict
- **7a:** Not practical for Expo projects.
- **7b:** This is effectively Solution 5c reframed. **Permanent fix if fully adopted.**
- **7c:** Over-engineered for this problem.

---

## Solution 8: Xcode Configuration Files

**Category: Xcode Settings Investigation**

### 8a. WorkspaceSettings.xcsettings

The file at `ios/DailyCommuter.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` controls certain workspace-level settings. Known keys include:

- `BuildSystemType` (legacy vs new build system)
- `DisableBuildSystemDeprecationDiagnostic`
- `PreviewsEnabled`

**There is no known key** like `IDEXcodeProjectCompatibilityVersion` or `DisableProjectFormatMigration` that prevents Xcode from upgrading the project format. This has been verified through:
- Apple Developer Forums searches
- Xcode build settings reference documentation
- Community investigation in CocoaPods, XcodeGen, and fastlane issues

### 8b. .xcodesettings File

There is no `.xcodesettings` file format recognized by Xcode for project-level settings. The name is sometimes confused with `.xcconfig` files, which only control build settings (compiler flags, paths, etc.), not project file format.

### 8c. IDEWorkspaceChecks.plist

The file at `ios/DailyCommuter.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` is used to suppress one-time Xcode workspace dialogs (e.g., the Mac 32-bit deprecation warning via `IDEDidComputeMac32BitWarning`). It does not control project format migration.

### Pros
- Would be the ideal solution if it existed

### Cons
- No such setting exists as of Xcode 16.x

### Verdict
**Not viable.** Apple does not provide a mechanism to lock the project file format version.

---

## Recommended Strategy for DailyCommuter

Given the current state of the project (committed objectVersion 60 but Xcode keeps reverting it to 70, PBXFileSystemSynchronizedRootGroup present, manually-added widget extension), here is a prioritized action plan:

### Immediate (do now)

1. **Pin the EAS Build image** (Solution 4)
   - Add `"image": "macos-sequoia-15.5-xcode-16.4"` (the `sdk-53` image) to each build profile in `eas.json`. This ensures builds succeed regardless of the project format. The current `eas.json` has no `image` field at all, so builds use the default image which may not match the project's Xcode requirements.

2. **Convert PBXFileSystemSynchronizedRootGroup to PBXGroup** (Solution 3b)
   - In Xcode, right-click the `ctaTimes` folder and select "Convert to Group"
   - Verify objectVersion remains at 60 (or reset it if Xcode changes it)
   - This must be done **before** deploying CI checks or hooks that validate synchronized groups, since the committed project file already contains them

3. **Add a CI validation check** (Solution 2)
   - Create the GitHub Actions workflow to validate objectVersion and block PRs that introduce further format upgrades.
   - Only deploy this after step 2 is completed, otherwise it will block all PRs touching pbxproj.

4. **Add a pre-commit hook** (Solution 1)
   - Install Husky or Lefthook and add the objectVersion check. This gives instant local feedback.
   - Only deploy this after step 2 is completed, for the same reason.

### Long-term (permanent solution)

5. **Migrate the widget to a config plugin** (Solution 5c / 7b)
   - Adopt `@bacons/apple-targets` or a custom config plugin to manage the ctaTimes widget extension
   - Move widget Swift source files to `targets/ctaTimes/` outside the `ios/` directory
   - This enables `expo prebuild --clean` to safely regenerate the entire `ios/` directory
   - The objectVersion is then controlled by Expo's prebuild template, not by Xcode

---

## References

- [CocoaPods/Xcodeproj - objectVersion Constants](https://github.com/CocoaPods/Xcodeproj/blob/master/lib/xcodeproj/constants.rb)
- [Fastlane Issue #22265 - PBXFileSystemSynchronizedRootGroup](https://github.com/fastlane/fastlane/issues/22265)
- [CocoaPods Issue #12456 - Unknown ISA PBXFileSystemSynchronizedRootGroup](https://github.com/CocoaPods/CocoaPods/issues/12456)
- [EvanBacon/xcode Issue #17 - Xcode 16 new ISA type](https://github.com/EvanBacon/xcode/issues/17)
- [EAS Build Server Infrastructure](https://docs.expo.dev/build-reference/infrastructure/)
- [EAS Build Configuration (eas.json)](https://docs.expo.dev/build/eas-json/)
- [Expo Config Plugins - Mods](https://docs.expo.dev/config-plugins/mods/)
- [@bacons/apple-targets - Config Plugin for Apple Targets](https://github.com/EvanBacon/expo-apple-targets) (npm: `@bacons/apple-targets`, repo: `expo-apple-targets`)
- [How Synchronized Groups Work at the pbxproj Level](https://pepicrft.me/blog/how-synchronized-groups-work-at-the-pbxproj-level/) (Pedro Pinera)
- [Apple Developer Forums - Xcode Project Settings](https://developer.apple.com/forums/thread/16555)
- [Ionic - AppFlow and Extensions](https://ionic.zendesk.com/hc/en-us/articles/27939200396055-AppFlow-and-Extensions)
- [CocoaPods/Xcodeproj Issue #996 - objectVersion 70](https://github.com/CocoaPods/Xcodeproj/issues/996)
- [XcodeGen Issue #1505 - Updated Project Format for Xcode 16](https://github.com/yonaskolb/XcodeGen/issues/1505)
