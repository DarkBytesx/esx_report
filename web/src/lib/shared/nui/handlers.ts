/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import { listenNui } from "./receiveNUI";
import type { ServerState } from "../types/server";
import { server } from "../stores/server.svelte";
import type { Translations } from "../stores/translations.svelte";
import { translations } from "../stores/translations.svelte";
import { uiState } from "../stores/user.svelte";
import { stopSpectate } from "./admin";
import { copyToClipboardChromium } from "../util/util";
import type { Player } from "../types/player";
import type { AdminReport, ReportMessage } from "../../tabs/reports/types/report";

type NuiMessage =
	| { action: "initResource"; data: { translations: Translations; serverData: ServerState } }
	| { action: "openAdminDashboard"; data: { players: Player[]; serverData?: ServerState } }
	| { action: "updateServerData"; data: ServerState }
	| { action: "updatePlayers"; data: Player[] }
	| { action: "stopSpectate"; data: boolean }
	| { action: "closeAdmin" }
	| { action: "openReportDialog"; data?: { categories?: Array<{ id: string; label: string }> } }
	| { action: "openPlayerTicketChat"; data: { report: AdminReport; messages: ReportMessage[] } }
	| { action: "reportChatMessage"; data: ReportMessage }
	| { action: "reportClosed"; data?: { reportId: number; notes?: string } }
	| { action: "reportUpdated" }
	| { action: "copyToClipboard"; data: string };

listenNui<NuiMessage>((msg) => {
	switch (msg.action) {
		case "initResource":
			if (!msg.data) return;

			server.set(msg.data.serverData);

			if (msg.data.translations && Object.keys(msg.data.translations).length > 0) {
				translations.set(msg.data.translations);
			}
			break;

		case "openAdminDashboard":
			if (!msg.data) return null;
			if (msg.data.serverData) {
				server.set(msg.data.serverData);
			}
			uiState.openDashboard(msg.data.players ?? []);
			break;

		case "updateServerData":
			if (!msg.data) return null;
			server.set(msg.data);
			break;

		case "updatePlayers":
			if (!msg.data) return null;
			uiState.setPlayers(msg.data);
			break;

		case "stopSpectate":
			if (!msg.data) return null;
			stopSpectate(msg.data);
			break;

		case "closeAdmin":
			uiState.close();
			break;

		case "openReportDialog":
			uiState.openReportDialog(msg.data?.categories);
			break;

		case "openPlayerTicketChat":
			if (msg.data) {
				uiState.openPlayerTicketChat(msg.data.report, msg.data.messages);
			}
			break;

		case "reportChatMessage":
			if (msg.data) {
				uiState.addReportMessage(msg.data);
				window.dispatchEvent(new CustomEvent("esx_report:reportChatMessage", { detail: msg.data }));
				window.dispatchEvent(new CustomEvent("esx-adminmenu:reportChatMessage", { detail: msg.data }));
			}
			break;

		case "reportClosed":
			uiState.closePlayerTicket();
			window.dispatchEvent(new CustomEvent("esx_report:reportClosed", { detail: msg.data }));
			window.dispatchEvent(new CustomEvent("esx-adminmenu:reportClosed", { detail: msg.data }));
			break;

		case "reportUpdated":
			window.dispatchEvent(new CustomEvent("esx_report:reportUpdated"));
			window.dispatchEvent(new CustomEvent("esx-adminmenu:reportUpdated"));
			break;

		case "copyToClipboard":
			if (!msg.data) return null;
			copyToClipboardChromium(msg.data);
			break;
	}
});
