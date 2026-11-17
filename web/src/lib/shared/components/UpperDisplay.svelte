<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
	import { t } from "$lib/shared/util/util";
	import "./UpperDisplay.css";
	import DataComponent from "./DataComponent.svelte";
	import ServerIcon from "./icons/ServerIcon.svelte";
	import PlayersIcon from "./icons/PlayersIcon.svelte";
	import { server } from "../stores/server.svelte";

	const {
		onEscape,
		activeView = "reports",
		onSelectView,
	} = $props<{
		onEscape: () => void | Promise<void>;
		activeView?: "reports" | "analytics";
		onSelectView?: (view: "reports" | "analytics") => void;
	}>();

	const playerCount = $derived(`${t("players")} ${server.currentPlayers}/${server.maxPlayers}`);
	const uptime = $derived(`${t("server_uptime")}: ${server.uptimeFormatted}`);
</script>

<div class="upper-display-container">
	<svg class="menu-icon" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
		<rect width="44" height="44" rx="4" fill="#FB9B04" />
		<path
			fill-rule="evenodd"
			clip-rule="evenodd"
			d="M13 20.4167C13 17.2191 13 15.6203 13.3775 15.0824C13.755 14.5445 15.2583 14.03 18.2649 13.0008L18.8377 12.8047C20.405 12.2682 21.1886 12 22 12C22.8114 12 23.595 12.2682 25.1623 12.8047L25.7351 13.0008C28.7417 14.03 30.245 14.5445 30.6225 15.0824C31 15.6203 31 17.2191 31 20.4167V21.9914C31 27.6294 26.761 30.3655 24.1014 31.5273C23.38 31.8424 23.0193 32 22 32C20.9807 32 20.62 31.8424 19.8986 31.5273C17.239 30.3655 13 27.6294 13 21.9914V20.4167ZM24 19C24 20.1046 23.1046 21 22 21C20.8954 21 20 20.1046 20 19C20 17.8954 20.8954 17 22 17C23.1046 17 24 17.8954 24 19ZM22 27C26 27 26 26.1046 26 25C26 23.8954 24.2091 23 22 23C19.7909 23 18 23.8954 18 25C18 26.1046 18 27 22 27Z"
			fill="#161616"
		/>
	</svg>
	<div class="menu-titles">
		<span class="menu-title">Support & Reports</span>
		<span class="menu-subtitle">Player Tickets & Staff Analytics</span>
	</div>

	<!-- Segmented View Switcher -->
	<div class="top-nav-switcher">
		<button
			type="button"
			class="nav-tab-btn"
			class:active={activeView === "reports"}
			onclick={() => onSelectView?.("reports")}
		>
			<svg viewBox="0 0 16 16" fill="currentColor" class="nav-tab-icon">
				<path d="M14 4.5V14a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2h5.5L14 4.5zm-3 0A1.5 1.5 0 0 1 9.5 3V1H4a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V4.5h-2z"/>
			</svg>
			<span>Tickets Workspace</span>
		</button>
		<button
			type="button"
			class="nav-tab-btn"
			class:active={activeView === "analytics"}
			onclick={() => onSelectView?.("analytics")}
		>
			<svg viewBox="0 0 16 16" fill="currentColor" class="nav-tab-icon">
				<path d="M1 11a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1v-4zm6-4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V7zm6-5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1V2z"/>
			</svg>
			<span>Staff Analytics</span>
		</button>
	</div>

	<div class="data-components">
		<DataComponent content={uptime} icon={ServerIcon} />
		<DataComponent content={playerCount} icon={PlayersIcon} />
		<button class="close-button" onclick={onEscape} aria-label="close-menu">
			<svg class="close-icon" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
				<path
					fill-rule="evenodd"
					clip-rule="evenodd"
					d="M15 13.6187L13.6187 15L7.5 8.8716L1.38132 15L0 13.6187L6.1284 7.5L0 1.38132L1.38132 0L7.5 6.1284L13.6187 0L15 1.38132L8.8716 7.5L15 13.6187Z"
					fill="#F2F2F2"
				/>
			</svg>
		</button>
	</div>
</div>
