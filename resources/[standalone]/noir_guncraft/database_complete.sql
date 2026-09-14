-- Noir Guncraft Database Tables
--
-- Não é preciso importar este arquivo: server/database.lua roda o mesmo DDL
-- no MySQL.ready. Ele fica aqui como referência do schema.
--
-- As tabelas do upstream se chamavam `benches` e `crafting_queue`, sem prefixo.

CREATE TABLE IF NOT EXISTS `noir_guncraft_benches` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `owner` varchar(50) NOT NULL,
    `x` float NOT NULL,
    `y` float NOT NULL,
    `z` float NOT NULL,
    `heading` float NOT NULL,
    `model` varchar(50) NOT NULL,
    `serial` varchar(50) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `serial` (`serial`),
    INDEX `owner_idx` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `noir_guncraft_queue` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `bench_id` int(11) NOT NULL,
    `item` varchar(50) NOT NULL,
    `finish_time` bigint(20) NOT NULL,
    `start_time` bigint(20) DEFAULT NULL,
    `quantity` int(11) DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `bench_id` (`bench_id`),
    KEY `finish_time_idx` (`finish_time`),
    FOREIGN KEY (`bench_id`) REFERENCES `noir_guncraft_benches`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
