# ESX Report System & Staff Analytics - Development Log

**Resource:** `esx_report`  
**Base:** ESX Legacy  
**Version:** v1.1.0  
**Date:** November 17, 2026  
**Status:** Production Verified  

---

## 1. Release v1.1.0 - Auto Database Injection & MySQL.ready Hook

* **Auto-Injection Guarantee**: Wired `server/database.lua` to `MySQL.ready`, eliminating any race condition with `oxmysql` on initial server boot.
* **Redundant Restart Protection**: Added duplicate check guards so restarting the resource mid-session safely verifies tables without re-running initialization.
* **Standalone SQL Script**: Provided [esx_report.sql](file:///c:/Users/Raven/Downloads/New%20Server%20Pack/txData/ESXLegacy_E69671.base/resources/[esx_addons]/esx_report/esx_report.sql) in resource root for manual reference or standalone imports.

---

## 2. Release v1.0.0 - Initial Release

Initial release of `esx_report`, a lightweight, standalone player support ticketing and staff productivity analytics resource for FiveM servers running ESX Legacy.

### Highlights
* **Pure Report Focus**: Completely stripped of all unrelated admin menu and ban bloat; no connection deferrals or ban checks.
* **Modern 3-Column Workspace**: Full-width high-efficiency NUI interface built in Svelte 5.
* **Proximity Suspect Snapshot**: Captures players within radius at report filing time with clickable IDs.
* **Live Ticket Messaging**: Real-time two-way communication between players and staff.
* **In-Ticket Staff Actions**: Instant `Goto`, `Bring`, and `Spectate` (with ESC exit protection).
* **Staff Analytics Leaderboard**: Tracks top claimers, responders, resolvers, resolution rates, and category distribution.
* **Discord Webhook**: Configurable webhook logging for submitted tickets.

## 2. Comprehensive Changelog

### A. 3-Column Reports Workspace Layout
* **Left Column (Report List)**:
  * Width optimized to `minmax(18vh, 22vh)` to maximize center workspace area.
  * Displays ticket number, title/category, status badge (`OPEN`, `CLAIMED`, `RESOLVED`), reporter name, claiming staff, and relative timestamps (`2 min ago`, etc.).
  * Real-time search by ID, title, reporter, or reason.
  * Status filters: `All`, `Open`, `Claimed`, `Resolved` with dynamic open badge count.
* **Center Column (Selected Report Workspace)**:
  * **Integrated Header (`selected-header`)**:
    * Row 1: Case ID, status badge, category chip, relative submission time, and action buttons (`Claim Ticket`, `Unclaim`, `Mark Resolved`, `Delete`).
    * Row 2: Full report title with clean word wrapping.
    * Row 3: Integrated **Reporter & Accused Player Strip**:
      * Reporter name and live server ID pill (`Online` / `Offline`).
      * One-click admin actions: `Goto` (teleport to reporter), `Bring` (teleport reporter to admin), and `Spectate`.
      * Accused player pill (if reported) with `Goto` and `Bring`.
  * **Report Description**: Initial reason box with auto-scrolling for lengthy text.
  * **Live Ticket Chat**: Real-time two-way conversation between player and staff with auto-scroll and send input.
* **Right Column (Active Staff & Nearby Players)**:
  * **Active Staff**: Real-time list of all staff members currently online with role badges (`Assigned` if claiming this ticket).
  * **Players at Report Time**: Historical snapshot of players within proximity at the moment the ticket was created.

---

### B. Player Report Submission Modal
* Changed the modal input from asking for "Reported Player ID" to **Report Title** (`Required`).
* Added an optional target player ID field.
* Fixed server callback deferral (`return xLib.nui.defer`) to prevent "No response from server" timeouts.

---

### C. Database & Server Architecture
* **Schema Updates (`server/database.lua`)**:
  * Added `title VARCHAR(128)` to `admin_reports`.
  * Added `players_snapshot LONGTEXT` and `staff_snapshot TEXT` to `admin_reports`.
  * Preserved `admin_report_messages` for audit trails and conversation persistence.
* **JSON Serialization Bugfix (`server/reports.lua`)**:
  * Resolved `SCRIPT ERROR: type 'function' is not supported by JSON` by implementing `resolvePlayerSource`, `resolvePlayerName`, and `resolvePlayerGroup` to strip Lua function closures and metatables before JSON encoding.
* **Configurable Nearby Player Snapshot (50m GTA Units)**:
  * Added `Config.Reports.NearbyPlayerRadius = 50.0` in `shared/config.lua`.
  * Server calculates vector distance `#(reporterCoords - targetCoords)` for all online players at report submission time.
  * Snapshot automatically records player ID, name, staff status, and distance (in meters).
  * Always guarantees inclusion of the reporter and the accused target player regardless of distance.
  * Players are sorted in Column 3: Reporter first, Accused second, then ascending distance.

---

### D. NUI Focus & Mouse Trap Bugfix
* **Root Cause**: When a ticket was marked as resolved, the server triggered `esx-adminmenu:client:onReportClosed` to the reporter. When an admin tested resolving their own ticket, `closePlayerTicket()` in `user.svelte.ts` called `this.close()` unconditionally. This set `uiState.visible = false` on the entire dashboard, but FiveM still held `SetNuiFocus(true, true)`. Because the UI DOM was unmounted, the mouse cursor was permanently stuck and the camera/player could not move in GTA.
* **Fix**:
  * Updated `closePlayerTicket()` in `user.svelte.ts` so it **only** closes the UI if `this.mode === 'player_ticket' || this.mode === 'report'`, and properly calls `fetchNui("releaseFocus")`. If in `dashboard` mode, the dashboard remains active.
  * Added safety checks in `client/reports.lua` to release focus when in `report` mode.
  * Added Escape key interception in `App.svelte` and `ReportsManagement.svelte` so pressing `Escape` closes the resolve modal without dismissing the admin menu.

---

### E. Live Chat Messaging Bridge
* **Root Cause**: In `client/nui.lua`, `serverBridges` for `sendReportMessage` omitted `forward = { "message" }`. As a result, the bridge stripped `res.message` and returned `{ success = true }`. In Svelte, `if (res?.success && res.message)` evaluated to `false`, causing the `"Failed to send message."` error toast.
* **Fix**:
  * Added `forward = { "message" }` in `client/nui.lua`.
  * Made Svelte handlers in both `ReportsManagement.svelte` and `PlayerTicketChat.svelte` accept `res?.success` with an optimistic local fallback if `res.message` is absent.
  * Unified permissions check across all report endpoints via `isStaffMember()`.

---

### F. Blank `ox_lib` Notification Fix
* **Root Cause**: `server/reports.lua` called `TriggerClientEvent("esx:showNotification", ...)` passing only `(source, message, "info")` without a `title` or `duration`. When `es_extended` delegated to `ox_lib:notify`, the absence of `title` caused Mantine's notification component to collapse into a blank box.
* **Fix**:
  * Updated all report notification triggers to pass explicit structured parameters: `(message, type, duration, title)`.
  * Titles now display clearly (e.g., `Staff: Hairi Raven`, `Report #2 - Hairi Raven`, `Report Claimed`, `Report Resolved`).

---

## 3. Modified Files Summary

| File Path | Type | Modifications |
| :--- | :--- | :--- |
| `shared/config.lua` | Config | Added `Config.Reports.NearbyPlayerRadius = 50.0` with documentation. |
| `server/database.lua` | Server | Schema migrations for `title`, `players_snapshot`, and `staff_snapshot`. |
| `server/reports.lua` | Server | Sanitized player serializers, 50m radius snapshot, unified `isStaffMember`, titled notifications, chat delivery. |
| `client/nui.lua` | Client | Added message and report forwarding for NUI bridges; fixed callback deferral for `submitReport`. |
| `client/reports.lua` | Client | Added titled notifications for report alerts; focus safety check on `onReportClosed`. |
| `web/src/lib/tabs/reports/ReportsManagement.svelte` | Web / UI | 3-column layout, integrated header reporter strip, Svelte 5 runes (`$derived.by`), modal Escape handling. |
| `web/src/lib/tabs/reports/PlayerTicketChat.svelte` | Web / UI | Resilient message sending logic, focus release on ticket close. |
| `web/src/lib/tabs/reports/types/report.ts` | Web / Types | Added `distance?: number \| null` to `SnapshotPlayer`. |
| `web/src/lib/shared/stores/user.svelte.ts` | Web / Store | Fixed `closePlayerTicket()` to prevent hiding admin dashboard and avoid mouse lock. |
| `web/src/App.svelte` | Web / App | Escape key modal backdrop protection. |

### G. UI Ergonomics & Proportions Overhaul
* **Window Dimensions (`app.css`)**:
  * Increased `.esx-adminmenu-container` height from `74vh` to `78vh` (with `max-height: 86vh`), providing ~65–85px more vertical canvas while preserving comfortable 11% top/bottom screen margins.
  * Tightened interior padding (`1.4vh 1.8vh`) and element gap (`1.6vh`).
* **Center Workspace (Live Chat & Header Focus)**:
  * Compacted `.selected-header` padding and case title typography (`1.35vh`).
  * Integrated dedicated green `Resolved by:` pill (and blue `Claimed by:` pill) directly into `.header-parties-strip` next to the reporter details.
  * Fixed duplicate resolution text: suppressed the lower resolution banner for default fallback strings (`"Resolved by staff."`, `"Closed by player."`). Only custom admin notes now display in a dedicated callout banner.
  * Redesigned "Initial Report Description" into a compact quote-style callout (`max-height: 5.5vh`, amber accent left border).
  * Allowed the `.chat-section` and `.chat-stream` to flex to 100% of remaining vertical height without artificial height cutoffs, doubling visible chat message capacity.
* **Right Column Rebalance**:
  * Limited `.staff-section` to `max-height: 20vh`, eliminating dead space when only 1–3 staff members are online.
  * Granted `flex: 1` to `.players-snapshot-section`, allowing the nearby players list to expand and provide superior scrolling when reviewing 10+ nearby players.
* **Server-Side Resolver Assignment**:
  * In `server/reports.lua`, ensured `claimed_name` reflects the staff member executing the resolution if previously unclaimed.

### H. Server Population Density Override Fix
* **Root Causes**:
  1. **Strict Type Failure in Lua**: In `server/helpers.lua`, `setPopulationDensity` checked `type(value) ~= "number"`. HTML range inputs in the web client often serialize bound values as strings (e.g., `"1"`). When received on the server, `"1"` is of type `"string"`, causing Lua to fail validation with `"Density values must be numbers between 0 and 1."` and reject the change.
  2. **Silent Failure in Web Action**: In `ServerManagement.svelte`, `action()` lacked an error handler (`else { notifications.error(res?.err) }`), so server rejections were swallowed silently.
  3. **Reset to Zero / Sticky Nil State**: When `densityEnabled` was set to `false` or server defaults were restored, `server/helpers.lua` and `client/init.lua` passed `nil` instead of `1.0` (100% normal density). The web store kept whatever previous or zero value was cached, causing the sliders to reset back to 0%.
* **Fixes Applied**:
  * In `server/helpers.lua`, used `local num = tonumber(data[key])` so both numeric floats and stringified numbers are accepted and validated.
  * In `server/helpers.lua`, when `enabled == false` (restoring defaults), reset `serverEnvironment` density values to `1.0`.
  * In `client/init.lua`, updated `AddStateBagChangeHandler` to forward `1.0` (100%) when `densityEnabled` is disabled.
  * In `ServerManagement.svelte`, coerced slider values with `Number()` in `applyDensity()` and added proper error notifications for all server management actions.
  * In `server.svelte.ts`, handled `null`/`undefined` fallbacks to reset sliders to `1.0` whenever server defaults are restored.

### I. Dedicated Reports & Staff Analytics Resource Transition (Direct Workspace)
* **Complete External Backups Preserved**:
  * `c:\Users\Raven\Downloads\New Server Pack\backup\esx_adminmenu_FULL_BACKUP.zip` (22 MB compressed archive).
  * `c:\Users\Raven\Downloads\New Server Pack\backup\esx_adminmenu_full/` (full uncompressed clone).
* **Direct Workspace Mode (Sidebar Removed)**:
  * Eliminated the left navigation sidebar (`Sidebar.svelte`) completely from `App.svelte`.
  * The 3-column ticket manager now spans the entire 100% width of the menu container.
  * Rebalanced columns: Column 1 (`minmax(24vh, 28vh)`), Center Ticket & Live Chat (`1fr`), Column 3 Staff & Proximity Snapshot (`minmax(30vh, 34vh)`).
* **Top Bar View Switching (`UpperDisplay.svelte`)**:
  * Title updated to **"Support & Reports"** with subtitle **"Player Tickets & Staff Analytics"**.
  * Added a segmented view toggle directly in the top bar:
    * `[ 🎫 Tickets Workspace ]`
    * `[ 📊 Staff Analytics ]`
  * Removed the quick admin wheel switch button to dedicate the resource exclusively to player reports and staff performance.
* **Full Staff & Ticket Analytics Dashboard (`ReportsAnalytics.svelte`)**:
  * **Summary KPI Cards**: Total Tickets Handled (All time, Today, 7-day), Resolution Rate (%) with progress bar, Active Backlog (Open vs Claimed), and Total Chat Messages / Staff Messages.
  * **3 Performance Leaderboards**:
    1. **Most Tickets Claimed**: Ranks top staff by cases claimed (Gold 🥇, Silver 🥈, Bronze 🥉 badges, share bar).
    2. **Most Active in Chat (Top Responders)**: Ranks staff by total chat messages sent to players.
    3. **Most Resolved Cases**: Ranks staff by total tickets resolved.
  * **Category Distribution**: Breakdown of report categories (Player Report, Bug Report, Question, etc.) with count and percentages.
  * **Real-Time Data & Refresh**: Manual refresh button with animated spinner and last-synced timestamp.
  * **Dev Mode Fallback**: Provides comprehensive mock data in browser (`!isChromium()`) for fast UI testing.
* **Backend Analytics Engine (`server/reports.lua` & `client/nui.lua`)**:
  * Added callback `"esx-adminmenu:server:report:getAnalytics"` querying `admin_reports` and `admin_report_messages` for KPI metrics and top 10 leaderboards.
  * Registered NUI bridge `getReportAnalytics` in `client/nui.lua` and typed API fetcher in `admin.ts`.
* **Staff Command (`client/reports.lua`)**:
  * Added `/reports` command for staff to open the Tickets & Analytics dashboard directly.
  * `/report` preserved for players to open their active ticket or file a new case.
* **Production Optimization**:
  * Web bundle size reduced from 261 kB to **114 kB** (over 56% size reduction) with 0 errors.

### J. Unused Codebase Cleanup & Command Restructuring
* **Command Restructuring**:
  * **Player Report**: Dedicated to `/report`. Opens the report submission modal if no active ticket exists, or opens the live two-way chat stream with staff if an active case is ongoing.
  * **Admin Reports Dashboard**: Dedicated to `/reports`. Opens the full Support Reports & Staff Analytics Dashboard for authorized staff (with `/admindashboard` and `/admin` maintained as aliases for backward compatibility).
  * Registered chat suggestions:
    * `/report`: "Submit a player report or open your active ticket chat"
    * `/reports`: "Open the Staff Reports & Analytics Dashboard"
  * Added optional keybinding support for both `report` and `reports` in `Config.Keybinds`.
* **Frontend Pruning & Bundle Reduction**:
  * Removed all unused tabs: `web/src/lib/tabs/admin-logs/`, `admin-menu/`, `dashboard/`, `players/`, `server/`.
  * Removed legacy layout components: `Sidebar.svelte`, `TabContent.svelte`, `Sidebar.css`, `config/sidebar.ts`, `types/sidebar.ts`, and `navigation.svelte.ts`.
  * Refactored `user.svelte.ts` into a lightweight reactive store dedicated to reports, active chats, categories, online players, and spectator mode.
  * Refactored `admin.ts` to expose only report actions, spectator/teleport helpers (`goto`, `bring`, `spectate`, `stopSpectate`), and analytics APIs.
  * Self-contained `PlayerTicketChat.svelte` and `ReportsManagement.svelte` using shared `relativeTime` and `player.ts` types.
  * Production web bundle dropped from 261 kB to **106 kB** (approx. 60% reduction) with clean 2.2s compile time.

---

## 4. Verification Checklist
- [x] Client/server Lua code parsed without runtime syntax errors.
- [x] Svelte 5 frontend compiled cleanly via Vite (`npm run build`).
- [x] Ticket chat message delivery tested and verified.
- [x] Ticket resolve does not freeze mouse or dismiss admin menu.
- [x] In-game report notification displays bold title and message content cleanly.
- [x] "Resolved by" pill displays in header strip next to reporter details.
- [x] Redundant "Resolved by staff." text duplicate eliminated.
- [x] UI resized to 78vh with maximized live chat vertical clearance.
- [x] Population density slider values parse numbers correctly without resetting to 0%.
- [x] Full external backup verified outside resource directory.
- [x] Left navigation sidebar removed; workspace expanded to 100% width.
- [x] Segmented view switcher (`Tickets Workspace` / `Staff Analytics`) added to top bar.
- [x] Staff Leaderboards for Claims, Chat Responses, and Resolutions implemented.
- [x] `/reports` staff command added and verified.
- [x] Unused frontend tabs, legacy sidebar, and dead code pruned cleanly without breaking dependencies.
- [x] `/report` (player) and `/reports` (staff) commands mapped and registered with chat suggestions.

---

## 5. Completed Tasks
- [x] Move "Resolved by" to Header strip.
- [x] Fix duplicate resolution notes text.
- [x] Optimize 3-column element layout and chat dominance.
- [x] Expand window dimensions to 78vh.
- [x] Fix Server Environment population density slider & persistence bug.
- [x] External backup outside resource folder.
- [x] Transition resource to dedicated Reports & Staff Analytics system (Direct Workspace).
- [x] Full Ticket & Staff Analytics dashboard with leaderboards.
- [x] Cleanup unrelated and unused code (tabs, stores, dummy data) without breaking dependencies.
- [x] Set primary commands: Player Report = `/report`, Staff Dashboard = `/reports`.

