<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import { uiState } from "./lib/shared/stores/user.svelte";
	import UpperDisplay from "./lib/shared/components/UpperDisplay.svelte";
	import Notifications from "./lib/shared/components/Notifications.svelte";
	import ReportModal from "./lib/tabs/reports/ReportModal.svelte";
	import PlayerTicketChat from "./lib/tabs/reports/PlayerTicketChat.svelte";
	import ReportsManagement from "./lib/tabs/reports/ReportsManagement.svelte";
	import ReportsAnalytics from "./lib/tabs/reports/ReportsAnalytics.svelte";
	import { fetchNui } from "./lib/shared/nui/fetchNUI";

	let activeView = $state<"reports" | "analytics">("reports");

	async function handleEscape() {
		const res = await fetchNui("releaseFocus", { release: true });

		if (res !== null) {
			uiState.close();
		}
	}

	function handleKeyDown(event: KeyboardEvent) {
		if (event.key === "Escape") {
			if (document.querySelector(".modal-backdrop")) {
				return;
			}
			if (uiState.visible) {
				handleEscape();
			}
		}
	}

	$effect(() => {
		window.addEventListener("keydown", handleKeyDown);

		return () => {
			window.removeEventListener("keydown", handleKeyDown);
		};
	});
</script>

{#if uiState.visible && uiState.mode === "dashboard"}
	<div class="esx-report-container esx-adminmenu-container">
		<UpperDisplay
			onEscape={handleEscape}
			{activeView}
			onSelectView={(v) => {
				activeView = v;
			}}
		/>
		<div class="menu-content">
			<div class="tab-container">
				<div class="tab-wrapper">
					{#if activeView === "reports"}
						<ReportsManagement />
					{:else}
						<ReportsAnalytics />
					{/if}
				</div>
			</div>
		</div>
	</div>
{:else if uiState.visible && uiState.mode === "report"}
	<ReportModal />
{:else if uiState.visible && uiState.mode === "player_ticket"}
	<PlayerTicketChat />
{/if}
<Notifications />
{#if uiState.spectating}
	<div class="spectate-tooltip-container">
		<div class="spectate-tooltip">
			{t("escape_spectate")}
		</div>
	</div>
{/if}
