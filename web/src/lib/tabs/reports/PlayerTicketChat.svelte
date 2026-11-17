<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
	import { onMount, tick } from "svelte";
	import { fetchNui } from "$lib/shared/nui/fetchNUI";
	import { sendReportMessage, resolveReport } from "$lib/shared/nui/admin";
	import { uiState } from "$lib/shared/stores/user.svelte";
	import { notifications } from "$lib/shared/stores/notifications.svelte";
	import { getTimestampMs, relativeTime } from "$lib/shared/util/formatter";

	let chatContainer = $state<HTMLDivElement | null>(null);
	let messageText = $state("");
	let sending = $state(false);
	let closing = $state(false);

	const report = $derived(uiState.activePlayerReport);
	const messages = $derived(uiState.activePlayerMessages);

	async function scrollToBottom() {
		await tick();
		if (chatContainer) {
			chatContainer.scrollTop = chatContainer.scrollHeight;
		}
	}

	async function handleCloseUi() {
		await fetchNui("releaseFocus", { release: true });
		uiState.close();
	}

	async function handleSendMessage(e?: SubmitEvent) {
		if (e) e.preventDefault();
		if (!report) return;

		const trimmed = messageText.trim();
		if (trimmed === "" || sending) return;

		sending = true;
		try {
			const res = await sendReportMessage(report.id, trimmed);
			if (res?.success) {
				const newMsg: ReportMessage = res.message || {
					id: Date.now(),
					report_id: report.id,
					sender_identifier: "player",
					sender_name: "Me",
					is_staff: 0,
					message: trimmed,
					created_at: Date.now(),
				};
				uiState.addReportMessage(newMsg);
				messageText = "";
				void scrollToBottom();
			} else {
				notifications.error(res?.err || "Failed to send message.");
			}
		} catch (err) {
			notifications.error("An error occurred while sending your message.");
		} finally {
			sending = false;
		}
	}

	async function handleCloseTicket() {
		if (!report || closing) return;
		closing = true;
		try {
			const res = await resolveReport(report.id, "Closed by player.");
			if (res?.success) {
				notifications.success("Your ticket has been closed.");
				uiState.closePlayerTicket();
				await fetchNui("releaseFocus", { release: true });
			} else {
				notifications.error(res?.err || "Failed to close ticket.");
			}
		} catch (err) {
			notifications.error("Failed to close ticket.");
		} finally {
			closing = false;
		}
	}

	$effect(() => {
		if (messages.length > 0) {
			void scrollToBottom();
		}
	});

	onMount(() => {
		void scrollToBottom();
	});
</script>

