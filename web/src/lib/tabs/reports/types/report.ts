/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

export type ReportCategory = {
	id: string;
	label: string;
};

export type ReportMessage = {
	id: number;
	report_id: number;
	sender_identifier: string;
	sender_name: string;
	is_staff: number | boolean;
	message: string;
	created_at: string | number;
};

export type SnapshotPlayer = {
	id: number | string;
	name: string;
	is_staff?: boolean;
	group?: string;
	distance?: number | null;
};

export type OnlineStaffMember = {
	id: number;
	name: string;
	group?: string;
};

export type AdminReport = {
	id: number;
	title?: string | null;
	reporter_identifier: string;
	reporter_name: string;
	reporter_source?: number | null;
	reporter_online?: boolean;
	reporter_current_source?: number | null;
	target_identifier?: string | null;
	target_name?: string | null;
	target_source?: number | null;
	target_online?: boolean;
	target_current_source?: number | null;
	category: string;
	reason: string;
	status: "open" | "claimed" | "resolved";
	claimed_by?: string | null;
	claimed_name?: string | null;
	resolution_notes?: string | null;
	players_snapshot?: SnapshotPlayer[] | string | null;
	staff_snapshot?: SnapshotPlayer[] | string | null;
	created_at: string | number;
	updated_at?: string | number;
};

export type ReportFilters = {
	status?: "all" | "open" | "claimed" | "resolved";
	search?: string;
	limit?: number;
};
