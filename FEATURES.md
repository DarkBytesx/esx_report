# Support Reports & Staff Analytics - Feature Documentation

**Resource:** `esx_report`  
**Framework:** ESX Legacy (v1.16+)  
**Category:** Administrative & Player Support System  
**Design System:** ESX UI Kit (Dark Theme / Amber `#FB9B04` Accent)  

---

## 1. Overview

`esx_report` is a dedicated, high-performance **Player Support & Staff Analytics Resource**. It replaces bloated multi-purpose admin menus with a focused workspace engineered specifically for ticketing, dispute management, in-game communication, and staff productivity tracking.

The system caters to two distinct server audiences:
1. **Players**: Can quickly report griefing, bugs, rule violations, or request assistance via `/report`, and maintain an active live chat with staff.
2. **Staff Members**: Can manage incoming tickets through a 3-column direct workspace via `/reports`, teleport/spectate involved parties, inspect nearby players at report time, and review staff performance leaderboards.

---

## 2. Core Commands & Access Points

| Command | Target Audience | Functionality | Optional Keybind |
| :--- | :--- | :--- | :--- |
| `/report` | **All Players** | Opens clean report submission dialog (if no active ticket) or resumes active ticket chat drawer. | `Config.Keybinds.Report` (e.g., `F10`) |
| `/reports` | **Staff / Admins** | Opens the Support Reports Workspace & Staff Analytics Dashboard. | `Config.Keybinds.Reports` (e.g., `F9`) |
| `/admindashboard` | **Staff / Admins** | Backward-compatible alias for `/reports`. | — |
| `/admin` | **Staff / Admins** | Backward-compatible alias for `/reports`. | — |

---

## 3. Player Support System (`/report`)

### A. Report Submission Modal
* **Case Title (`Required`)**: Clear subject headline for quick staff triage.
* **Category Selector**: Configurable categories (e.g., *Player Report*, *Rule Break / Griefing*, *Bug / Glitch*, *Question / Help*, *Other*).
* **Accused Player ID (`Optional`)**: Numerical server ID of the player being reported.
* **Description (`Required`)**: Detailed narrative of what occurred.
* **Anti-Spam Protections**:
  * Configurable cooldown timer between submissions (default: 60s).
  * Maximum active reports threshold per player (default: 2 open cases).

### B. Live Ticket Drawer (`PlayerTicketChat.svelte`)
* **Real-Time Two-Way Messaging**: Players communicate directly with staff without cluttering server-wide chat.
* **Case Status Indicators**: Live badge updates (`OPEN`, `CLAIMED`, `RESOLVED`).
* **Staff Identification**: Shows which staff member claimed the case and sent each message.
* **Auto-Scroll Stream**: Chat container automatically follows active dialogue.
* **Close Ticket Option**: Players can resolve or dismiss their own ticket once satisfied.

---

## 4. Staff Support Workspace (`/reports`)

The staff dashboard utilizes a **Direct Workspace Layout** without sidebar menus, dedicating 100% of the UI width to ticket resolution.

```
+----------------------------------------------------------------------------------------------------+
|  [SHIELD] Support & Reports       [ 🎫 Tickets Workspace ]   [ 📊 Staff Analytics ]    Uptime | Players [X]|
+----------------------------------------------------------------------------------------------------+
|  [ Col 1: Report List ]   |   [ Col 2: Active Case & Live Chat ]   |  [ Col 3: Staff & Proximity ] |
|  - All / Open / Claimed   |   - Case Header & Status Badges        |  - Active Online Staff List   |
|  - Live Search Box        |   - One-Click Goto / Bring / Spectate  |  - Nearby Players at Time     |
|  - Ticket Cards w/ Meta   |   - Initial Report Description Callout |    of Report (50m radius)     |
|                           |   - Live Two-Way Staff-Player Chat     |  - Distance / Role Badges     |
|                           |   - Reply Box & Quick Actions          |  - Interactive ID Copy Badges |
+----------------------------------------------------------------------------------------------------+
```

