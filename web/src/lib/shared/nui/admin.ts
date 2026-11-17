/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import { fetchNui } from "./fetchNUI";
import { uiState } from "../stores/user.svelte";
import type { ServerState } from "../types/server";
import type { AdminReport, ReportFilters, ReportMessage, OnlineStaffMember } from "../../tabs/reports/types/report";

// Callback response type
export type NuiSuccess = {
	success: boolean;
	playerOnline?: boolean;
	err?: string;
	message?: string;
	serverData?: ServerState;
};

// Player Actions for Staff in Reports
export const bringPlayer = (playerId: number) => fetchNui<NuiSuccess>("bring", { id: playerId });

export const gotoPlayer = (playerId: number) => fetchNui<NuiSuccess>("goto", { id: playerId });

export const spectatePlayer = async (playerId: number) => {
	const res = await fetchNui<NuiSuccess>("spectate", { id: playerId });

	if (res?.success) {
		uiState.spectate();
	}
};

export const stopSpectate = (bool: boolean) => {
	if (bool) {
		uiState.stopSpectate();
	}
};

// Report Core Endpoints
type ReportsResponse = NuiSuccess & {
	reports?: AdminReport[];
	openCount?: number;
	onlineStaff?: OnlineStaffMember[];
};

export const fetchReports = async (filters: ReportFilters = {}) => {
	const res = await fetchNui<ReportsResponse>("getReports", filters);

	return {
		reports: res?.success ? (res.reports ?? []) : [],
		openCount: res?.openCount ?? 0,
		onlineStaff: res?.onlineStaff ?? [],
		ok: res?.success === true,
	};
};

export const claimReport = async (reportId: number) => {
	return fetchNui<NuiSuccess & { claimedName?: string }>("report:claim", { reportId });
};

export const unclaimReport = async (reportId: number) => {
	return fetchNui<NuiSuccess>("report:unclaim", { reportId });
};

export const resolveReport = async (reportId: number, notes?: string) => {
	return fetchNui<NuiSuccess>("report:resolve", { reportId, notes });
};

export const replyReport = async (reportId: number, message: string) => {
	return fetchNui<NuiSuccess>("report:reply", { reportId, message });
};

export const deleteReport = async (reportId: number) => {
	return fetchNui<NuiSuccess>("report:delete", { reportId });
};

export const submitReport = async (payload: { category: string; title?: string; targetId?: number | null; reason: string }) => {
	return fetchNui<NuiSuccess & { reportId?: number }>("submitReport", payload);
};

export const getReportMessages = async (reportId: number) => {
	const res = await fetchNui<NuiSuccess & { report?: AdminReport; messages?: ReportMessage[] }>("getReportMessages", { reportId });
	return {
		report: res?.report,
		messages: res?.messages ?? [],
		ok: res?.success === true,
	};
};

export const sendReportMessage = async (reportId: number, message: string) => {
	return fetchNui<NuiSuccess & { message?: ReportMessage }>("sendReportMessage", { reportId, message });
};

// Analytics Data Types & Fetcher
export type StaffLeaderboardItem = {
	name: string;
	count: number;
};

export type ReportCategoryItem = {
	category: string;
	count: number;
};

export type ReportAnalyticsData = {
	summary: {
		total: number;
		open: number;
		claimed: number;
		resolved: number;
		today: number;
		week: number;
		totalMessages: number;
		staffMessages: number;
		resolutionRate: number;
	};
	topClaimers: StaffLeaderboardItem[];
	topResponders: StaffLeaderboardItem[];
	topResolvers: StaffLeaderboardItem[];
	categories: ReportCategoryItem[];
};

export const fetchReportAnalytics = async () => {
	const res = await fetchNui<NuiSuccess & { data?: ReportAnalyticsData }>("getReportAnalytics");
	return {
		ok: res?.success === true,
		data: res?.data,
		err: res?.err,
	};
};
