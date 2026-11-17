<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
	import { onMount, onDestroy, tick } from "svelte";
	import {
		fetchReports,
		claimReport,
		unclaimReport,
		resolveReport,
		deleteReport,
		gotoPlayer,
		bringPlayer,
		spectatePlayer,
		getReportMessages,
		sendReportMessage,
	} from "$lib/shared/nui/admin";
	import { notifications } from "$lib/shared/stores/notifications.svelte";
	import { uiState } from "$lib/shared/stores/user.svelte";
	import { getTimestampMs, relativeTime } from "$lib/shared/util/formatter";
	import { isChromium } from "$lib/shared/util/util";
	import type { AdminReport, ReportMessage, OnlineStaffMember, SnapshotPlayer } from "./types/report";

	// --- State ---
	let reports = $state<AdminReport[]>([]);
	let loading = $state(false);
	let statusFilter = $state<"all" | "open" | "claimed" | "resolved">("all");
	let search = $state("");
	let openCount = $state(0);

	// Column 2: Selected Report & Chat
	let selectedReport = $state<AdminReport | null>(null);
	let chatMessages = $state<ReportMessage[]>([]);
	let chatInput = $state("");
	let chatLoading = $state(false);
	let chatSending = $state(false);
	let chatContainer = $state<HTMLDivElement | null>(null);

	// Column 3: Active Staff & Player Snapshot
	let onlineStaff = $state<OnlineStaffMember[]>([]);
	let playerSearch = $state("");

	// Resolve Modal
	let resolvingReport = $state<AdminReport | null>(null);
	let resolveNotes = $state("");
	let actionLoading = $state(false);

	let searchTimer: ReturnType<typeof setTimeout> | undefined;

	// Mock data for preview outside FiveM CEF
	function getMockReports(): AdminReport[] {
		return [
			{
				id: 1,
				title: "VDM at Legion Square bank",
				category: "Rule Break / Griefing",
				reason: "A black Buffalo STX repeatedly ran over pedestrians at Legion Square without initiating RP. Left the scene towards Pillbox.",
				status: "open",
				reporter_identifier: "license:1111",
				reporter_name: "John Doe",
				reporter_source: 12,
				reporter_online: true,
				reporter_current_source: 12,
				target_identifier: "license:2222",
				target_name: "BadGuy_99",
				target_source: 34,
				target_online: true,
				target_current_source: 34,
				created_at: Date.now() - 1000 * 60 * 12,
				players_snapshot: [
					{ id: 12, name: "John Doe", is_staff: false },
					{ id: 34, name: "BadGuy_99", is_staff: false },
					{ id: 1, name: "Admin_Raven", is_staff: true, group: "superadmin" },
					{ id: 5, name: "Sarah Connor", is_staff: false },
					{ id: 8, name: "Mike Wheeler", is_staff: false },
					{ id: 14, name: "Arthur Morgan", is_staff: false },
				],
				staff_snapshot: [
					{ id: 1, name: "Admin_Raven", is_staff: true, group: "superadmin" },
				],
			},
			{
				id: 2,
				title: "Car disappeared from garage",
				category: "Bug / Glitch",
				reason: "Spawned Sultan RS at Central Garage and it immediately despawned into the void. Need assistance to retrieve it.",
				status: "claimed",
				claimed_name: "Admin_Raven",
				claimed_by: "license:admin",
				reporter_identifier: "license:3333",
				reporter_name: "Arthur Morgan",
				reporter_source: 14,
				reporter_online: true,
				reporter_current_source: 14,
				created_at: Date.now() - 1000 * 60 * 45,
				players_snapshot: [
					{ id: 14, name: "Arthur Morgan", is_staff: false },
					{ id: 1, name: "Admin_Raven", is_staff: true, group: "superadmin" },
					{ id: 9, name: "Geralt of Rivia", is_staff: false },
				],
				staff_snapshot: [
					{ id: 1, name: "Admin_Raven", is_staff: true, group: "superadmin" },
				],
			},
			{
				id: 3,
				title: "Question regarding drug selling cooldown",
				category: "Question / Help",
				reason: "How long is the cooldown after selling weed to local NPCs? Does it reset on server restart?",
				status: "resolved",
				claimed_name: "Mod_Sarah",
				claimed_by: "license:mod",
				resolution_notes: "Explained server rules and cooldown timer in chat.",
				reporter_identifier: "license:4444",
				reporter_name: "Walter White",
				reporter_source: 19,
				reporter_online: false,
				reporter_current_source: null,
				created_at: Date.now() - 1000 * 60 * 180,
				players_snapshot: [
					{ id: 19, name: "Walter White", is_staff: false },
					{ id: 3, name: "Mod_Sarah", is_staff: true, group: "admin" },
				],
				staff_snapshot: [
					{ id: 3, name: "Mod_Sarah", is_staff: true, group: "admin" },
				],
			},
		];
	}

	async function scrollChatToBottom() {
		await tick();
		if (chatContainer) {
			chatContainer.scrollTop = chatContainer.scrollHeight;
		}
	}

	async function selectReport(report: AdminReport) {
		selectedReport = report;
		chatMessages = [];
		chatInput = "";
		chatLoading = true;

		try {
			if (!isChromium()) {
				// Provide mock chat conversation in dev preview
				chatMessages = [
					{
						id: 1,
						report_id: report.id,
						sender_identifier: report.reporter_identifier,
						sender_name: report.reporter_name,
						is_staff: 0,
						message: report.reason,
						created_at: report.created_at,
					},
					...(report.claimed_name
						? [
								{
									id: 2,
									report_id: report.id,
									sender_identifier: "license:staff",
									sender_name: report.claimed_name,
									is_staff: 1,
									message: `Hello ${report.reporter_name}, I am looking into this issue right now.`,
									created_at: Date.now() - 1000 * 60 * 5,
								},
						  ]
						: []),
				];
				void scrollChatToBottom();
				return;
			}

			const res = await getReportMessages(report.id);
			if (res.ok) {
				chatMessages = res.messages;
				void scrollChatToBottom();
			}
		} finally {
			chatLoading = false;
		}
	}

	async function loadReports(selectFirst = false) {
		if (loading) return;
		loading = true;

		try {
			if (!isChromium()) {
				const mock = getMockReports();
				let filtered = mock;
				if (statusFilter !== "all") {
					filtered = filtered.filter((r) => r.status === statusFilter);
				}
				if (search.trim() !== "") {
					const s = search.trim().toLowerCase();
					filtered = filtered.filter(
						(r) =>
							(r.title && r.title.toLowerCase().includes(s)) ||
							r.reporter_name.toLowerCase().includes(s) ||
							(r.target_name && r.target_name.toLowerCase().includes(s)) ||
							r.reason.toLowerCase().includes(s) ||
							String(r.id) === s
					);
				}
				reports = filtered;
				openCount = mock.filter((r) => r.status === "open").length;
				onlineStaff = [
					{ id: 1, name: "Admin_Raven", group: "superadmin" },
					{ id: 4, name: "Mod_Sarah", group: "admin" },
				];

				if (selectedReport) {
					const updated = reports.find((r) => r.id === selectedReport!.id);
					if (updated) {
						selectedReport = updated;
					} else if (reports.length > 0) {
						void selectReport(reports[0]);
					} else {
						selectedReport = null;
					}
				} else if (selectFirst && reports.length > 0) {
					void selectReport(reports[0]);
				}
				return;
			}

			const res = await fetchReports({
				status: statusFilter,
				search: search.trim() !== "" ? search.trim() : undefined,
				limit: 100,
			});

			if (res.ok) {
				reports = res.reports;
				openCount = res.openCount;
				if (res.onlineStaff && res.onlineStaff.length > 0) {
					onlineStaff = res.onlineStaff;
				} else if (uiState.players && uiState.players.length > 0) {
					onlineStaff = uiState.players
						.filter((p) => p.is_staff)
						.map((p) => ({
							id: Number(p.id) || 0,
							name: p.name,
							group: p.group || "Staff",
						}));
				}

				if (selectedReport) {
					const updated = reports.find((r) => r.id === selectedReport!.id);
					if (updated) {
						selectedReport = updated;
					} else if (reports.length > 0) {
						void selectReport(reports[0]);
					} else {
						selectedReport = null;
					}
				} else if (selectFirst && reports.length > 0) {
					void selectReport(reports[0]);
				}
			}
		} catch (e) {
			notifications.error("Failed to load reports.");
		} finally {
			loading = false;
		}
	}

	function onFilterChange(newFilter: "all" | "open" | "claimed" | "resolved") {
		statusFilter = newFilter;
		void loadReports(true);
	}

	function onSearchInput() {
		clearTimeout(searchTimer);
		searchTimer = setTimeout(() => {
			void loadReports(true);
		}, 300);
	}

	async function handleSendChatMessage(e?: SubmitEvent) {
		if (e) e.preventDefault();
		if (!selectedReport) return;
		const trimmed = chatInput.trim();
		if (trimmed === "" || chatSending) return;

		chatSending = true;
		try {
			if (!isChromium()) {
				const mockMsg: ReportMessage = {
					id: Date.now(),
					report_id: selectedReport.id,
					sender_identifier: "license:me",
					sender_name: "Staff",
					is_staff: 1,
					message: trimmed,
					created_at: Date.now(),
				};
				chatMessages = [...chatMessages, mockMsg];
				chatInput = "";
				void scrollChatToBottom();
				return;
			}

			const res = await sendReportMessage(selectedReport.id, trimmed);
			if (res?.success) {
				const newMsg: ReportMessage = res.message || {
					id: Date.now(),
					report_id: selectedReport.id,
					sender_identifier: "license:staff",
					sender_name: "Staff",
					is_staff: 1,
					message: trimmed,
					created_at: Date.now(),
				};
				if (!chatMessages.some((m) => m.id === newMsg.id)) {
					chatMessages = [...chatMessages, newMsg];
				}
				chatInput = "";
				void scrollChatToBottom();
				void loadReports(false);
			} else {
				notifications.error(res?.err || "Failed to send message.");
			}
		} catch (err) {
			notifications.error("Failed to send message.");
		} finally {
			chatSending = false;
		}
	}

	function handleIncomingChatMessage(event: Event) {
		const customEvent = event as CustomEvent<ReportMessage>;
		const msg = customEvent.detail;
		if (selectedReport && selectedReport.id === msg.report_id) {
			if (!chatMessages.some((m) => m.id === msg.id)) {
				chatMessages = [...chatMessages, msg];
				void scrollChatToBottom();
			}
		}
	}

	async function handleClaim(report: AdminReport) {
		actionLoading = true;
		try {
			const res = await claimReport(report.id);
			if (res?.success) {
				notifications.success(`Claimed report #${report.id}.`);
				await loadReports(false);
			} else {
				notifications.error(res?.err || "Failed to claim report.");
			}
		} finally {
			actionLoading = false;
		}
	}

	async function handleUnclaim(report: AdminReport) {
		actionLoading = true;
		try {
			const res = await unclaimReport(report.id);
			if (res?.success) {
				notifications.success(`Unclaimed report #${report.id}.`);
				await loadReports(false);
			} else {
				notifications.error(res?.err || "Failed to unclaim report.");
			}
		} finally {
			actionLoading = false;
		}
	}

	function openResolveModal(report: AdminReport) {
		resolvingReport = report;
		resolveNotes = "";
	}

	async function confirmResolve() {
		if (!resolvingReport) return;
		actionLoading = true;
		try {
			const res = await resolveReport(resolvingReport.id, resolveNotes.trim());
			if (res?.success) {
				notifications.success(`Report #${resolvingReport.id} marked as resolved.`);
				resolvingReport = null;
				await loadReports(false);
			} else {
				notifications.error(res?.err || "Failed to resolve report.");
			}
		} finally {
			actionLoading = false;
		}
	}

	function handleModalEscape(e: KeyboardEvent) {
		if (e.key === "Escape" && resolvingReport) {
			e.stopPropagation();
			resolvingReport = null;
		}
	}

	async function handleDelete(report: AdminReport) {
		actionLoading = true;
		try {
			const res = await deleteReport(report.id);
			if (res?.success) {
				notifications.success(`Report #${report.id} deleted.`);
				if (selectedReport?.id === report.id) {
					selectedReport = null;
				}
				await loadReports(true);
			} else {
				notifications.error(res?.err || "Failed to delete report.");
			}
		} finally {
			actionLoading = false;
		}
	}

	function handleGoto(sourceId?: number | null) {
		if (!sourceId) {
			notifications.error("Player is offline.");
			return;
		}
		void gotoPlayer(sourceId);
	}

	function handleBring(sourceId?: number | null) {
		if (!sourceId) {
			notifications.error("Player is offline.");
			return;
		}
		void bringPlayer(sourceId);
	}

	function handleSpectate(sourceId?: number | null) {
		if (!sourceId) {
			notifications.error("Player is offline.");
			return;
		}
		void spectatePlayer(sourceId);
	}

	function handleCopy(text: string | number, label: string) {
		if (navigator.clipboard) {
			navigator.clipboard.writeText(String(text));
			notifications.success(`Copied ${label} (${text}) to clipboard.`);
		}
	}

	// --- Derived Active Staff List for Column 3 ---
	const activeStaffComputed = $derived.by<OnlineStaffMember[]>(() => {
		if (onlineStaff && onlineStaff.length > 0) {
			return onlineStaff;
		}
		if (uiState.players) {
			return uiState.players
				.filter((p) => p.is_staff)
				.map((p) => ({
					id: Number(p.id) || 0,
					name: p.name,
					group: p.group || "Staff",
				}));
		}
		return [];
	});

	// --- Derived Players Snapshot for Column 3 ---
	const snapshotPlayersList = $derived.by<SnapshotPlayer[]>(() => {
		if (!selectedReport) return [];

		let list: SnapshotPlayer[] = [];

		if (Array.isArray(selectedReport.players_snapshot)) {
			list = selectedReport.players_snapshot;
		} else if (typeof selectedReport.players_snapshot === "string" && selectedReport.players_snapshot.trim() !== "") {
			try {
				list = JSON.parse(selectedReport.players_snapshot);
			} catch {
				list = [];
			}
		}

		// Fallback for legacy reports without snapshot: show live online players
		if ((!list || list.length === 0) && uiState.players && uiState.players.length > 0) {
			list = uiState.players.map((p) => ({
				id: p.id ?? "OFF",
				name: p.name,
				is_staff: p.is_staff,
				group: p.group,
			}));
		}

		if (playerSearch.trim() === "") return list;

		const s = playerSearch.trim().toLowerCase();
		return list.filter(
			(p) => String(p.id).toLowerCase().includes(s) || p.name.toLowerCase().includes(s)
		);
	});

	const hasRecordedSnapshot = $derived.by<boolean>(() => {
		if (!selectedReport) return false;
		if (Array.isArray(selectedReport.players_snapshot) && selectedReport.players_snapshot.length > 0) {
			return true;
		}
		if (typeof selectedReport.players_snapshot === "string" && selectedReport.players_snapshot.length > 4) {
			return true;
		}
		return false;
	});

	function handleLiveUpdate() {
		void loadReports(false);
	}

	onMount(() => {
		void loadReports(true);
		window.addEventListener("esx_report:reportUpdated", handleLiveUpdate);
		window.addEventListener("esx-adminmenu:reportUpdated", handleLiveUpdate);
		window.addEventListener("esx_report:reportChatMessage", handleIncomingChatMessage);
		window.addEventListener("esx-adminmenu:reportChatMessage", handleIncomingChatMessage);
	});

	onDestroy(() => {
		clearTimeout(searchTimer);
		window.removeEventListener("esx_report:reportUpdated", handleLiveUpdate);
		window.removeEventListener("esx-adminmenu:reportUpdated", handleLiveUpdate);
		window.removeEventListener("esx_report:reportChatMessage", handleIncomingChatMessage);
		window.removeEventListener("esx-adminmenu:reportChatMessage", handleIncomingChatMessage);
	});