<div class="ticket-modal-backdrop" onclick={handleCloseUi} role="presentation">
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<div class="ticket-modal-card" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
		{#if report}
			<!-- Header -->
			<div class="ticket-header">
				<div class="ticket-header-info">
					<div class="badge-row">
						<span class="ticket-id-badge">TICKET #{report.id}</span>
						<span class="status-badge" class:claimed={report.status === "claimed"} class:open={report.status === "open"}>
							{report.status === "claimed" ? "IN PROGRESS" : "PENDING STAFF"}
						</span>
						<span class="category-badge">{report.category}</span>
					</div>
					<h2 class="ticket-title">
						{report.title || (report.status === "claimed" && report.claimed_name ? `Staff: ${report.claimed_name}` : "Waiting for staff...")}
					</h2>
				</div>
				<button type="button" class="close-icon-btn" onclick={handleCloseUi} aria-label="Close dialog">
					<svg viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">
						<path
							fill-rule="evenodd"
							clip-rule="evenodd"
							d="M15 13.6187L13.6187 15L7.5 8.8716L1.38132 15L0 13.6187L6.1284 7.5L0 1.38132L1.38132 0L7.5 6.1284L13.6187 0L15 1.38132L8.8716 7.5L15 13.6187Z"
							fill="currentColor"
						/>
					</svg>
				</button>
			</div>

			<!-- Initial report reason info -->
			<div class="original-issue-box">
				<span class="issue-label">Report Issue:</span>
				<span class="issue-text">{report.reason}</span>
			</div>

			<!-- Live Conversation Stream -->
			<div class="chat-messages-container" bind:this={chatContainer}>
				{#if messages.length === 0}
					<div class="empty-chat">
						<span>No messages yet. Send a message to talk directly with staff.</span>
					</div>
				{:else}
					{#each messages as msg (msg.id)}
						{@const isStaffMsg = Boolean(msg.is_staff)}
						<div class="message-row" class:is-staff={isStaffMsg} class:is-player={!isStaffMsg}>
							<div class="message-bubble">
								<div class="message-meta">
									<span class="sender-name">
										{isStaffMsg ? `Staff (${msg.sender_name})` : "You"}
									</span>
									<span class="message-time">{relativeTime(getTimestampMs(msg.created_at))}</span>
								</div>
								<p class="message-body">{msg.message}</p>
							</div>
						</div>
					{/each}
				{/if}
			</div>

			<!-- Chat Input Bar -->
			<form class="chat-input-bar" onsubmit={handleSendMessage}>
				<input
					type="text"
					class="chat-text-input"
					placeholder="Type your message to staff..."
					bind:value={messageText}
					maxlength="500"
				/>
				<button type="submit" class="btn-send" disabled={sending || messageText.trim() === ""}>
					Send
				</button>
			</form>

			<!-- Footer with Close Ticket option -->
			<div class="ticket-footer">
				<span class="ticket-hint">Close this ticket when your issue is resolved.</span>
				<button type="button" class="btn-close-ticket" onclick={handleCloseTicket} disabled={closing}>
					{closing ? "Closing..." : "Close Ticket"}
				</button>
			</div>
		{:else}
			<div class="empty-chat">
				<span>No active ticket.</span>
				<button type="button" class="btn-close-ticket" onclick={handleCloseUi}>Close</button>
			</div>
		{/if}
	</div>
</div>

<style>
	.ticket-modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.75);
		backdrop-filter: blur(0.4vh);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 99999;
		animation: fadeIn 0.2s ease-out;
		font-family: "Poppins", sans-serif;
	}

	.ticket-modal-card {
		background: #161616;
		border: 0.1vh solid #2e2e2c;
		border-radius: 1vh;
		width: 90vw;
		max-width: 58vh;
		height: 65vh;
		box-sizing: border-box;
		padding: 2vh 2.4vh;
		color: #f2f2f2;
		box-shadow: 0 1vh 3vh rgba(0, 0, 0, 0.7);
		display: flex;
		flex-direction: column;
		gap: 1.2vh;
		animation: scaleIn 0.25s cubic-bezier(0.16, 1, 0.3, 1);
	}

	.ticket-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		border-bottom: 0.1vh solid #2e2e2c;
		padding-bottom: 1vh;
	}

	.ticket-header-info {
		display: flex;
		flex-direction: column;
		gap: 0.4vh;
	}

	.badge-row {
		display: flex;
		align-items: center;
		gap: 0.6vh;
	}

	.ticket-id-badge {
		background: rgba(251, 155, 4, 0.15);
		color: #fb9b04;
		border: 0.1vh solid rgba(251, 155, 4, 0.3);
		border-radius: 0.3vh;
		font-size: 1vh;
		font-weight: 700;
		padding: 0.2vh 0.6vh;
	}

	.status-badge {
		font-size: 0.95vh;
		font-weight: 700;
		padding: 0.2vh 0.6vh;
		border-radius: 0.3vh;
	}

	.status-badge.claimed {
		background: rgba(59, 130, 246, 0.15);
		color: #60a5fa;
		border: 0.1vh solid rgba(59, 130, 246, 0.3);
	}

	.status-badge.open {
		background: rgba(251, 155, 4, 0.15);
		color: #fb9b04;
		border: 0.1vh solid rgba(251, 155, 4, 0.3);
	}

	.category-badge {
		background: rgba(255, 255, 255, 0.06);
		color: #a3a3a3;
		border: 0.1vh solid #333;
		font-size: 0.95vh;
		padding: 0.2vh 0.6vh;
		border-radius: 0.3vh;
	}

	.ticket-title {
		margin: 0;
		font-size: 1.6vh;
		font-weight: 600;
		color: #f2f2f2;
	}

	.close-icon-btn {
		background: transparent;
		border: none;
		color: #8c8c8c;
		cursor: pointer;
		width: 2.4vh;
		height: 2.4vh;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 0.4vh;
		padding: 0.4vh;
		transition: all 0.15s;
	}

	.close-icon-btn:hover {
		color: #f2f2f2;
		background: rgba(255, 255, 255, 0.08);
	}

	.original-issue-box {
		background: rgba(24, 24, 24, 0.85);
		border: 0.1vh solid #282828;
		border-left: 0.3vh solid #fb9b04;
		border-radius: 0.4vh;
		padding: 0.7vh 1vh;
		font-size: 1.1vh;
		display: flex;
		flex-direction: column;
		gap: 0.2vh;
	}

	.issue-label {
		font-weight: 600;
		color: #fb9b04;
		font-size: 1vh;
	}

	.issue-text {
		color: #e5e5e5;
		white-space: pre-wrap;
		word-break: break-word;
	}

	.chat-messages-container {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 1vh;
		padding: 0.8vh 0.4vh;
	}

	.empty-chat {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: #737373;
		font-size: 1.15vh;
		text-align: center;
		gap: 1vh;
	}

	.message-row {
		display: flex;
		width: 100%;
	}

	.message-row.is-staff {
		justify-content: flex-start;
	}

	.message-row.is-player {
		justify-content: flex-end;
	}

	.message-bubble {
		max-width: 80%;
		padding: 0.8vh 1.2vh;
		border-radius: 0.6vh;
		display: flex;
		flex-direction: column;
		gap: 0.3vh;
		box-sizing: border-box;
	}

	.message-row.is-staff .message-bubble {
		background: rgba(59, 130, 246, 0.12);
		border: 0.1vh solid rgba(59, 130, 246, 0.3);
		border-top-left-radius: 0.1vh;
	}

	.message-row.is-player .message-bubble {
		background: rgba(251, 155, 4, 0.12);
		border: 0.1vh solid rgba(251, 155, 4, 0.3);
		border-top-right-radius: 0.1vh;
	}

	.message-meta {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 1vh;
		font-size: 0.95vh;
	}

	.message-row.is-staff .sender-name {
		font-weight: 700;
		color: #60a5fa;
	}

	.message-row.is-player .sender-name {
		font-weight: 700;
		color: #fb9b04;
	}

	.message-time {
		color: #6b7280;
	}

	.message-body {
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
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.6vh;
		padding: 0.4vh 0.6vh;
	}

	.chat-text-input {
		flex: 1;
		background: transparent;
		border: none;
		outline: none;
		color: #f2f2f2;
		font-size: 1.2vh;
		font-family: inherit;
		padding: 0.4vh 0.6vh;
	}

	.chat-text-input::placeholder {
		color: #666;
	}

	.btn-send {
		background: #fb9b04;
		color: #161616;
		border: none;
		border-radius: 0.4vh;
		padding: 0.6vh 1.4vh;
		font-size: 1.15vh;
		font-weight: 600;
		cursor: pointer;
		font-family: inherit;
		transition: background-color 0.15s;
	}

	.btn-send:hover:not(:disabled) {
		background: #ffa826;
	}

	.btn-send:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.ticket-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		border-top: 0.1vh solid #2e2e2c;
		padding-top: 0.8vh;
	}

	.ticket-hint {
		font-size: 1.05vh;
		color: #737373;
	}

	.btn-close-ticket {
		background: rgba(239, 68, 68, 0.15);
		color: #fca5a5;
		border: 0.1vh solid rgba(239, 68, 68, 0.3);
		border-radius: 0.4vh;
		padding: 0.5vh 1.2vh;
		font-size: 1.1vh;
		font-weight: 600;
		cursor: pointer;
		font-family: inherit;
		transition: all 0.15s;
	}

	.btn-close-ticket:hover:not(:disabled) {
		background: rgba(239, 68, 68, 0.25);
		color: #ef4444;
	}

	.btn-close-ticket:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.95); }
		to { opacity: 1; transform: scale(1); }
	}
</style>
