<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script lang="ts">
	import { fetchNui } from "$lib/shared/nui/fetchNUI";
	import { submitReport } from "$lib/shared/nui/admin";
	import { uiState } from "$lib/shared/stores/user.svelte";
	import { notifications } from "$lib/shared/stores/notifications.svelte";

	let category = $state(uiState.reportCategories[0]?.label ?? "Player Report");
	let title = $state("");
	let reason = $state("");
	let submitting = $state(false);
	let errorMessage = $state<string | null>(null);

	async function handleClose() {
		errorMessage = null;
		title = "";
		reason = "";
		await fetchNui("releaseFocus", { release: true });
		uiState.close();
	}

	async function handleSubmit(e: SubmitEvent) {
		e.preventDefault();
		errorMessage = null;

		const trimmedTitle = title.trim();
		if (trimmedTitle.length < 3) {
			errorMessage = "Please enter a report title (at least 3 characters).";
			return;
		}

		if (trimmedTitle.length > 100) {
			errorMessage = "Report title cannot exceed 100 characters.";
			return;
		}

		const trimmedReason = reason.trim();
		if (trimmedReason.length < 5) {
			errorMessage = "Please enter at least 5 characters for your report details.";
			return;
		}

		if (trimmedReason.length > 500) {
			errorMessage = "Report description cannot exceed 500 characters.";
			return;
		}

		submitting = true;

		try {
			const res = await submitReport({
				category,
				title: trimmedTitle,
				reason: trimmedReason,
			});

			if (res?.success) {
				notifications.success(res.message || "Your report has been submitted to staff!");
				await handleClose();
			} else {
				errorMessage = res?.err || res?.message || "Failed to submit report. Please try again.";
			}
		} catch (err: unknown) {
			errorMessage = "An unexpected error occurred while submitting your report.";
		} finally {
			submitting = false;
		}
	}
</script>

