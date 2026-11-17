<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
	import { onMount } from "svelte";
	import { fetchReportAnalytics, type ReportAnalyticsData } from "../../shared/nui/admin";
	import { notifications } from "../../shared/stores/notifications.svelte";
	import { isChromium } from "../../shared/util/util";

	let loading = $state(false);
	let analyticsData = $state<ReportAnalyticsData | null>(null);
	let lastUpdated = $state<string>("");

	const maxClaims = $derived(analyticsData?.topClaimers?.[0]?.count || 1);
	const maxResponses = $derived(analyticsData?.topResponders?.[0]?.count || 1);
	const maxResolutions = $derived(analyticsData?.topResolvers?.[0]?.count || 1);

	async function loadAnalytics(showToast = false) {
		loading = true;
		try {
			if (!isChromium()) {
				// Provide realistic mock data in browser dev mode
				analyticsData = {
					summary: {
						total: 48,
						open: 5,
						claimed: 7,
						resolved: 36,
						today: 14,
						week: 48,
						totalMessages: 184,
						staffMessages: 112,
						resolutionRate: 75.0,
					},
					topClaimers: [
						{ name: "Hairi Raven", count: 22 },
						{ name: "Mod_Sarah", count: 14 },
						{ name: "Admin_John", count: 8 },
						{ name: "Support_Alex", count: 4 },
					],
					topResponders: [
						{ name: "Hairi Raven", count: 68 },
						{ name: "Mod_Sarah", count: 42 },
						{ name: "Support_Alex", count: 20 },
						{ name: "Admin_John", count: 14 },
					],
					topResolvers: [
						{ name: "Hairi Raven", count: 18 },
						{ name: "Mod_Sarah", count: 11 },
						{ name: "Admin_John", count: 7 },
					],
					categories: [
						{ category: "Player Report", count: 24 },
						{ category: "Bug Report", count: 12 },
						{ category: "Question", count: 8 },
						{ category: "Vehicle Issue", count: 4 },
					],
				};
				lastUpdated = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
				if (showToast) {
					notifications.success("Analytics data updated (Dev Mode).");
				}
				loading = false;
				return;
			}

			const res = await fetchReportAnalytics();
			if (res.ok && res.data) {
				analyticsData = res.data;
				lastUpdated = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
				if (showToast) {
					notifications.success("Analytics data updated.");
				}
			} else {
				if (showToast) {
					notifications.error(res.err || "Failed to load analytics.");
				}
			}
		} catch (err) {
			console.error("[ReportsAnalytics] Failed to fetch analytics:", err);
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		void loadAnalytics(false);
	});

	function getBarWidth(count: number, maxCount: number): string {
		if (maxCount <= 0) return "0%";
		return `${Math.min(100, Math.max(10, Math.round((count / maxCount) * 100)))}%`;
	}
</script>

