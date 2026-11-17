/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import type { Player } from "../types/player";
import { generateDummyPlayers } from "../util/generateDummyData";
import type { AdminReport, ReportMessage } from "../../tabs/reports/types/report";
import { isChromium } from "../util/util";
import { fetchNui } from "../nui/fetchNUI";

export class UIState {
	visible = $state(!isChromium());
	mode = $state<"dashboard" | "report" | "player_ticket">("dashboard");
	activePlayerReport = $state<AdminReport | null>(null);
	activePlayerMessages = $state<ReportMessage[]>([]);
	reportCategories = $state<Array<{ id: string; label: string }>>([
		{ id: "player", label: "Player Report" },
		{ id: "rule_break", label: "Rule Break / Griefing" },
		{ id: "bug", label: "Bug / Glitch" },
		{ id: "question", label: "Question / Help" },
		{ id: "other", label: "Other" },
	]);
	spectating = $state(false);
	players = $state<Player[] | null>(isChromium() ? null : generateDummyPlayers(200));

	openDashboard(players: Player[]) {
		this.visible = true;
		this.mode = "dashboard";
		this.spectating = false;
		this.players = players;
	}

	open(players: Player[]) {
		this.openDashboard(players);
	}

	openReportDialog(categories?: Array<{ id: string; label: string }>) {
		this.visible = true;
		this.mode = "report";
		this.spectating = false;
		if (categories && categories.length > 0) {
			this.reportCategories = categories;
		}
	}

	openPlayerTicketChat(report: AdminReport, messages: ReportMessage[]) {
		this.visible = true;
		this.mode = "player_ticket";
		this.spectating = false;
		this.activePlayerReport = report;
		this.activePlayerMessages = messages;
	}

	addReportMessage(message: ReportMessage) {
		if (this.activePlayerReport && this.activePlayerReport.id === message.report_id) {
			this.activePlayerMessages = [...this.activePlayerMessages, message];
		}
	}

	closePlayerTicket() {
		this.activePlayerReport = null;
		this.activePlayerMessages = [];
		if (this.mode === "player_ticket" || this.mode === "report") {
			this.close();
			void fetchNui("releaseFocus", { release: true });
		}
	}

	close() {
		this.visible = false;
	}

	spectate() {
		this.spectating = true;
		this.visible = false;
	}

	stopSpectate() {
		this.spectating = false;
		this.visible = true;
		this.mode = "dashboard";
	}

	setPlayers(players: Player[]) {
		this.players = players;
	}

	removePlayer(playerId: number) {
		if (!this.players) return;
		this.players = this.players.filter((p) => p.id !== playerId);
	}
}

export const uiState = new UIState();
