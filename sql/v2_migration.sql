-- BC-Banking V2 migration
-- Run this AFTER the original sql.sql. Existing V1 transaction history is preserved.

CREATE TABLE IF NOT EXISTS `bc_banking_accounts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_key` VARCHAR(80) NOT NULL,
  `account_type` VARCHAR(24) NOT NULL,
  `owner_citizenid` VARCHAR(50) DEFAULT NULL,
  `job_name` VARCHAR(50) DEFAULT NULL,
  `label` VARCHAR(100) NOT NULL,
  `balance` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bc_banking_account_key` (`account_key`),
  KEY `idx_bc_banking_job` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bc_banking_account_members` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_id` BIGINT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `can_view` TINYINT(1) NOT NULL DEFAULT 1,
  `can_deposit` TINYINT(1) NOT NULL DEFAULT 0,
  `can_withdraw` TINYINT(1) NOT NULL DEFAULT 0,
  `can_manage` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bc_banking_member` (`account_id`, `citizenid`),
  CONSTRAINT `fk_bc_banking_member_account` FOREIGN KEY (`account_id`) REFERENCES `bc_banking_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bc_banking_cards` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `card_last4` CHAR(4) NOT NULL,
  `pin_salt` CHAR(32) NOT NULL,
  `pin_hash` CHAR(64) NOT NULL,
  `is_locked` TINYINT(1) NOT NULL DEFAULT 0,
  `failed_attempts` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `locked_until` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bc_banking_card_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bc_banking_v2_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor_citizenid` VARCHAR(50) NOT NULL,
  `account_key` VARCHAR(80) DEFAULT NULL,
  `action` VARCHAR(40) NOT NULL,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `details` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_bc_banking_audit_actor` (`actor_citizenid`, `id`),
  KEY `idx_bc_banking_audit_account` (`account_key`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