</script>

<svelte:window onkeydown={handleModalEscape} />

<div class="reports-workspace">
	<!-- Top Bar -->
	<div class="top-bar">
		<div class="title-group">
			<span class="main-title">Reports Management</span>
			<span class="sub-title">Review player tickets, manage cases, and communicate with players.</span>
		</div>

		<div class="controls-group">
			<div class="filter-tabs">
				<button class="filter-btn" class:active={statusFilter === "all"} onclick={() => onFilterChange("all")}>
					All
				</button>
				<button class="filter-btn" class:active={statusFilter === "open"} onclick={() => onFilterChange("open")}>
					Open
					{#if openCount > 0}
						<span class="badge open-badge">{openCount}</span>
					{/if}
				</button>
				<button class="filter-btn" class:active={statusFilter === "claimed"} onclick={() => onFilterChange("claimed")}>
					Claimed
				</button>
				<button class="filter-btn" class:active={statusFilter === "resolved"} onclick={() => onFilterChange("resolved")}>
					Resolved
				</button>
			</div>

			<div class="search-box">
				<svg class="search-icon" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
					<path
						d="M10.8746 10.852L14 14M12.5556 6.77778C12.5556 9.96877 9.96877 12.5556 6.77778 12.5556C3.5868 12.5556 1 9.96877 1 6.77778C1 3.5868 3.5868 1 6.77778 1C9.96877 1 12.5556 3.5868 12.5556 6.77778Z"
						stroke="currentColor"
						stroke-width="1.8"
						stroke-linecap="round"
						stroke-linejoin="round"
					/>
				</svg>
				<input
					type="text"
					class="search-input"
					placeholder="Search reports or ID..."
					bind:value={search}
					oninput={onSearchInput}
				/>
			</div>

			<button type="button" class="refresh-btn" onclick={() => loadReports(false)} title="Refresh list" disabled={loading}>
				<svg class:spinning={loading} viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
					<path d="M14 8A6 6 0 1 1 8 2c2 0 3.8 1 4.8 2.5L14 3v3h-3l1.5-1.5A4.5 4.5 0 1 0 12.5 8H14Z" fill="currentColor" />
				</svg>
			</button>
		</div>
	</div>

	<!-- 3-Column Layout -->
	<div class="reports-3col-container">
		<!-- ================= COLUMN 1: REPORT LIST ================= -->
		<div class="col-panel col-report-list">
			<div class="panel-header">
				<div class="header-left">
					<span class="panel-title">Report List</span>
					<span class="count-tag">{reports.length}</span>
				</div>
			</div>

			<div class="panel-body list-scroll">
				{#if loading && reports.length === 0}
					<div class="panel-empty">
						<div class="spinner"></div>
						<span>Loading reports...</span>
					</div>
				{:else if reports.length === 0}
					<div class="panel-empty">
						<svg class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
							<path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
						</svg>
						<span class="empty-text">No reports found</span>
					</div>
				{:else}
					<div class="tickets-stack">
						{#each reports as report (report.id)}
							{@const isSelected = selectedReport?.id === report.id}
							{@const createdMs = getTimestampMs(report.created_at)}
							<!-- svelte-ignore a11y_click_events_have_key_events -->
							<div
								class="ticket-item"
								class:selected={isSelected}
								class:card-open={report.status === "open"}
								class:card-claimed={report.status === "claimed"}
								class:card-resolved={report.status === "resolved"}
								onclick={() => selectReport(report)}
								role="button"
								tabindex="0"
							>
								<!-- Top row: ID, Title, Status -->
								<div class="ticket-header">
									<div class="ticket-id-title">
										<span class="ticket-id">#{report.id}</span>
										<span class="ticket-title" title={report.title || report.category}>
											{report.title || report.category}
										</span>
									</div>
									<span class="status-badge status-{report.status}">
										{report.status.toUpperCase()}
									</span>
								</div>

								<!-- Sub row: Category & Time -->
								<div class="ticket-sub">
									<span class="category-chip">{report.category}</span>
									<span class="time-chip">{relativeTime(createdMs)}</span>
								</div>

								<!-- Reporter info & preview -->
								<div class="ticket-meta-row">
									<span class="reporter-label">By: <strong class="reporter-name">{report.reporter_name}</strong></span>
									{#if report.claimed_name}
										<span class="claimed-badge" title="Claimed by {report.claimed_name}">
											Staff: {report.claimed_name}
										</span>
									{/if}
								</div>

								<!-- Short preview of reason -->
								<p class="ticket-preview">{report.reason}</p>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		</div>

		<!-- ================= COLUMN 2: INSIDE THE SELECTED REPORT LIST ================= -->
		<div class="col-panel col-selected-report">
			{#if !selectedReport}
				<div class="empty-workspace">
					<svg class="workspace-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
						<path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
					</svg>
					<span class="workspace-title">No Report Selected</span>
					<span class="workspace-desc">Select a report from the list on the left to view full ticket details, chat with the player, and take admin actions.</span>
				</div>
			{:else}
				{@const createdMs = getTimestampMs(selectedReport.created_at)}
				<!-- Top Case Header with Integrated Reporter & Accused Details -->
				<div class="selected-header">
					<div class="header-top-row">
						<div class="case-meta-badges">
							<span class="case-id">#{selectedReport.id}</span>
							<span class="status-badge status-{selectedReport.status}">{selectedReport.status.toUpperCase()}</span>
							<span class="category-chip">{selectedReport.category}</span>
							<span class="case-time">{relativeTime(createdMs)}</span>
						</div>

						<!-- Header Actions: Claim, Unclaim, Resolve, Delete -->
						<div class="case-actions">
							{#if selectedReport.status === "open"}
								<button type="button" class="btn btn-primary" onclick={() => handleClaim(selectedReport!)} disabled={actionLoading}>
									Claim Ticket
								</button>
							{:else if selectedReport.status === "claimed"}
								<button type="button" class="btn btn-secondary" onclick={() => handleUnclaim(selectedReport!)} disabled={actionLoading}>
									Unclaim
								</button>
								<button type="button" class="btn btn-resolve" onclick={() => openResolveModal(selectedReport!)} disabled={actionLoading}>
									Mark Resolved
								</button>
							{/if}

							<button type="button" class="btn-icon delete-btn" onclick={() => handleDelete(selectedReport!)} title="Delete ticket" disabled={actionLoading}>
								<svg viewBox="0 0 16 16" fill="currentColor">
									<path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/>
									<path fill-rule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/>
								</svg>
							</button>
						</div>
					</div>

					<!-- Title -->
					<h3 class="case-title">{selectedReport.title || selectedReport.category}</h3>

					<!-- Integrated Reporter & Accused Strip -->
					<div class="header-parties-strip">
						<div class="header-party-pill reporter-pill">
							<span class="pill-role">Reporter:</span>
							<span class="pill-name">{selectedReport.reporter_name}</span>
							{#if selectedReport.reporter_online}
								<span class="pill-id online" title="Online (Server ID: {selectedReport.reporter_current_source})">
									ID: {selectedReport.reporter_current_source}
								</span>
								<div class="pill-actions">
									<button type="button" class="mini-action-btn" onclick={() => handleGoto(selectedReport?.reporter_current_source)} title="Teleport to Reporter">Goto</button>
									<button type="button" class="mini-action-btn" onclick={() => handleBring(selectedReport?.reporter_current_source)} title="Bring Reporter to you">Bring</button>
									<button type="button" class="mini-action-btn" onclick={() => handleSpectate(selectedReport?.reporter_current_source)} title="Spectate Reporter">Spectate</button>
								</div>
							{:else}
								<span class="pill-id offline" title="Currently Offline">Offline</span>
							{/if}
						</div>

						{#if selectedReport.target_name}
							<div class="header-party-pill accused-pill">
								<span class="pill-role">Accused:</span>
								<span class="pill-name">{selectedReport.target_name}</span>
								{#if selectedReport.target_online}
									<span class="pill-id online" title="Online (Server ID: {selectedReport.target_current_source})">
										ID: {selectedReport.target_current_source}
									</span>
									<div class="pill-actions">
										<button type="button" class="mini-action-btn" onclick={() => handleGoto(selectedReport?.target_current_source)} title="Teleport to Accused">Goto</button>
										<button type="button" class="mini-action-btn" onclick={() => handleBring(selectedReport?.target_current_source)} title="Bring Accused to you">Bring</button>
									</div>
								{:else}
									<span class="pill-id offline" title="Currently Offline">Offline</span>
								{/if}
							</div>
						{/if}

						{#if selectedReport.status === "resolved"}
							<div class="header-party-pill resolved-pill">
								<span class="pill-role">Resolved by:</span>
								<span class="pill-name">{selectedReport.claimed_name || "Staff"}</span>
							</div>
						{:else if selectedReport.status === "claimed" && selectedReport.claimed_name}
							<div class="header-party-pill staff-pill">
								<span class="pill-role">Claimed by:</span>
								<span class="pill-name">{selectedReport.claimed_name}</span>
							</div>
						{/if}
					</div>
				</div>

				<!-- Selected Body Workspace -->
				<div class="selected-body">
					<!-- Compact Issue Description Box -->
					<div class="reason-section">
						<span class="section-heading">Initial Report Description:</span>
						<div class="reason-box">
							<p class="reason-text">{selectedReport.reason}</p>
						</div>
					</div>

					<!-- Custom Resolution Notes (Shown only if staff provided custom notes) -->
					{#if selectedReport.status === "resolved" && selectedReport.resolution_notes && selectedReport.resolution_notes !== "Resolved by staff." && selectedReport.resolution_notes !== "Closed by player."}
						<div class="resolution-banner">
							<span class="res-title">Resolution Note:</span>
							<p class="res-text">{selectedReport.resolution_notes}</p>
						</div>
					{/if}

					<!-- Integrated Live Ticket Chat -->
					<div class="chat-section">
						<div class="chat-section-header">
							<div class="chat-title-row">
								<span class="chat-title">Live Ticket Conversation</span>
								<span class="chat-live-pulse" title="Real-time message feed"></span>
							</div>
							<span class="chat-party-note">Direct communication with {selectedReport.reporter_name}</span>
						</div>

						<!-- Messages Stream -->
						<div class="chat-stream" bind:this={chatContainer}>
							{#if chatLoading}
								<div class="chat-empty">
									<div class="spinner"></div>
									<span>Loading conversation...</span>
								</div>
							{:else if chatMessages.length === 0}
								<div class="chat-empty">
									<span>No messages yet. Send a response below to start assisting the player.</span>
								</div>
							{:else}
								{#each chatMessages as msg (msg.id)}
									{@const isStaffMsg = Boolean(msg.is_staff)}
									<div class="chat-bubble-row" class:is-staff={isStaffMsg} class:is-player={!isStaffMsg}>
										<div class="chat-bubble">
											<div class="bubble-header">
												<span class="bubble-sender">{isStaffMsg ? `Staff (${msg.sender_name})` : msg.sender_name}</span>
												<span class="bubble-time">{relativeTime(getTimestampMs(msg.created_at))}</span>
											</div>
											<p class="bubble-message">{msg.message}</p>
										</div>
									</div>
								{/each}
							{/if}
						</div>

						<!-- Chat Input Bar -->
						{#if selectedReport.status !== "resolved"}
							<form class="chat-input-bar" onsubmit={handleSendChatMessage}>
								<input
									type="text"
									class="chat-input"
									placeholder="Type a message to {selectedReport.reporter_name}..."
									bind:value={chatInput}
									maxlength="500"
									disabled={chatSending}
								/>
								<button type="submit" class="chat-send-btn" disabled={chatSending || chatInput.trim() === ""}>
									{chatSending ? "Sending..." : "Send"}
								</button>
							</form>
						{:else}
							<div class="chat-closed-notice">
								<span>This ticket has been marked as resolved.</span>
							</div>
						{/if}
					</div>
				</div>
			{/if}
		</div>

		<!-- ================= COLUMN 3: ACTIVE STAFF & PLAYER SNAPSHOT ================= -->
		<div class="col-panel col-staff-and-players">
			<!-- Top Subsection: ACTIVE STAFF -->
			<div class="staff-section">
				<div class="panel-header">
					<div class="header-left">
						<span class="panel-title">Active Staff</span>
						<span class="live-dot" title="Staff currently active"></span>
					</div>
					<span class="count-tag staff-tag">{activeStaffComputed.length}</span>
				</div>

				<div class="staff-list list-scroll">
					{#if activeStaffComputed.length === 0}
						<div class="staff-empty">
							<span>No staff members detected</span>
						</div>
					{:else}
						{#each activeStaffComputed as staff (staff.id)}
							{@const isHandling = Boolean(selectedReport?.claimed_name && selectedReport.claimed_name.toLowerCase() === staff.name.toLowerCase())}
							<div class="staff-card" class:is-assigned={isHandling}>
								<div class="staff-meta">
									<span class="id-badge">ID: {staff.id}</span>
									<span class="staff-name" title={staff.name}>{staff.name}</span>
								</div>
								<div class="staff-right">
									<span class="role-badge">{staff.group || "Staff"}</span>
									{#if isHandling}
										<span class="assigned-pill" title="Assigned to current ticket">Assigned</span>
									{/if}
								</div>
							</div>
						{/each}
					{/if}
				</div>
			</div>

			<!-- Bottom Subsection: PLAYERS LIST WHEN REPORT WAS MADE -->
			<div class="players-snapshot-section">
				<div class="panel-header">
					<div class="header-left">
						<span class="panel-title">Players at Report Time</span>
					</div>
					<span class="count-tag">{snapshotPlayersList.length}</span>
				</div>

				<!-- Snapshot Status & Search -->
				<div class="snapshot-controls">
					<div class="snapshot-info-banner" class:legacy={!hasRecordedSnapshot}>
						{#if hasRecordedSnapshot}
							<svg viewBox="0 0 16 16" fill="currentColor" class="info-icon">
								<path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z"/>
								<path d="m8.93 6.588-2.29.287-.082.38.45.083c.294.07.352.176.288.469l-.738 3.468c-.194.897.105 1.319.808 1.319.545 0 1.178-.252 1.465-.598l.088-.416c-.2.176-.492.246-.686.246-.275 0-.375-.193-.304-.533L8.93 6.588zM9 4.5a1 1 0 1 1-2 0 1 1 0 0 1 2 0z"/>
							</svg>
							<span>Snapshot of nearby players (within 50m) at report time</span>
						{:else}
							<svg viewBox="0 0 16 16" fill="currentColor" class="info-icon">
								<path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z"/>
								<path d="M7.002 11a1 1 0 1 1 2 0 1 1 0 0 1-2 0zM7.1 4.995a.905.905 0 1 1 1.8 0l-.35 3.507a.552.552 0 0 1-1.1 0L7.1 4.995z"/>
							</svg>
							<span>Legacy report: Showing currently active server players</span>
						{/if}
					</div>

					<div class="player-filter-box">
						<input
							type="text"
							class="player-filter-input"
							placeholder="Filter by ID or Name..."
							bind:value={playerSearch}
						/>
					</div>
				</div>

				<!-- Scrollable Snapshot List -->
				<div class="snapshot-list list-scroll">
					{#if snapshotPlayersList.length === 0}
						<div class="staff-empty">
							<span>No matching players</span>
						</div>
					{:else}
						{#each snapshotPlayersList as ply (ply.id + '-' + ply.name)}
							{@const isReporter = selectedReport?.reporter_name && selectedReport.reporter_name.toLowerCase() === ply.name.toLowerCase()}
							{@const isAccused = selectedReport?.target_name && selectedReport.target_name.toLowerCase() === ply.name.toLowerCase()}
							<div class="player-snapshot-card" class:reporter-hl={isReporter} class:accused-hl={isAccused}>
								<div class="ply-left">
									<button
										type="button"
										class="id-badge-interactive"
										title="Click to copy ID"
										onclick={() => handleCopy(ply.id, "Player ID")}
									>
										ID: {ply.id}
									</button>
									<span class="ply-name" title={ply.name}>{ply.name}</span>
								</div>

								<div class="ply-tags">
									{#if ply.distance !== undefined && ply.distance !== null}
										<span class="badge-role badge-distance" title="Distance from reporter at report time">{ply.distance}m</span>
									{/if}
									{#if isReporter}
										<span class="badge-role badge-reporter">Reporter</span>
									{/if}
									{#if isAccused}
										<span class="badge-role badge-accused">Accused</span>
									{/if}
									{#if ply.is_staff}
										<span class="badge-role badge-staff">Staff</span>
									{/if}
								</div>
							</div>
						{/each}
					{/if}
				</div>
			</div>
		</div>
	</div>

	<!-- Resolve Modal -->
	{#if resolvingReport}
		<div class="modal-backdrop" onclick={() => (resolvingReport = null)} role="presentation">
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<div class="modal-content" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
				<h3 class="modal-title">Resolve Report #{resolvingReport.id}</h3>
				<p class="modal-subtitle">Add a resolution note for the player and staff history logs.</p>

				<textarea
					class="modal-textarea"
					placeholder="e.g. Player assisted in game / rule violation handled / refund issued..."
					bind:value={resolveNotes}
					rows="3"
				></textarea>

				<div class="modal-buttons">
					<button type="button" class="btn btn-secondary" onclick={() => (resolvingReport = null)}>Cancel</button>
					<button type="button" class="btn btn-primary" onclick={confirmResolve} disabled={actionLoading}>
						Confirm & Resolve
					</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.reports-workspace {
		display: flex;
		flex-direction: column;
		height: 100%;
		width: 100%;
		gap: 1.2vh;
		box-sizing: border-box;
		user-select: none;
		font-family: "Poppins", sans-serif;
		color: #f2f2f2;
		overflow: hidden;
	}

	/* Top Bar */
	.top-bar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 0.8vh;
		border-bottom: 0.1vh solid #2e2e2c;
		gap: 1.5vh;
		flex-shrink: 0;
	}

	.title-group {
		display: flex;
		flex-direction: column;
	}

	.main-title {
		font-size: 1.5vh;
		font-weight: 600;
		color: #f2f2f2;
	}

	.sub-title {
		font-size: 1.05vh;
		color: #8c8c8c;
	}

	.controls-group {
		display: flex;
		align-items: center;
		gap: 1vh;
	}

	.filter-tabs {
		display: flex;
		background: rgba(22, 22, 22, 0.85);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.5vh;
		padding: 0.2vh;
		gap: 0.2vh;
	}

	.filter-btn {
		background: transparent;
		border: none;
		color: #8c8c8c;
		font-size: 1.1vh;
		font-weight: 500;
		padding: 0.4vh 1vh;
		border-radius: 0.3vh;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 0.6vh;
		transition: all 0.15s;
		font-family: inherit;
	}

	.filter-btn:hover {
		color: #f2f2f2;
	}

	.filter-btn.active {
		background: #fb9b04;
		color: #161616;
		font-weight: 600;
	}

	.badge {
		font-size: 0.95vh;
		padding: 0.1vh 0.5vh;
		border-radius: 1vh;
		font-weight: 700;
	}

	.open-badge {
		background: rgba(22, 22, 22, 0.4);
		color: #161616;
	}

	.filter-btn:not(.active) .open-badge {
		background: rgba(251, 155, 4, 0.2);
		color: #fb9b04;
	}

	.search-box {
		display: flex;
		align-items: center;
		background: rgba(22, 22, 22, 0.85);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.5vh;
		padding: 0.3vh 0.8vh;
		gap: 0.6vh;
		width: 20vh;
	}

	.search-icon {
		width: 1.2vh;
		height: 1.2vh;
		color: #8c8c8c;
		flex-shrink: 0;
	}

	.search-input {
		background: transparent;
		border: none;
		outline: none;
		color: #f2f2f2;
		font-size: 1.1vh;
		width: 100%;
		font-family: inherit;
	}

	.search-input::placeholder {
		color: #666;
	}

	.refresh-btn {
		background: rgba(22, 22, 22, 0.85);
		border: 0.1vh solid #2e2e2c;
		color: #8c8c8c;
		width: 2.8vh;
		height: 2.8vh;
		border-radius: 0.5vh;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.15s;
		padding: 0;
	}

	.refresh-btn:hover:not(:disabled) {
		color: #fb9b04;
		border-color: rgba(251, 155, 4, 0.4);
	}

	.refresh-btn svg {
		width: 1.3vh;
		height: 1.3vh;
	}

	.spinning {
		animation: spin 0.8s linear infinite;
	}

	/* 3-Column Layout */
	.reports-3col-container {
		display: grid;
		grid-template-columns: minmax(24vh, 28vh) 1fr minmax(30vh, 34vh);
		gap: 1.2vh;
		flex: 1;
		min-height: 0;
		height: 100%;
	}

	.col-panel {
		background: rgba(22, 22, 22, 0.7);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.8vh;
		display: flex;
		flex-direction: column;
		min-height: 0;
		overflow: hidden;
		box-sizing: border-box;
	}

	.panel-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1vh 1.4vh;
		border-bottom: 0.1vh solid #2e2e2c;
		background: rgba(26, 26, 26, 0.5);
		flex-shrink: 0;
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 0.8vh;
	}

	.panel-title {
		font-size: 1.25vh;
		font-weight: 600;
		color: #f2f2f2;
	}

	.count-tag {
		background: rgba(255, 255, 255, 0.08);
		border: 0.1vh solid #3a3a3a;
		color: #d1d5db;
		font-size: 0.95vh;
		font-weight: 600;
		padding: 0.1vh 0.5vh;
		border-radius: 0.3vh;
	}

	.staff-tag {
		background: rgba(16, 185, 129, 0.15);
		color: #34d399;
		border-color: rgba(16, 185, 129, 0.3);
	}

	.live-dot {
		width: 0.8vh;
		height: 0.8vh;
		border-radius: 50%;
		background: #10b981;
		box-shadow: 0 0 0.6vh #10b981;
		animation: pulse 2s infinite;
	}

	.list-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		padding: 0.8vh;
	}

	.panel-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		min-height: 20vh;
		color: #797979;
		gap: 0.8vh;
	}

	.empty-icon {
		width: 3.5vh;
		height: 3.5vh;
		opacity: 0.3;
	}

	.empty-text {
		font-size: 1.15vh;
	}

	/* Tickets Stack */
	.tickets-stack {
		display: flex;
		flex-direction: column;
		gap: 0.8vh;
	}

	.ticket-item {
		background: rgba(30, 30, 30, 0.6);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.6vh;
		padding: 0.7vh 0.9vh;
		cursor: pointer;
		display: flex;
		flex-direction: column;
		gap: 0.4vh;
		transition: all 0.15s;
		outline: none;
	}

	.ticket-item:hover {
		background: rgba(38, 38, 38, 0.8);
		border-color: rgba(251, 155, 4, 0.3);
	}

	.ticket-item.card-open {
		border-left: 0.35vh solid #fb9b04;
	}

	.ticket-item.card-claimed {
		border-left: 0.35vh solid #3b82f6;
	}

	.ticket-item.card-resolved {
		border-left: 0.35vh solid #10b981;
		opacity: 0.7;
	}

	.ticket-item.selected {
		background: rgba(251, 155, 4, 0.08);
		border-color: #fb9b04;
		box-shadow: 0 0 1vh rgba(251, 155, 4, 0.2);
	}

	.ticket-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.8vh;
	}

	.ticket-id-title {
		display: flex;
		align-items: center;
		gap: 0.6vh;
		min-width: 0;
		flex: 1;
	}

	.ticket-id {
		font-size: 1.15vh;
		font-weight: 700;
		color: #fb9b04;
		flex-shrink: 0;
	}

	.ticket-title {
		font-size: 1.2vh;
		font-weight: 600;
		color: #f2f2f2;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.status-badge {
		font-size: 0.9vh;
		font-weight: 700;
		padding: 0.2vh 0.6vh;
		border-radius: 0.3vh;
		letter-spacing: 0.04em;
		flex-shrink: 0;
	}

	.status-open {
		background: rgba(251, 155, 4, 0.15);
		color: #fb9b04;
		border: 0.1vh solid rgba(251, 155, 4, 0.35);
	}

	.status-claimed {
		background: rgba(59, 130, 246, 0.15);
		color: #60a5fa;
		border: 0.1vh solid rgba(59, 130, 246, 0.35);
	}

	.status-resolved {
		background: rgba(16, 185, 129, 0.15);
		color: #34d399;
		border: 0.1vh solid rgba(16, 185, 129, 0.35);
	}

	.ticket-sub {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.6vh;
	}

	.category-chip {
		background: rgba(255, 255, 255, 0.06);
		border: 0.1vh solid #3a3a3a;
		color: #b0b0b0;
		font-size: 0.95vh;
		padding: 0.15vh 0.5vh;
		border-radius: 0.3vh;
		white-space: nowrap;
	}

	.time-chip {
		font-size: 0.95vh;
		color: #797979;
	}

	.ticket-meta-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		font-size: 1.05vh;
		color: #a3a3a3;
	}

	.reporter-name {
		color: #e5e5e5;
	}

	.claimed-badge {
		font-size: 0.9vh;
		color: #60a5fa;
		background: rgba(59, 130, 246, 0.1);
		padding: 0.1vh 0.4vh;
		border-radius: 0.2vh;
	}

	.ticket-preview {
		margin: 0;
		font-size: 1.05vh;
		color: #9c9c9c;
		line-height: 1.35;
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	/* ================= COLUMN 2: SELECTED REPORT WORKSPACE ================= */
	.col-selected-report {
		background: rgba(20, 20, 20, 0.8);
	}

	.empty-workspace {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		padding: 3vh;
		text-align: center;
		color: #797979;
		gap: 1.2vh;
	}

	.workspace-icon {
		width: 5vh;
		height: 5vh;
		opacity: 0.3;
	}

	.workspace-title {
		font-size: 1.6vh;
		font-weight: 600;
		color: #b3b3b3;
	}

	.workspace-desc {
		font-size: 1.15vh;
		max-width: 38vh;
		line-height: 1.5;
	}

	.selected-header {
		display: flex;
		flex-direction: column;
		padding: 1vh 1.4vh;
		border-bottom: 0.1vh solid #2e2e2c;
		background: rgba(24, 24, 24, 0.75);
		gap: 0.5vh;
		flex-shrink: 0;
	}

	.header-top-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		width: 100%;
		gap: 1vh;
	}

	.case-meta-badges {
		display: flex;
		align-items: center;
		gap: 0.8vh;
		flex-wrap: wrap;
	}

	.case-id {
		font-size: 1.3vh;
		font-weight: 700;
		color: #fb9b04;
	}

	.case-time {
		font-size: 1.05vh;
		color: #8c8c8c;
	}

	.case-title {
		margin: 0;
		font-size: 1.35vh;
		font-weight: 600;
		color: #f2f2f2;
		line-height: 1.25;
		word-break: break-word;
	}

	.case-actions {
		display: flex;
		align-items: center;
		gap: 0.8vh;
		flex-shrink: 0;
	}

	/* Integrated Header Parties Strip (Reporter & Accused) */
	.header-parties-strip {
		display: flex;
		align-items: center;
		gap: 0.6vh;
		flex-wrap: wrap;
		margin-top: 0.1vh;
	}

	.header-party-pill {
		display: inline-flex;
		align-items: center;
		gap: 0.5vh;
		background: rgba(30, 30, 30, 0.85);
		border: 0.1vh solid #30302e;
		border-radius: 0.4vh;
		padding: 0.3vh 0.7vh;
		font-size: 1.05vh;
	}

	.header-party-pill.reporter-pill {
		border-left: 0.25vh solid #fb9b04;
	}

	.header-party-pill.accused-pill {
		border-left: 0.25vh solid #ef4444;
	}

	.header-party-pill.resolved-pill {
		border-left: 0.25vh solid #10b981;
		background: rgba(16, 185, 129, 0.1);
	}

	.header-party-pill.resolved-pill .pill-role {
		color: #34d399;
	}

	.header-party-pill.staff-pill {
		border-left: 0.25vh solid #3b82f6;
		background: rgba(59, 130, 246, 0.1);
	}

	.header-party-pill.staff-pill .pill-role {
		color: #60a5fa;
	}

	.pill-role {
		color: #8c8c8c;
		font-weight: 500;
		font-size: 0.95vh;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.pill-name {
		color: #f2f2f2;
		font-weight: 600;
		font-size: 1.15vh;
	}

	.pill-id {
		font-size: 0.95vh;
		font-weight: 700;
		padding: 0.1vh 0.45vh;
		border-radius: 0.3vh;
		font-variant-numeric: tabular-nums;
	}

	.pill-id.online {
		background: rgba(16, 185, 129, 0.15);
		color: #34d399;
		border: 0.1vh solid rgba(16, 185, 129, 0.3);
	}

	.pill-id.offline {
		background: rgba(255, 255, 255, 0.06);
		color: #8c8c8c;
		border: 0.1vh solid rgba(255, 255, 255, 0.1);
	}

	.pill-actions {
		display: inline-flex;
		align-items: center;
		gap: 0.4vh;
		margin-left: 0.3vh;
	}

	.mini-action-btn {
		background: rgba(251, 155, 4, 0.12);
		border: 0.1vh solid rgba(251, 155, 4, 0.35);
		color: #fb9b04;
		border-radius: 0.3vh;
		padding: 0.2vh 0.55vh;
		font-size: 0.95vh;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s ease;
		font-family: inherit;
		line-height: 1;
	}

	.mini-action-btn:hover {
		background: #fb9b04;
		color: #121212;
	}

	.selected-body {
		flex: 1;
		min-height: 0;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		gap: 0.8vh;
		padding: 1vh 1.3vh;
	}

	/* Reason & Resolution */
	.reason-section {
		display: flex;
		flex-direction: column;
		gap: 0.25vh;
		flex-shrink: 0;
	}

	.section-heading {
		font-size: 0.95vh;
		font-weight: 600;
		color: #fb9b04;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.reason-box {
		background: rgba(26, 26, 26, 0.75);
		border: 0.1vh solid #2e2e2c;
		border-left: 0.25vh solid #fb9b04;
		border-radius: 0.4vh;
		padding: 0.5vh 0.9vh;
		max-height: 5.5vh;
		overflow-y: auto;
		flex-shrink: 0;
	}

	.reason-text {
		margin: 0;
		font-size: 1.1vh;
		color: #e5e5e5;
		line-height: 1.4;
		white-space: pre-wrap;
		word-break: break-word;
	}

	.resolution-banner {
		background: rgba(16, 185, 129, 0.08);
		border: 0.1vh solid rgba(16, 185, 129, 0.3);
		border-left: 0.25vh solid #10b981;
		border-radius: 0.4vh;
		padding: 0.5vh 0.9vh;
		display: flex;
		flex-direction: column;
		gap: 0.2vh;
		flex-shrink: 0;
	}

	.res-title {
		font-size: 1vh;
		font-weight: 600;
		color: #34d399;
	}

	.res-text {
		margin: 0;
		font-size: 1.05vh;
		color: #d1fae5;
	}

	/* Live Ticket Conversation Section */
	.chat-section {
		background: rgba(18, 18, 18, 0.95);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.5vh;
		display: flex;
		flex-direction: column;
		min-height: 0;
		flex: 1;
		overflow: hidden;
	}

	.chat-section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.6vh 1vh;
		border-bottom: 0.1vh solid #2e2e2c;
		background: rgba(24, 24, 24, 0.85);
		flex-shrink: 0;
	}

	.chat-title-row {
		display: flex;
		align-items: center;
		gap: 0.6vh;
	}

	.chat-title {
		font-size: 1.15vh;
		font-weight: 600;
		color: #f2f2f2;
	}

	.chat-live-pulse {
		width: 0.6vh;
		height: 0.6vh;
		border-radius: 50%;
		background: #10b981;
		box-shadow: 0 0 0.5vh #10b981;
	}

	.chat-party-note {
		font-size: 0.95vh;
		color: #8c8c8c;
	}

	.chat-stream {
		flex: 1;
		min-height: 0;
		max-height: none;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 0.7vh;
		padding: 0.8vh;
	}

	.chat-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: #737373;
		font-size: 1.15vh;
		text-align: center;
		gap: 0.8vh;
	}

	.chat-bubble-row {
		display: flex;
		width: 100%;
	}

	.chat-bubble-row.is-staff {
		justify-content: flex-end;
	}

	.chat-bubble-row.is-player {
		justify-content: flex-start;
	}

	.chat-bubble {
		max-width: 80%;
		padding: 0.7vh 1vh;
		border-radius: 0.6vh;
		display: flex;
		flex-direction: column;
		gap: 0.2vh;
		box-sizing: border-box;
	}

	.chat-bubble-row.is-staff .chat-bubble {
		background: rgba(59, 130, 246, 0.15);
		border: 0.1vh solid rgba(59, 130, 246, 0.35);
		border-top-right-radius: 0.1vh;
	}

	.chat-bubble-row.is-player .chat-bubble {
		background: rgba(251, 155, 4, 0.12);
		border: 0.1vh solid rgba(251, 155, 4, 0.3);
		border-top-left-radius: 0.1vh;
	}

	.bubble-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 1vh;
		font-size: 0.9vh;
	}

	.chat-bubble-row.is-staff .bubble-sender {
		font-weight: 700;
		color: #60a5fa;
	}

	.chat-bubble-row.is-player .bubble-sender {
		font-weight: 700;
		color: #fb9b04;
	}

	.bubble-time {
		color: #6b7280;
	}

	.bubble-message {
		margin: 0;
		font-size: 1.15vh;
		color: #f3f4f6;
		line-height: 1.4;
		white-space: pre-wrap;
		word-break: break-word;
	}

	.chat-input-bar {
		display: flex;
		gap: 0.8vh;
		align-items: center;
		background: rgba(22, 22, 22, 0.95);
		border-top: 0.1vh solid #2e2e2c;
		padding: 0.6vh 0.8vh;
	}

	.chat-input {
		flex: 1;
		background: rgba(30, 30, 30, 0.8);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.4vh;
		color: #f2f2f2;
		font-size: 1.15vh;
		font-family: inherit;
		padding: 0.6vh 0.8vh;
		outline: none;
		transition: border-color 0.15s;
	}

	.chat-input:focus {
		border-color: #fb9b04;
	}

	.chat-input::placeholder {
		color: #666;
	}

	.chat-send-btn {
		background: #fb9b04;
		color: #161616;
		border: none;
		border-radius: 0.4vh;
		padding: 0.6vh 1.4vh;
		font-size: 1.1vh;
		font-weight: 700;
		cursor: pointer;
		font-family: inherit;
		transition: background-color 0.15s;
	}

	.chat-send-btn:hover:not(:disabled) {
		background: #ffa826;
	}

	.chat-send-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.chat-closed-notice {
		background: rgba(16, 185, 129, 0.1);
		border-top: 0.1vh solid rgba(16, 185, 129, 0.25);
		padding: 0.8vh;
		text-align: center;
		font-size: 1.1vh;
		color: #34d399;
	}

	/* ================= COLUMN 3: ACTIVE STAFF & SNAPSHOT PLAYERS ================= */
	.col-staff-and-players {
		background: rgba(22, 22, 22, 0.7);
	}

	.staff-section {
		max-height: 20vh;
		display: flex;
		flex-direction: column;
		border-bottom: 0.1vh solid #2e2e2c;
		min-height: 0;
		flex-shrink: 0;
	}

	.staff-list {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		padding: 0.8vh;
		display: flex;
		flex-direction: column;
		gap: 0.6vh;
	}

	.staff-empty {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: #797979;
		font-size: 1.1vh;
	}

	.staff-card {
		background: rgba(30, 30, 30, 0.6);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.5vh;
		padding: 0.6vh 0.9vh;
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.6vh;
	}

	.staff-card.is-assigned {
		border-color: #3b82f6;
		background: rgba(59, 130, 246, 0.08);
	}

	.staff-meta {
		display: flex;
		align-items: center;
		gap: 0.6vh;
		min-width: 0;
	}

	.id-badge {
		background: rgba(251, 155, 4, 0.15);
		color: #fb9b04;
		border: 0.1vh solid rgba(251, 155, 4, 0.3);
		font-size: 0.9vh;
		font-weight: 700;
		padding: 0.15vh 0.4vh;
		border-radius: 0.3vh;
		flex-shrink: 0;
	}

	.staff-name {
		font-size: 1.15vh;
		font-weight: 600;
		color: #f2f2f2;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.staff-right {
		display: flex;
		align-items: center;
		gap: 0.4vh;
		flex-shrink: 0;
	}

	.role-badge {
		background: rgba(255, 255, 255, 0.06);
		border: 0.1vh solid #3a3a3a;
		color: #9ca3af;
		font-size: 0.85vh;
		padding: 0.1vh 0.4vh;
		border-radius: 0.2vh;
		text-transform: capitalize;
	}

	.assigned-pill {
		background: #3b82f6;
		color: #ffffff;
		font-size: 0.85vh;
		font-weight: 700;
		padding: 0.1vh 0.5vh;
		border-radius: 0.2vh;
	}

	/* Players Snapshot Section */
	.players-snapshot-section {
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
	}

	.snapshot-controls {
		display: flex;
		flex-direction: column;
		gap: 0.6vh;
		padding: 0.8vh;
		border-bottom: 0.1vh solid #2e2e2c;
		background: rgba(26, 26, 26, 0.3);
	}

	.snapshot-info-banner {
		display: flex;
		align-items: center;
		gap: 0.5vh;
		font-size: 0.95vh;
		color: #93c5fd;
		background: rgba(59, 130, 246, 0.1);
		border: 0.1vh solid rgba(59, 130, 246, 0.25);
		border-radius: 0.4vh;
		padding: 0.4vh 0.6vh;
	}

	.snapshot-info-banner.legacy {
		color: #fde047;
		background: rgba(234, 179, 8, 0.1);
		border-color: rgba(234, 179, 8, 0.25);
	}

	.info-icon {
		width: 1.2vh;
		height: 1.2vh;
		flex-shrink: 0;
	}

	.player-filter-box {
		width: 100%;
	}

	.player-filter-input {
		width: 100%;
		background: rgba(30, 30, 30, 0.8);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.4vh;
		color: #f2f2f2;
		font-size: 1.05vh;
		font-family: inherit;
		padding: 0.4vh 0.6vh;
		box-sizing: border-box;
		outline: none;
		transition: border-color 0.15s;
	}

	.player-filter-input:focus {
		border-color: #fb9b04;
	}

	.player-filter-input::placeholder {
		color: #666;
	}

	.snapshot-list {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		padding: 0.8vh;
		display: flex;
		flex-direction: column;
		gap: 0.6vh;
	}

	.player-snapshot-card {
		background: rgba(30, 30, 30, 0.5);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.5vh;
		padding: 0.6vh 0.8vh;
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.6vh;
		transition: all 0.15s;
	}

	.player-snapshot-card:hover {
		background: rgba(38, 38, 38, 0.8);
		border-color: #3e3e3c;
	}

	.player-snapshot-card.reporter-hl {
		border-left: 0.3vh solid #fb9b04;
		background: rgba(251, 155, 4, 0.08);
	}

	.player-snapshot-card.accused-hl {
		border-left: 0.3vh solid #ef4444;
		background: rgba(239, 68, 68, 0.08);
	}

	.ply-left {
		display: flex;
		align-items: center;
		gap: 0.6vh;
		min-width: 0;
	}

	.id-badge-interactive {
		background: rgba(255, 255, 255, 0.08);
		border: 0.1vh solid #3a3a3a;
		color: #fb9b04;
		font-size: 0.9vh;
		font-weight: 700;
		padding: 0.15vh 0.4vh;
		border-radius: 0.3vh;
		cursor: pointer;
		font-family: inherit;
		transition: background-color 0.15s;
		flex-shrink: 0;
	}

	.id-badge-interactive:hover {
		background: rgba(251, 155, 4, 0.25);
		color: #ffffff;
	}

	.ply-name {
		font-size: 1.1vh;
		font-weight: 500;
		color: #f2f2f2;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.ply-tags {
		display: flex;
		align-items: center;
		gap: 0.4vh;
		flex-shrink: 0;
	}

	.badge-role {
		font-size: 0.85vh;
		font-weight: 700;
		padding: 0.1vh 0.4vh;
		border-radius: 0.2vh;
		letter-spacing: 0.03em;
	}

	.badge-reporter {
		background: rgba(251, 155, 4, 0.2);
		color: #fb9b04;
		border: 0.1vh solid rgba(251, 155, 4, 0.4);
	}

	.badge-accused {
		background: rgba(239, 68, 68, 0.2);
		color: #f87171;
		border: 0.1vh solid rgba(239, 68, 68, 0.4);
	}

	.badge-staff {
		background: rgba(59, 130, 246, 0.2);
		color: #60a5fa;
		border: 0.1vh solid rgba(59, 130, 246, 0.4);
	}

	.badge-distance {
		background: rgba(255, 255, 255, 0.08);
		color: #cbd5e1;
		border: 0.1vh solid rgba(255, 255, 255, 0.16);
		font-variant-numeric: tabular-nums;
	}

	/* Shared UI Buttons & Modal */
	.btn {
		padding: 0.6vh 1.2vh;
		border-radius: 0.4vh;
		font-size: 1.1vh;
		font-weight: 600;
		cursor: pointer;
		border: none;
		font-family: inherit;
		display: inline-flex;
		align-items: center;
		gap: 0.6vh;
		transition: all 0.15s;
	}

	.btn-primary {
		background: #fb9b04;
		color: #161616;
	}

	.btn-primary:hover:not(:disabled) {
		background: #ffa826;
	}

	.btn-secondary {
		background: rgba(37, 37, 37, 0.85);
		color: #a3a3a3;
		border: 0.1vh solid #3a3a3a;
	}

	.btn-secondary:hover:not(:disabled) {
		background: rgba(50, 50, 50, 0.9);
		color: #f2f2f2;
	}

	.btn-resolve {
		background: rgba(16, 185, 129, 0.2);
		color: #34d399;
		border: 0.1vh solid rgba(16, 185, 129, 0.4);
	}

	.btn-resolve:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.35);
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-icon {
		background: transparent;
		border: none;
		color: #8c8c8c;
		cursor: pointer;
		padding: 0.4vh;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 0.4vh;
		transition: all 0.15s;
	}

	.btn-icon:hover {
		color: #ef4444;
		background: rgba(239, 68, 68, 0.1);
	}

	.btn-icon svg {
		width: 1.4vh;
		height: 1.4vh;
	}

	/* Modal */
	.modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.75);
		backdrop-filter: blur(0.3vh);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 999999;
	}

	.modal-content {
		background: #161616;
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.8vh;
		padding: 2vh 2.4vh;
		width: 44vh;
		max-width: 90vw;
		display: flex;
		flex-direction: column;
		gap: 1.2vh;
		color: #f2f2f2;
		box-shadow: 0 1vh 3vh rgba(0, 0, 0, 0.8);
	}

	.modal-title {
		margin: 0;
		font-size: 1.5vh;
		font-weight: 600;
	}

	.modal-subtitle {
		margin: 0;
		font-size: 1.1vh;
		color: #8c8c8c;
	}

	.modal-textarea {
		background: rgba(26, 26, 26, 0.9);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.4vh;
		color: #f2f2f2;
		padding: 0.8vh;
		font-size: 1.15vh;
		font-family: inherit;
		resize: none;
		outline: none;
	}

	.modal-textarea:focus {
		border-color: #fb9b04;
	}

	.modal-buttons {
		display: flex;
		justify-content: flex-end;
		gap: 0.8vh;
	}

	.spinner {
		width: 1.6vh;
		height: 1.6vh;
		border: 0.2vh solid rgba(251, 155, 4, 0.3);
		border-top-color: #fb9b04;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
			transform: scale(1);
		}
		50% {
			opacity: 0.5;
			transform: scale(0.9);
		}
	}
</style>
