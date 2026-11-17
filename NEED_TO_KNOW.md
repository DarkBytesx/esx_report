# Developer Guide & "Need to Know" Manual

**Resource:** `esx_report`  
**Purpose:** Developer Architecture, Internal Mechanics, Critical Pitfalls, and Maintenance Guide.  

---

## 1. System Architecture

The resource is divided into three interconnected layers:

```
+-----------------------------------------------------------------------------------+
|                                 Svelte 5 Web UI                                   |
|   App.svelte  -->  UpperDisplay.svelte (Header & View Switcher)                   |
|               -->  ReportsManagement.svelte (3-Column Staff Workspace)            |
|               -->  ReportsAnalytics.svelte (KPIs & Leaderboards)                 |
|               -->  ReportModal.svelte (Submission Dialog)                         |
|               -->  PlayerTicketChat.svelte (Player Live Drawer)                   |
+-----------------------------------------+-----------------------------------------+
                                          | NUI Message / Fetch Bridge
+-----------------------------------------v-----------------------------------------+
|                                Client Lua Runtime                                 |
|   client/reports.lua  : Command registration, keymapping, sound alerts            |
|   client/nui.lua      : NUI event listeners, focus toggling, RPC callbacks       |
|   client/actions.lua  : Camera spectator thread, Goto/Bring client execution      |
+-----------------------------------------+-----------------------------------------+
                                          | Server Net Events / Callbacks
+-----------------------------------------v-----------------------------------------+
|                                Server Lua Backend                                 |
|   server/reports.lua  : Intake, assignment, live messaging, analytics queries    |
|   server/commands.lua : Permission-checked ESX command registrations              |
|   server/database.lua : oxmysql schema auto-migrations                            |
|   server/actions.lua  : Server-side Goto, Bring, and Spectate permission handlers |
+-----------------------------------------------------------------------------------+
```

---

## 2. Database Schema & Tables

