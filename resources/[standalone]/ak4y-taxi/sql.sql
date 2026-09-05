CREATE TABLE `ak4y_taxi` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`identifier` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`name` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`photo` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`xp` INT(11) NULL DEFAULT NULL,
	`completedroutes` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`tasks` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
	`earnedmoney` INT(11) NULL DEFAULT NULL,
	PRIMARY KEY (`id`) USING BTREE
)
COLLATE='utf8mb4_unicode_ci'
ENGINE=InnoDB
AUTO_INCREMENT=33
;
