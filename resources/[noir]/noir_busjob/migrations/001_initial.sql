CREATE TABLE IF NOT EXISTS busjob_driver_profiles (
    citizenid VARCHAR(50) NOT NULL,
    last_known_name VARCHAR(100) NULL,
    level INT NOT NULL DEFAULT 1,
    xp_total INT NOT NULL DEFAULT 0,
    routes_completed INT NOT NULL DEFAULT 0,
    stops_completed INT NOT NULL DEFAULT 0,
    passengers_transported INT NOT NULL DEFAULT 0,
    perfect_stops INT NOT NULL DEFAULT 0,
    total_earned BIGINT NOT NULL DEFAULT 0,
    distance_meters BIGINT NOT NULL DEFAULT 0,
    score_sum DECIMAL(14,2) NOT NULL DEFAULT 0,
    best_score DECIMAL(5,2) NOT NULL DEFAULT 0,
    last_route_id VARCHAR(50) NULL,
    last_route_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (citizenid),
    INDEX idx_busjob_level_xp (level, xp_total), INDEX idx_busjob_xp (xp_total), INDEX idx_busjob_routes (routes_completed)
);
CREATE TABLE IF NOT EXISTS busjob_route_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, citizenid VARCHAR(50) NOT NULL, route_id VARCHAR(50) NOT NULL,
    vehicle_model VARCHAR(50) NOT NULL, started_at DATETIME NOT NULL, completed_at DATETIME NOT NULL, duration_seconds INT NOT NULL,
    stops_completed INT NOT NULL, passengers_transported INT NOT NULL, stop_score DECIMAL(5,2) NOT NULL, safety_score DECIMAL(5,2) NOT NULL,
    punctuality_score DECIMAL(5,2) NOT NULL, service_score DECIMAL(5,2) NOT NULL, final_score DECIMAL(5,2) NOT NULL,
    payout INT NOT NULL, xp_earned INT NOT NULL, PRIMARY KEY (id),
    INDEX idx_bus_history_driver (citizenid, completed_at), INDEX idx_bus_history_route (route_id, completed_at)
);