All database operations use **`oxmysql`** with parameterized queries and async/await syntax. Schema migrations run automatically upon resource initialization in [server/database.lua](file:///c:/Users/Raven/Downloads/New%20Server%20Pack/txData/ESXLegacy_E69671.base/resources/[esx_addons]/esx_report/server/database.lua).

### Table: `admin_reports`
Main storage for player tickets and case histories.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `INT AUTO_INCREMENT` | Unique Ticket ID (Primary Key). |
| `reporter_identifier` | `VARCHAR(64)` | Player's primary rockstar/license identifier. |
| `reporter_name` | `VARCHAR(64)` | Player's character name. |
| `reporter_source` | `INT` | Live server ID of the player at creation time. |
| `title` | `VARCHAR(128)` | Case subject / title headline. |
| `category` | `VARCHAR(64)` | Category identifier (e.g. `player`, `bug`, `rule_break`). |
| `target_id` | `INT NULL` | Optional server ID of the reported/accused player. |
| `target_name` | `VARCHAR(64) NULL` | Accused player character name. |
| `target_identifier` | `VARCHAR(64) NULL` | Accused player license identifier. |
| `reason` | `TEXT` | Initial report description written by player. |
| `status` | `ENUM('open', 'claimed', 'resolved')` | Current lifecycle state of the ticket. |
| `claimed_by` | `VARCHAR(64) NULL` | Staff member's license identifier. |
| `claimed_name` | `VARCHAR(64) NULL` | Staff member's character/staff name. |
| `notes` | `TEXT NULL` | Custom resolution notes left by staff upon closing. |
| `players_snapshot` | `LONGTEXT NULL` | JSON array of nearby players (within 50m) at report time. |
| `staff_snapshot` | `TEXT NULL` | JSON array of staff online at report time. |
| `created_at` | `TIMESTAMP` | Ticket creation timestamp. |
| `updated_at` | `TIMESTAMP` | Timestamp of last activity or resolution. |

### Table: `admin_report_messages`
Stores conversation records between players and staff.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `INT AUTO_INCREMENT` | Unique Message ID (Primary Key). |
| `report_id` | `INT` | Foreign key referencing `admin_reports(id)`. |
| `sender_identifier`| `VARCHAR(64)` | Sender's license identifier. |
| `sender_name` | `VARCHAR(64)` | Sender's character or staff display name. |
| `is_staff` | `TINYINT(1)` | `1` for staff reply, `0` for player message. |
| `message` | `TEXT` | Message content. |
| `created_at` | `TIMESTAMP` | Message timestamp. |

---

## 3. Critical Developer Gotchas & Pitfalls

> [!CAUTION]
> Read these rules carefully before modifying the codebase. Violating them can cause stuck cursors in FiveM, unhandled script crashes, or blank notification boxes.

### 1. NUI Focus & Mouse Trap Rules
* **The Problem**: In FiveM, if the frontend unmounts (`uiState.visible = false`) while FiveM still has `SetNuiFocus(true, true)` active, the mouse cursor becomes permanently frozen on the screen and the user cannot look around or walk in GTA.
* **The Rule**: Always pair UI dismissals with `fetchNui("releaseFocus", { release: true })`.
* **Case in Point**: In [user.svelte.ts](file:///c:/Users/Raven/Downloads/New%20Server%20Pack/txData/ESXLegacy_E69671.base/resources/[esx_addons]/esx_report/web/src/lib/shared/stores/user.svelte.ts), `closePlayerTicket()` specifically checks:
  ```ts
  if (this.mode === "player_ticket" || this.mode === "report") {
      this.close();
      void fetchNui("releaseFocus", { release: true });
  }
  ```
  If a staff member marks a report resolved from inside the dashboard (`mode === "dashboard"`), `closePlayerTicket()` does **not** close the dashboard.

### 2. JSON Serialization Pitfall
* **The Problem**: FiveM's native `json.encode()` in Lua throws:
  `SCRIPT ERROR: type 'function' is not supported by JSON`
  if you pass a raw ESX `xPlayer` table, an object containing metatables, or function closures (such as `xPlayer.getCoords()`).
* **The Rule**: Never pass raw table objects into `json.encode()`. In [server/reports.lua](file:///c:/Users/Raven/Downloads/New%20Server%20Pack/txData/ESXLegacy_E69671.base/resources/[esx_addons]/esx_report/server/reports.lua), sanitize every field:
  ```lua
  local cleanSnapshot = {}
  for _, p in ipairs(nearbyPlayers) do
      cleanSnapshot[#cleanSnapshot + 1] = {
          id = tonumber(p.id) or 0,
          name = tostring(p.name or "Unknown"),
          is_staff = p.is_staff == true,
          distance = p.distance and math.floor(p.distance * 10) / 10 or nil
      }
  end
  local jsonString = json.encode(cleanSnapshot)
  ```

### 3. ox_lib Notification Blank Box Bug
* **The Problem**: Modern `es_extended` builds delegate `ESX.ShowNotification` directly to `ox_lib:notify`. If a notification is triggered without a title, Mantine's React container collapses into a blank black pill.
* **The Rule**: Always supply a 4-argument signature:
  ```lua
  TriggerClientEvent("esx:showNotification", targetSource, messageText, notificationType, durationMs, titleText)
  ```
  Example:
  ```lua
  TriggerClientEvent("esx:showNotification", xPlayer.source, "Your report has been claimed.", "info", 5000, "Support Update")
  ```

### 4. Svelte 5 Runes & Placement Constraints
* This project is compiled using **Svelte 5** and **Vite 7**.
* All state is declared using `$state()`, `$derived()`, or `$derived.by()`.
* **Important**: Do not place `{@const}` tags as direct children of non-block container elements (e.g. naked `<div>`). Compute derived values in the `<script>` tag using `$derived()` instead:
  ```ts
  // Correct Svelte 5 practice:
  const maxClaims = $derived(analyticsData?.topClaimers?.[0]?.count || 1);
  ```

### 5. Local Browser Development (`!isChromium()`)
* The frontend includes automatic fallback mock data inside `loadAnalytics()` and `generateDummyPlayers()`.
* Running `npm run dev` in `web/` will automatically display realistic reports, chat threads, and leaderboard stats inside Chrome/Edge/Firefox, allowing rapid UI iteration without having to restart FiveM.

---

## 4. Frontend Build Workflow

The web client is located in `web/`:

```powershell
# Navigate to web directory
cd "c:\Users\Raven\Downloads\New Server Pack\txData\ESXLegacy_E69671.base\resources\[esx_addons]\esx_report\web"

# Install dependencies (if setting up fresh)
npm install

# Start Vite dev server for browser preview
npm run dev

# Compile production build for FiveM
npm run build
```

When `npm run build` runs, it outputs optimized assets to `web/dist/`, which is declared in `fxmanifest.lua`. The production bundle size is approximately **106 kB**.

---

## 5. Adding New Report Categories

To add or modify ticket categories, edit [shared/config.lua](file:///c:/Users/Raven/Downloads/New%20Server%20Pack/txData/ESXLegacy_E69671.base/resources/[esx_addons]/esx_report/shared/config.lua):

```lua
Config.Reports.Categories = {
    { id = "player", label = "Player Report" },
    { id = "rule_break", label = "Rule Break / Griefing" },
    { id = "bug", label = "Bug / Glitch" },
    { id = "question", label = "Question / Help" },
    { id = "billing", label = "Tebex / Donation Issue" }, -- New category
    { id = "other", label = "Other" },
}
```

The submission modal, filter pills, and analytics charts will automatically adapt without requiring changes to Lua or Svelte files.
