/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import type { ServerState } from "../types/server";
import type { Translations } from "../stores/translations.svelte";
import type { Player } from "../types/player";

type InitResourceData = {
  translations: Translations;
  serverData: ServerState;
};

export type NuiMessage =
	| { action: "initResource"; data: InitResourceData }
	| { action: "openAdmin"; data: Player[] }
	| { action: "openAdminDashboard"; data: { players: Player[]; serverData?: ServerState; selectedPlayerId?: number } }
	| { action: "updateServerData"; data: ServerState }
	| { action: "updatePlayers"; data: Player[] }
	| { action: "closeAdmin"; data?: undefined };

export function listenNui<T extends { action: string }>(
  handler: (message: T) => void
) {
  const listener = (event: MessageEvent<T>) => {
    if (!event.data?.action) return;
    handler(event.data);
  };

  window.addEventListener("message", listener);

  return () => window.removeEventListener("message", listener);
}
