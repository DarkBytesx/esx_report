/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import type { Player } from "../types/player";

const names = [
	"John Doe",
	"Jane Doe",
	"Ryan Reynolds",
	"John Wick",
	"Michael Scott",
	"Walter White",
	"Tony Stark",
	"Bruce Wayne",
	"Arthur Morgan",
	"Geralt of Rivia",
	"Tom Shelby",
	"Joel Miller",
];

export function generateDummyPlayers(count: number): Player[] {
	return Array.from({ length: count }, (_, i) => {
		const name = names[i % names.length];
		const status: Player["status"] = Math.random() > 0.5 ? "online" : "offline";

		const basePlayer = {
			name,
			status,

			cash: Math.floor(Math.random() * 10_000),
			bank: Math.floor(Math.random() * 1_000_000),
			alt_money: Math.floor(Math.random() * 500_000),

			last_join: Date.now() - Math.floor(Math.random() * 1000 * 60 * 60 * 24 * 30),

			char_identifier: `char1:${Math.random().toString(16).slice(2)}`,
			identifier: `license:${Math.random().toString(16).slice(2)}`,

			job: "Unemployed",
			job_grade: "Unknown",
			gender: Math.random() > 0.5 ? "m" : "f",

			play_time: {
				days: Math.floor(Math.random() * 30),
				hours: Math.floor(Math.random() * 24),
				minutes: Math.floor(Math.random() * 60),
			},

			position: {
				x: Math.random() * 4000 - 2000,
				y: Math.random() * 4000 - 2000,
				z: Math.random() * 100,
			},
		};

		if (status === "offline") {
			return basePlayer as Player;
		}

		// online-only fields
		return {
			...basePlayer,
			id: i + 1,
			health: Math.floor(Math.random() * 100),
			armor: Math.floor(Math.random() * 100),
		} as Player;
	});
}
