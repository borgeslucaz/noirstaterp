-- QBCore: player_vehicles table (skip if your framework already created it)
-- QBox (qbx_core) uses its own player_vehicles schema without the garage column.
-- Only run this on QBCore servers that don't already have this table.

CREATE TABLE IF NOT EXISTS `player_vehicles` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `vehicle` VARCHAR(50) NOT NULL,
  `hash` VARCHAR(50) NOT NULL,
  `mods` LONGTEXT NOT NULL,
  `plate` VARCHAR(8) NOT NULL,
  `garage` VARCHAR(50) NOT NULL DEFAULT 'pillboxgarage',
  `fuel` INT NOT NULL DEFAULT 100,
  `engine` FLOAT NOT NULL DEFAULT 1000.0,
  `body` FLOAT NOT NULL DEFAULT 1000.0,
  `state` INT NOT NULL DEFAULT 0,
  `depotprice` INT NOT NULL DEFAULT 0,
  `drivingdistance` INT DEFAULT NULL,
  `status` TEXT DEFAULT NULL,
  INDEX (`citizenid`),
  INDEX (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dealership_loans` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `loan_id` INT NOT NULL,
  `vehicle` VARCHAR(50) NOT NULL,
  `plate` VARCHAR(8) NOT NULL,
  `financed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `repossessed` TINYINT NOT NULL DEFAULT 0,
  INDEX (`citizenid`),
  INDEX (`loan_id`),
  INDEX (`repossessed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
