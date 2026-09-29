Database = {}

-- As tabelas do upstream se chamavam `benches` e `crafting_queue`, sem prefixo
-- nenhum, esperando ser as únicas do banco a usar esses nomes.
local BENCHES = 'noir_guncraft_benches'
local QUEUE = 'noir_guncraft_queue'

Database.BENCHES = BENCHES
Database.QUEUE = QUEUE

local function tableExists(name)
    return (MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
        { name }) or 0) > 0
end

CreateThread(function()
    MySQL.ready(function()
        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS `%s` (
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
        ]]):format(BENCHES))

        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS `%s` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `bench_id` int(11) NOT NULL,
                `item` varchar(50) NOT NULL,
                `finish_time` bigint(20) NOT NULL,
                `start_time` bigint(20) DEFAULT NULL,
                `quantity` int(11) DEFAULT 1,
                PRIMARY KEY (`id`),
                KEY `bench_id` (`bench_id`),
                KEY `finish_time_idx` (`finish_time`),
                FOREIGN KEY (`bench_id`) REFERENCES `%s`(`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]):format(QUEUE, BENCHES))

        -- Não renomeia sozinho: `benches` é genérico o bastante para pertencer a
        -- outro recurso, e um RENAME cego quebraria aquele script.
        if tableExists('benches') and tableExists('crafting_queue') then
            print(('[noir_guncraft] Tabelas antigas do upstream encontradas. Para migrar os dados:\n' ..
                '  INSERT INTO `%s` SELECT * FROM `benches`;\n' ..
                '  INSERT INTO `%s` (id, bench_id, item, finish_time, start_time, quantity)\n' ..
                '    SELECT id, bench_id, item, finish_time, start_time, quantity FROM `crafting_queue`;')
                :format(BENCHES, QUEUE))
        end

        if Config.Debug then
            print('[noir_guncraft] Database tables verified')
        end
    end)
end)