<div class="analytics-container list-scroll">
	<!-- Top Controls Header -->
	<div class="analytics-header">
		<div class="header-titles">
			<div class="title-row">
				<h2 class="main-title">Staff & Ticket Analytics</h2>
				<span class="pulse-indicator" title="Live statistics"></span>
			</div>
			<span class="sub-title">Performance metrics, response rates, and staff leaderboards.</span>
		</div>

		<div class="header-actions">
			{#if lastUpdated}
				<span class="last-sync">Updated: {lastUpdated}</span>
			{/if}
			<button
				type="button"
				class="btn-refresh"
				onclick={() => loadAnalytics(true)}
				disabled={loading}
				title="Refresh Analytics"
			>
				<svg class:spinning={loading} viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
					<path d="M14 8A6 6 0 1 1 8 2c2 0 3.8 1 4.8 2.5L14 3v3h-3l1.5-1.5A4.5 4.5 0 1 0 12.5 8H14Z" fill="currentColor" />
				</svg>
				<span>{loading ? "Refreshing..." : "Refresh"}</span>
			</button>
		</div>
	</div>

	{#if loading && !analyticsData}
		<div class="loading-state">
			<div class="spinner"></div>
			<span>Calculating staff performance and ticket analytics...</span>
		</div>
	{:else if !analyticsData}
		<div class="empty-state">
			<span>No analytics data available yet.</span>
		</div>
	{:else}
		<!-- Row 1: KPI Summary Cards -->
		<div class="kpi-grid">
			<!-- Total Reports -->
			<div class="kpi-card">
				<div class="kpi-top">
					<span class="kpi-label">Total Tickets Handled</span>
					<span class="kpi-badge total-badge">All Time</span>
				</div>
				<span class="kpi-number">{analyticsData.summary.total}</span>
				<div class="kpi-footer">
					<span class="kpi-sub">Today: <strong>{analyticsData.summary.today}</strong></span>
					<span class="kpi-sub">Last 7d: <strong>{analyticsData.summary.week}</strong></span>
				</div>
			</div>

			<!-- Resolution Rate -->
			<div class="kpi-card">
				<div class="kpi-top">
					<span class="kpi-label">Resolution Rate</span>
					<span class="kpi-badge success-badge">{analyticsData.summary.resolutionRate}%</span>
				</div>
				<span class="kpi-number text-resolved">{analyticsData.summary.resolved}</span>
				<div class="kpi-footer">
					<span class="kpi-sub">Resolved Cases</span>
					<div class="progress-bar-bg">
						<div class="progress-bar-fill fill-resolved" style="width: {analyticsData.summary.resolutionRate}%"></div>
					</div>
				</div>
			</div>

			<!-- Active Backlog -->
			<div class="kpi-card">
				<div class="kpi-top">
					<span class="kpi-label">Active Backlog</span>
					<span class="kpi-badge warning-badge">Live</span>
				</div>
				<span class="kpi-number text-open">{analyticsData.summary.open + analyticsData.summary.claimed}</span>
				<div class="kpi-footer">
					<span class="kpi-sub">Pending: <strong class="text-open">{analyticsData.summary.open}</strong></span>
					<span class="kpi-sub">Claimed: <strong class="text-claimed">{analyticsData.summary.claimed}</strong></span>
				</div>
			</div>

			<!-- Staff Live Chat Activity -->
			<div class="kpi-card">
				<div class="kpi-top">
					<span class="kpi-label">Staff Chat Responses</span>
					<span class="kpi-badge info-badge">Communication</span>
				</div>
				<span class="kpi-number text-chat">{analyticsData.summary.staffMessages}</span>
				<div class="kpi-footer">
					<span class="kpi-sub">Total chat messages sent by staff members</span>
				</div>
			</div>
		</div>

		<!-- Row 2: Three Staff Leaderboards -->
		<div class="leaderboards-grid">
			<!-- Leaderboard 1: Most Claims -->
			<div class="leaderboard-panel">
				<div class="panel-header">
					<div class="panel-title-group">
						<svg class="panel-icon icon-claim" viewBox="0 0 20 20" fill="currentColor">
							<path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z"/>
						</svg>
						<div>
							<h3 class="panel-title">Most Tickets Claimed</h3>
							<span class="panel-desc">Staff who take ownership of incoming tickets</span>
						</div>
					</div>
				</div>

				<div class="leaderboard-list">
					{#if analyticsData.topClaimers.length === 0}
						<div class="board-empty">No claims recorded yet.</div>
					{:else}
						{#each analyticsData.topClaimers as item, index}
							<div class="board-row" class:is-top={index === 0}>
								<div class="board-rank rank-{index + 1}">
									{#if index === 0}🥇{:else if index === 1}🥈{:else if index === 2}🥉{:else}#{index + 1}{/if}
								</div>
								<div class="board-content">
									<div class="board-meta">
										<span class="board-name">{item.name}</span>
										<span class="board-count count-claimed">{item.count} claims</span>
									</div>
									<div class="board-bar-bg">
										<div class="board-bar-fill fill-claimed" style="width: {getBarWidth(item.count, maxClaims)}"></div>
									</div>
								</div>
							</div>
						{/each}
					{/if}
				</div>
			</div>

			<!-- Leaderboard 2: Most Chat Responses -->
			<div class="leaderboard-panel">
				<div class="panel-header">
					<div class="panel-title-group">
						<svg class="panel-icon icon-response" viewBox="0 0 20 20" fill="currentColor">
							<path fill-rule="evenodd" d="M18 10c0 3.866-3.582 7-8 7a8.841 8.841 0 01-4.083-.98L2 17l1.338-3.123C2.493 12.767 2 11.434 2 10c0-3.866 3.582-7 8-7s8 3.134 8 7zM7 9H5v2h2V9zm8 0h-2v2h2V9zM9 9h2v2H9V9z" clip-rule="evenodd"/>
						</svg>
						<div>
							<h3 class="panel-title">Most Active in Chat</h3>
							<span class="panel-desc">Staff sending the most replies to players</span>
						</div>
					</div>
				</div>

				<div class="leaderboard-list">
					{#if analyticsData.topResponders.length === 0}
						<div class="board-empty">No responses recorded yet.</div>
					{:else}
						{#each analyticsData.topResponders as item, index}
							<div class="board-row" class:is-top={index === 0}>
								<div class="board-rank rank-{index + 1}">
									{#if index === 0}🥇{:else if index === 1}🥈{:else if index === 2}🥉{:else}#{index + 1}{/if}
								</div>
								<div class="board-content">
									<div class="board-meta">
										<span class="board-name">{item.name}</span>
										<span class="board-count count-response">{item.count} replies</span>
									</div>
									<div class="board-bar-bg">
										<div class="board-bar-fill fill-response" style="width: {getBarWidth(item.count, maxResponses)}"></div>
									</div>
								</div>
							</div>
						{/each}
					{/if}
				</div>
			</div>

			<!-- Leaderboard 3: Most Resolved -->
			<div class="leaderboard-panel">
				<div class="panel-header">
					<div class="panel-title-group">
						<svg class="panel-icon icon-resolve" viewBox="0 0 20 20" fill="currentColor">
							<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
						</svg>
						<div>
							<h3 class="panel-title">Most Resolved Cases</h3>
							<span class="panel-desc">Staff who successfully close and resolve cases</span>
						</div>
					</div>
				</div>

				<div class="leaderboard-list">
					{#if analyticsData.topResolvers.length === 0}
						<div class="board-empty">No resolved tickets yet.</div>
					{:else}
						{#each analyticsData.topResolvers as item, index}
							<div class="board-row" class:is-top={index === 0}>
								<div class="board-rank rank-{index + 1}">
									{#if index === 0}🥇{:else if index === 1}🥈{:else if index === 2}🥉{:else}#{index + 1}{/if}
								</div>
								<div class="board-content">
									<div class="board-meta">
										<span class="board-name">{item.name}</span>
										<span class="board-count count-resolved">{item.count} resolved</span>
									</div>
									<div class="board-bar-bg">
										<div class="board-bar-fill fill-resolved" style="width: {getBarWidth(item.count, maxResolutions)}"></div>
									</div>
								</div>
							</div>
						{/each}
					{/if}
				</div>
			</div>
		</div>

		<!-- Row 3: Category Distribution -->
		{#if analyticsData.categories && analyticsData.categories.length > 0}
			{@const maxCat = analyticsData.categories[0]?.count || 1}
			<div class="categories-panel">
				<div class="panel-header">
					<div class="panel-title-group">
						<svg class="panel-icon icon-category" viewBox="0 0 20 20" fill="currentColor">
							<path d="M7 3a1 1 0 000 2h6a1 1 0 100-2H7zM4 7a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1zM2 11a2 2 0 012-2h12a2 2 0 012 2v4a2 2 0 01-2 2H4a2 2 0 01-2-2v-4z"/>
						</svg>
						<div>
							<h3 class="panel-title">Report Category Breakdown</h3>
							<span class="panel-desc">Distribution of issues submitted by players</span>
						</div>
					</div>
				</div>

				<div class="categories-grid">
					{#each analyticsData.categories as cat}
						<div class="category-card">
							<div class="cat-meta">
								<span class="cat-name">{cat.category}</span>
								<span class="cat-count">{cat.count} tickets</span>
							</div>
							<div class="board-bar-bg">
								<div class="board-bar-fill fill-category" style="width: {getBarWidth(cat.count, maxCat)}"></div>
							</div>
						</div>
					{/each}
				</div>
			</div>
		{/if}
	{/if}
</div>

<style>
	.analytics-container {
		display: flex;
		flex-direction: column;
		gap: 1.4vh;
		width: 100%;
		height: 100%;
		padding: 0.5vh 0.2vh 1.5vh 0.2vh;
		box-sizing: border-box;
		overflow-y: auto;
	}

	/* Header */
	.analytics-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.8vh 1.4vh;
		background: rgba(22, 22, 22, 0.7);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.6vh;
		flex-shrink: 0;
	}

	.header-titles {
		display: flex;
		flex-direction: column;
		gap: 0.2vh;
	}

	.title-row {
		display: flex;
		align-items: center;
		gap: 0.8vh;
	}

	.main-title {
		margin: 0;
		font-size: 1.6vh;
		font-weight: 700;
		color: #f2f2f2;
	}

	.pulse-indicator {
		width: 0.7vh;
		height: 0.7vh;
		border-radius: 50%;
		background: #10b981;
		box-shadow: 0 0 0.5vh #10b981;
	}

	.sub-title {
		font-size: 1.05vh;
		color: #8c8c8c;
	}

	.header-actions {
		display: flex;
		align-items: center;
		gap: 1vh;
	}

	.last-sync {
		font-size: 1vh;
		color: #71717a;
	}

	.btn-refresh {
		display: flex;
		align-items: center;
		gap: 0.6vh;
		background: rgba(251, 155, 4, 0.12);
		border: 0.1vh solid rgba(251, 155, 4, 0.35);
		color: #fb9b04;
		border-radius: 0.4vh;
		padding: 0.4vh 1vh;
		font-size: 1.1vh;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s ease;
		font-family: inherit;
	}

	.btn-refresh:hover:not(:disabled) {
		background: #fb9b04;
		color: #121212;
	}

	.btn-refresh svg {
		width: 1.2vh;
		height: 1.2vh;
	}

	.spinning {
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Loading & Empty */
	.loading-state,
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 35vh;
		gap: 1.2vh;
		color: #8c8c8c;
		font-size: 1.2vh;
	}

	.spinner {
		width: 2.6vh;
		height: 2.6vh;
		border: 0.25vh solid rgba(251, 155, 4, 0.2);
		border-top-color: #fb9b04;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	/* KPI Grid */
	.kpi-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 1.2vh;
		flex-shrink: 0;
	}

	.kpi-card {
		background: rgba(26, 26, 26, 0.8);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.6vh;
		padding: 1.2vh 1.4vh;
		display: flex;
		flex-direction: column;
		gap: 0.4vh;
	}

	.kpi-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.kpi-label {
		font-size: 1.05vh;
		color: #a1a1aa;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.kpi-badge {
		font-size: 0.9vh;
		font-weight: 700;
		padding: 0.15vh 0.5vh;
		border-radius: 0.3vh;
	}

	.total-badge {
		background: rgba(255, 255, 255, 0.08);
		color: #e4e4e7;
		border: 0.1vh solid #3f3f46;
	}

	.success-badge {
		background: rgba(16, 185, 129, 0.15);
		color: #34d399;
		border: 0.1vh solid rgba(16, 185, 129, 0.3);
	}

	.warning-badge {
		background: rgba(251, 155, 4, 0.15);
		color: #fb9b04;
		border: 0.1vh solid rgba(251, 155, 4, 0.3);
	}

	.info-badge {
		background: rgba(59, 130, 246, 0.15);
		color: #60a5fa;
		border: 0.1vh solid rgba(59, 130, 246, 0.3);
	}

	.kpi-number {
		font-size: 2.4vh;
		font-weight: 800;
		color: #f2f2f2;
		line-height: 1.1;
		font-variant-numeric: tabular-nums;
	}

	.kpi-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: 0.3vh;
		font-size: 1vh;
		color: #71717a;
	}

	.kpi-footer strong {
		color: #d4d4d8;
	}

	.text-resolved {
		color: #34d399;
	}

	.text-open {
		color: #fb9b04;
	}

	.text-claimed {
		color: #60a5fa;
	}

	.text-chat {
		color: #a78bfa;
	}

	.progress-bar-bg {
		width: 7vh;
		height: 0.5vh;
		background: rgba(255, 255, 255, 0.08);
		border-radius: 0.3vh;
		overflow: hidden;
	}

	.progress-bar-fill {
		height: 100%;
		border-radius: 0.3vh;
	}

	/* Leaderboards Grid */
	.leaderboards-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 1.2vh;
		flex-shrink: 0;
	}

	.leaderboard-panel {
		background: rgba(22, 22, 22, 0.85);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.6vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.panel-header {
		padding: 1vh 1.3vh;
		border-bottom: 0.1vh solid #2e2e2c;
		background: rgba(28, 28, 28, 0.7);
	}

	.panel-title-group {
		display: flex;
		align-items: center;
		gap: 0.8vh;
	}

	.panel-icon {
		width: 2vh;
		height: 2vh;
		flex-shrink: 0;
	}

	.icon-claim {
		color: #60a5fa;
	}

	.icon-response {
		color: #a78bfa;
	}

	.icon-resolve {
		color: #34d399;
	}

	.icon-category {
		color: #fb9b04;
	}

	.panel-title {
		margin: 0;
		font-size: 1.25vh;
		font-weight: 700;
		color: #f2f2f2;
	}

	.panel-desc {
		font-size: 0.95vh;
		color: #71717a;
	}

	.leaderboard-list {
		padding: 0.8vh 1vh;
		display: flex;
		flex-direction: column;
		gap: 0.6vh;
		min-height: 20vh;
		max-height: 26vh;
		overflow-y: auto;
	}

	.board-empty {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 18vh;
		color: #71717a;
		font-size: 1.05vh;
		text-align: center;
	}

	.board-row {
		display: flex;
		align-items: center;
		gap: 0.8vh;
		background: rgba(30, 30, 30, 0.6);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.4vh;
		padding: 0.5vh 0.8vh;
		transition: background-color 0.15s;
	}

	.board-row.is-top {
		border-color: rgba(251, 155, 4, 0.4);
		background: rgba(251, 155, 4, 0.06);
	}

	.board-rank {
		font-size: 1.1vh;
		font-weight: 800;
		width: 2.2vh;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		font-variant-numeric: tabular-nums;
	}

	.board-content {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 0.3vh;
	}

	.board-meta {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.board-name {
		font-size: 1.1vh;
		font-weight: 600;
		color: #f2f2f2;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.board-count {
		font-size: 0.95vh;
		font-weight: 700;
		padding: 0.1vh 0.45vh;
		border-radius: 0.25vh;
		font-variant-numeric: tabular-nums;
	}

	.count-claimed {
		color: #60a5fa;
		background: rgba(59, 130, 246, 0.15);
	}

	.count-response {
		color: #a78bfa;
		background: rgba(167, 139, 250, 0.15);
	}

	.count-resolved {
		color: #34d399;
		background: rgba(16, 185, 129, 0.15);
	}

	.board-bar-bg {
		width: 100%;
		height: 0.35vh;
		background: rgba(255, 255, 255, 0.06);
		border-radius: 0.2vh;
		overflow: hidden;
	}

	.board-bar-fill {
		height: 100%;
		border-radius: 0.2vh;
		transition: width 0.3s ease-out;
	}

	.fill-claimed {
		background: #3b82f6;
	}

	.fill-response {
		background: #8b5cf6;
	}

	.fill-resolved {
		background: #10b981;
	}

	.fill-category {
		background: #fb9b04;
	}

	/* Categories Panel */
	.categories-panel {
		background: rgba(22, 22, 22, 0.85);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.6vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		flex-shrink: 0;
	}

	.categories-grid {
		padding: 1vh 1.4vh;
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 1vh;
	}

	.category-card {
		background: rgba(30, 30, 30, 0.6);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.4vh;
		padding: 0.6vh 0.9vh;
		display: flex;
		flex-direction: column;
		gap: 0.4vh;
	}

	.cat-meta {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.cat-name {
		font-size: 1.1vh;
		font-weight: 600;
		color: #f2f2f2;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.cat-count {
		font-size: 0.95vh;
		color: #fb9b04;
		font-weight: 700;
	}
</style>