<div class="report-modal-backdrop" onclick={handleClose} role="presentation">
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<div class="report-modal-card" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
		<div class="report-modal-header">
			<div class="header-titles">
				<div class="badge-tag">STAFF TICKET</div>
				<h2 class="report-title">Submit a Report</h2>
				<p class="report-subtitle">Need assistance or reporting a player? Fill out the details below.</p>
			</div>
			<button type="button" class="close-btn" onclick={handleClose} aria-label="Close">
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

		{#if errorMessage}
			<div class="error-banner">
				<svg viewBox="0 0 20 20" fill="currentColor">
					<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
				</svg>
				<span>{errorMessage}</span>
			</div>
		{/if}

		<form class="report-form" onsubmit={handleSubmit}>
			<!-- Category Selector -->
			<div class="form-group">
				<label for="report-category" class="form-label">Category</label>
				<div class="category-pills">
					{#each uiState.reportCategories as cat}
						<button
							type="button"
							class="category-pill"
							class:selected={category === cat.label}
							onclick={() => (category = cat.label)}
						>
							{cat.label}
						</button>
					{/each}
				</div>
			</div>

			<!-- Report Title -->
			<div class="form-group">
				<div class="label-row">
					<label for="report-title-input" class="form-label">Report Title</label>
					<span class="label-hint">Required</span>
				</div>
				<input
					id="report-title-input"
					type="text"
					class="form-input"
					placeholder="e.g. Lost car after crash, RDM at Legion, Bug with inventory..."
					bind:value={title}
					maxlength="100"
					required
				/>
			</div>

			<!-- Reason / Description -->
			<div class="form-group">
				<div class="label-row">
					<label for="report-reason" class="form-label">Description & Details</label>
					<span class="char-count" class:limit={reason.length > 500}>{reason.length} / 500</span>
				</div>
				<textarea
					id="report-reason"
					class="form-textarea"
					placeholder="Explain what happened, location, and relevant details..."
					bind:value={reason}
					rows="4"
					maxlength="500"
					required
				></textarea>
			</div>

			<!-- Footer Buttons -->
			<div class="report-modal-footer">
				<button type="button" class="btn btn-secondary" onclick={handleClose} disabled={submitting}>
					Cancel
				</button>
				<button type="submit" class="btn btn-primary" disabled={submitting || title.trim().length < 3 || reason.trim().length < 5}>
					{#if submitting}
						<span class="spinner"></span> Submitting...
					{:else}
						Submit Report
					{/if}
				</button>
			</div>
		</form>
	</div>
</div>

<style>
	.report-modal-backdrop {
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

	.report-modal-card {
		background: #161616;
		border: 0.1vh solid #2e2e2c;
		border-radius: 1vh;
		width: 90vw;
		max-width: 54vh;
		box-sizing: border-box;
		padding: 2.2vh 2.4vh;
		color: #f2f2f2;
		box-shadow: 0 1vh 3vh rgba(0, 0, 0, 0.6);
		animation: scaleIn 0.25s cubic-bezier(0.16, 1, 0.3, 1);
		display: flex;
		flex-direction: column;
		gap: 1.8vh;
	}

	.report-modal-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
	}

	.badge-tag {
		display: inline-block;
		background: rgba(251, 155, 4, 0.15);
		color: #fb9b04;
		border: 0.1vh solid rgba(251, 155, 4, 0.3);
		border-radius: 0.3vh;
		font-size: 1vh;
		font-weight: 700;
		padding: 0.2vh 0.6vh;
		letter-spacing: 0.05em;
		margin-bottom: 0.4vh;
	}

	.report-title {
		margin: 0;
		font-size: 1.8vh;
		font-weight: 600;
		color: #f2f2f2;
	}

	.report-subtitle {
		margin: 0.3vh 0 0;
		font-size: 1.15vh;
		color: #8c8c8c;
		font-weight: 400;
	}

	.close-btn {
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
		transition: color 0.15s, background-color 0.15s;
	}

	.close-btn:hover {
		color: #f2f2f2;
		background: rgba(255, 255, 255, 0.08);
	}

	.error-banner {
		background: rgba(239, 68, 68, 0.15);
		border: 0.1vh solid rgba(239, 68, 68, 0.35);
		color: #fca5a5;
		padding: 0.8vh 1.2vh;
		border-radius: 0.5vh;
		font-size: 1.15vh;
		display: flex;
		align-items: center;
		gap: 0.8vh;
	}

	.error-banner svg {
		width: 1.4vh;
		height: 1.4vh;
		flex-shrink: 0;
	}

	.report-form {
		display: flex;
		flex-direction: column;
		gap: 1.5vh;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.6vh;
	}

	.label-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.form-label {
		font-size: 1.2vh;
		font-weight: 500;
		color: #e2e2e2;
	}

	.label-hint {
		font-size: 1.05vh;
		color: #737373;
	}

	.char-count {
		font-size: 1.05vh;
		color: #737373;
	}

	.char-count.limit {
		color: #ef4444;
	}

	.category-pills {
		display: flex;
		flex-wrap: wrap;
		gap: 0.6vh;
	}

	.category-pill {
		background: rgba(37, 37, 37, 0.6);
		border: 0.1vh solid #2e2e2c;
		color: #a3a3a3;
		padding: 0.6vh 1vh;
		border-radius: 0.4vh;
		font-size: 1.1vh;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s;
		font-family: inherit;
	}

	.category-pill:hover {
		background: rgba(251, 155, 4, 0.1);
		color: #fb9b04;
		border-color: rgba(251, 155, 4, 0.3);
	}

	.category-pill.selected {
		background: #fb9b04;
		color: #161616;
		border-color: #fb9b04;
		font-weight: 600;
	}

	.form-input,
	.form-textarea {
		background: rgba(30, 30, 30, 0.8);
		border: 0.1vh solid #2e2e2c;
		border-radius: 0.5vh;
		color: #f2f2f2;
		padding: 0.8vh 1.1vh;
		font-size: 1.2vh;
		font-family: inherit;
		box-sizing: border-box;
		width: 100%;
		outline: none;
		transition: border-color 0.15s, box-shadow 0.15s;
	}

	.form-input:focus,
	.form-textarea:focus {
		border-color: #fb9b04;
		box-shadow: 0 0 0 0.1vh rgba(251, 155, 4, 0.3);
	}

	.form-textarea {
		resize: none;
	}

	.report-modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 0.9vh;
		margin-top: 0.6vh;
	}

	.btn {
		padding: 0.8vh 1.6vh;
		border-radius: 0.4vh;
		font-size: 1.2vh;
		font-weight: 600;
		cursor: pointer;
		border: none;
		font-family: inherit;
		display: inline-flex;
		align-items: center;
		gap: 0.6vh;
		transition: all 0.15s;
	}

	.btn-secondary {
		background: rgba(37, 37, 37, 0.8);
		color: #a3a3a3;
		border: 0.1vh solid #2e2e2c;
	}

	.btn-secondary:hover:not(:disabled) {
		background: rgba(50, 50, 50, 0.9);
		color: #f2f2f2;
	}

	.btn-primary {
		background: #fb9b04;
		color: #161616;
	}

	.btn-primary:hover:not(:disabled) {
		background: #ffa826;
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.spinner {
		width: 1.2vh;
		height: 1.2vh;
		border: 0.2vh solid rgba(22, 22, 22, 0.3);
		border-top-color: #161616;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	@keyframes scaleIn {
		from {
			opacity: 0;
			transform: scale(0.95);
		}
		to {
			opacity: 1;
			transform: scale(1);
		}
	}
</style>
