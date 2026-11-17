-- ESX Report System & Staff Analytics Schema
-- Automatically injected on boot by oxmysql, but provided here for manual imports if needed.

CREATE TABLE IF NOT EXISTS `admin_reports` (
	`id` INT AUTO_INCREMENT PRIMARY KEY,
	`title` VARCHAR(128) NULL,
	`reporter_identifier` VARCHAR(64) NOT NULL,
	`reporter_name` VARCHAR(64) NOT NULL,
	`reporter_source` INT NULL,
	`target_identifier` VARCHAR(64) NULL,
	`target_name` VARCHAR(64) NULL,
	`target_source` INT NULL,
	`category` VARCHAR(32) NOT NULL DEFAULT 'player',
	`reason` TEXT NOT NULL,
	`status` VARCHAR(20) NOT NULL DEFAULT 'open',
	`claimed_by` VARCHAR(64) NULL,
	`claimed_name` VARCHAR(64) NULL,
	`resolution_notes` TEXT NULL,
	`players_snapshot` LONGTEXT NULL,
	`staff_snapshot` TEXT NULL,
	`created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	`updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

	INDEX `idx_reports_status` (`status`),
	INDEX `idx_reports_created` (`created_at`),
	INDEX `idx_reports_reporter` (`reporter_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_report_messages` (
	`id` INT AUTO_INCREMENT PRIMARY KEY,
	`report_id` INT NOT NULL,
	`sender_identifier` VARCHAR(64) NOT NULL,
	`sender_name` VARCHAR(64) NOT NULL,
	`is_staff` TINYINT(1) NOT NULL DEFAULT 0,
	`message` TEXT NOT NULL,
	`created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

	INDEX `idx_report_msg_report` (`report_id`),
	INDEX `idx_report_msg_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