### Column 1: Report Intake & Queue
* **Status Filtering Tabs**:
  * `All`: Displays entire case history.
  * `Open`: Filters for unassigned cases with dynamic numerical badge counter.
  * `Claimed`: Shows cases currently handled by staff.
  * `Resolved`: Completed case archives.
* **Instant Search**: Real-time filtering by Report ID, reporter name, accused name, or description keyword.
* **Card Metadata**: Displays Case `#ID`, Title, Category tag, Reporter name, Claiming staff, and relative timestamps (`2 min ago`, etc.).

### Column 2: Selected Case & Live Chat
* **Integrated Header Strip**:
  * Ticket `#ID`, status badge, category chip, and relative submission time.
  * Staff claim controls: `Claim Ticket`, `Unclaim`, `Mark Resolved` (with custom resolution notes modal), and `Delete`.
* **Reporter & Accused Player Strip**:
  * Reporter name and live server ID badge (`Online` / `Offline`).
  * One-click admin actions:
    * `Goto`: Teleports staff directly to player coordinates.
    * `Bring`: Teleports player directly to staff coordinates.
    * `Spectate`: Enters live camera spectate mode with Escape/Backspace exit prompt.
  * Accused player name and ID badge (with dedicated `Goto` and `Bring` controls).
  * Dedicated `Resolved by:` pill showing the closing staff member.
* **Initial Description Callout**: Compact quote-style box with amber left border.
* **Live Ticket Chat Stream**: Real-time messaging stream between staff and the reporting player. Auto-scrolls and differentiates staff replies with green tags.

### Column 3: Context & Proximity Investigation
* **Active Online Staff**:
  * Live roster of staff members currently on the server.
  * Highlights assigned staff handling the active ticket.
* **Players at Report Time (Historical Proximity Snapshot)**:
  * When a report is submitted, the server automatically captures a snapshot of all online players within a configurable radius (default: **50m GTA units**).
  * Displays:
    * Interactive **ID Badge** (click to copy player server ID directly to clipboard).
    * Player Character Name.
    * Distance from reporter at report time (e.g. `12.4m`).
    * Role badges: `Reporter` (gold), `Accused` (red), `Staff` (green).
  * Includes search/filter bar to locate specific suspects instantly.

---

## 5. Staff Performance & Ticket Analytics

Accessible via the `[ 📊 Staff Analytics ]` tab in the top navigation bar.

### A. Summary KPI Cards
1. **Total Tickets Handled**:
   * All-time cumulative reports.
   * Today's incoming volume.
   * Last 7 days intake.
2. **Resolution Rate**:
   * Percentage calculation (`Resolved / Total * 100`).
   * Visual progress bar.
3. **Active Backlog**:
   * Real-time breakdown of `Open` (awaiting staff) vs `Claimed` (work in progress).
4. **Chat Engagement**:
   * Total messages exchanged across all cases.
   * Staff response message count.

### B. Three Performance Leaderboards
1. **Most Tickets Claimed**:
   * Ranks staff who proactively take ownership of incoming tickets.
   * Displays rank medals (🥇 Gold, 🥈 Silver, 🥉 Bronze), staff name, claim count, and proportional share bar.
2. **Most Active in Chat (Top Responders)**:
   * Ranks staff by total messages sent to players in active ticket chats.
   * Quantifies communication effort and player assistance.
3. **Most Resolved Cases**:
   * Ranks staff who successfully investigate and conclude cases.

### C. Category Distribution
* Visual distribution of tickets categorized by type (*Player Report*, *Bug / Glitch*, *Rule Break*, *Question / Help*, *Other*).
* Includes raw counts and calculated percentages.

### D. Live Controls
* **Refresh Button**: Manual on-demand recalculation with animated spinning indicator.
* **Last Synced Timestamp**: Clear audit trail of when metrics were last updated.

---

## 6. Audio-Visual Feedback & Alerts
* **Staff Sound Alert**: Audible chime (`Event_Message_Purple`) played whenever a new report is filed.
* **In-Game Notifications**: Rich titled notification popups across both `ox_lib` and standard ESX showing case ID, reporter, and summary.
