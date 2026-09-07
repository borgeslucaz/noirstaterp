Locales = {}

local translations = {}

-- ============================================================
-- ENGLISH (fallback)
-- ============================================================
translations['en'] = {
    -- Interaction
    ['open_menu']                = 'PRESS E TO OPEN THE MENU',
    ['talk_to_dealer']           = 'Talk to Dealer',
    ['load_box']                 = 'E - Load Box',
    ['take_box']                 = 'E - Take Box',
    ['deliver']                  = 'E - Deliver',
    ['finish_job']               = 'E - Return Truck',
    ['take_illegal']             = 'E - Illegal Dealings',
    ['go_to_pickup']             = 'Go to the pickup point and load the goods.',
    ['box_progress']             = 'Cargo Progress',

    -- Job feedback
    ['get_trailer']              = 'Pick up the trailer at the marked location...',
    ['deliver_trailer']          = 'Deliver the trailer at the marked location...',
    ['return_veh']               = 'Return the truck to the company to close the contract...',
    ['wait_call']                = 'Stay close, we will call you if we have work...',
    ['get_ready']                = 'Get ready for transport!',
    ['job_cancelled']            = 'Delivery cancelled. The cargo will not return to the market.',
    ['job_cancelled_cargo_destroyed'] = 'Delivery failed: your cargo was destroyed.',
    ['job_cancelled_vehicle_destroyed'] = 'Delivery failed: your truck was destroyed.',
    ['job_failed_system']        = 'The delivery was closed due to a technical failure. You were not penalised.',
    ['job_failed_disconnect']    = 'Your delivery was closed because you were away for too long.',
    ['job_recovered_closed']     = 'Your previous delivery was closed after the disconnection. Wait for the next rotation.',

    -- Errors & validation
    ['cant_select_truck']        = 'You cannot use this truck on this contract!',
    ['mission_locked']           = 'Contract locked!',
    ['not_enough_points']        = 'Not enough reputation with this company!',
    ['you_charged']              = 'Damage penalty: $%s',
    ['not_enough_illegal_box']   = 'Not enough illegal boxes. REQUIRED: 10',
    ['trailer_doesnt_match']     = 'The trailer does not match!',
    ['in_vehicle']               = 'You cannot take the box from inside the vehicle!',
    ['spawn_location_full']      = 'The pickup slots are full right now!',
    ['leave_vehicle']            = 'Leave the vehicle!',
    ['stop_vehicle']             = 'Stop the vehicle to deliver!',
    ['notaccessjob']             = 'You do not have access to this job!',
    ['no_active_job']            = 'You do not have an active delivery.',
    ['already_active_job']       = 'You already have an active delivery.',
    ['must_have_job']            = 'You need an active delivery to deal with me.',
    ['already_illegal']          = 'You are already doing an illegal pickup or waiting for a call.',
    ['too_far']                  = 'You wandered too far, the deal is off.',
    ['edit_hud_hint']            = 'HUD Edit Mode: drag to move. Press ESC or /truckhud again to save.',
    ['illegal_validation_failed'] = 'Illegal cargo verification failed.',

    -- Market / contract errors (server → player)
    ['err_offer_taken']          = 'This cargo was just started by another driver.',
    ['err_offer_expired']        = 'This offer has expired. Check the new rotation.',
    ['err_offer_not_found']      = 'Offer not found.',
    ['err_rotation_used']        = 'You already started a contract in this rotation. Wait for the next one.',
    ['err_level_band']           = 'This cargo is reserved for drivers of level %s to %s.',
    ['err_level_band_min']       = 'This cargo requires level %s or higher.',
    ['err_mission_level']        = 'This contract requires level %s.',
    ['err_reputation']           = 'This contract requires %s reputation with %s.',
    ['err_route_reputation']     = 'This route requires %s reputation with %s.',
    ['err_truck_level']          = 'This truck requires level %s.',
    ['err_truck_not_allowed']    = 'This truck is not allowed on this route.',
    ['err_too_far_central']      = 'Go to the freight center to start a contract.',
    ['err_active_session']       = 'Finish or cancel your current delivery first.',
    ['err_db']                   = 'The freight center is unavailable right now. Try again in a moment.',
    ['err_spawn_full']           = 'The pickup slots are full right now!',
    ['err_invalid']              = 'Invalid request.',
    ['err_timeout']              = 'The freight center did not respond. Board refreshed.',
    ['err_finish_too_fast']      = 'Delivery too fast to be validated. Return the truck again in about %s min.',
    ['err_finish_phase']         = 'Pickup or delivery was not validated. Complete the previous steps first.',
    ['err_finish_area']          = 'Park the truck in the company return spot.',
    ['err_finish_vehicle']       = 'Return the truck provided for this contract.',

    -- Locks (offer card reasons)
    ['lock_level_band']          = 'Level %s–%s only',
    ['lock_level_band_min']      = 'Level %s+',
    ['lock_mission_level']       = 'Level %s required',
    ['lock_reputation']          = '%s reputation required',
    ['lock_route_reputation']    = '%s route reputation required',
    ['lock_used_rotation']       = '1 contract per rotation',
    ['lock_active_session']      = 'Delivery in progress',
    ['lock_no_truck']            = 'No compatible truck unlocked',

    -- UI labels
    ['transportation_stage']     = 'Transport Stage',
    ['trailer_quality']          = 'Cargo Integrity',
    ['truck_fuel']               = 'Truck Fuel',
    ['detach_trailer']           = 'Detach Trailer',
    ['mark_location']            = 'Mark Location',
    ['nts_main']                 = 'NTS MAIN',
    ['companies']                = 'COMPANIES',
    ['leaderboard']              = 'LEADERBOARD',
    ['profile']                  = 'PROFILE',
    ['global_market']            = 'GLOBAL MARKET',
    ['new_cargo_in']             = 'New cargo in',
    ['rotation']                 = 'Rotation',
    ['one_per_rotation']         = '1 CONTRACT PER ROTATION',
    ['board_empty_title']        = 'ALL CARGO IN THIS ROTATION HAS BEEN DISTRIBUTED',
    ['board_empty_sub']          = 'New opportunities in',
    ['board_loading']            = 'Loading the market...',
    ['tier_low']                 = 'Low',
    ['tier_medium']              = 'Medium',
    ['tier_high']                = 'High',
    ['status_available']         = 'AVAILABLE',
    ['status_locked']            = 'LOCKED',
    ['status_starting']          = 'STARTING...',
    ['status_in_progress']       = 'IN PROGRESS',
    ['status_completed']         = 'COMPLETED',
    ['status_failed']            = 'FAILED',
    ['status_expired']           = 'EXPIRED',
    ['status_unavailable']       = 'UNAVAILABLE',
    ['for_beginners']            = 'For beginners',
    ['estimated']                = 'Est.',
    ['minutes_short']            = 'min',
    ['market_bonus']             = 'Market bonus',
    ['payment']                  = 'Payment',
    ['xp']                       = 'XP',
    ['reputation']               = 'Reputation',
    ['requirements']             = 'Requirements',
    ['route']                    = 'Route',
    ['routes']                   = 'routes',
    ['company']                  = 'Company',
    ['cargo']                    = 'Cargo',
    ['eligibility']              = 'Eligibility',
    ['eligible']                 = 'Eligible',
    ['not_eligible']             = 'Not eligible',
    ['reward_summary']           = 'Reward summary',
    ['select_offer']             = 'Select an offer',
    ['select_truck']             = 'Select a Truck',
    ['select_your_truck']        = 'Select your truck',
    ['select_mission_and_route'] = 'Select an offer',
    ['start_the_job']            = 'Start the contract',
    ['stop_job']                 = 'CANCEL DELIVERY',
    ['start_job']                = 'START CONTRACT',
    ['starting_job']             = 'STARTING...',
    ['requirement_not_met']      = 'REQUIREMENT NOT MET',
    ['cancel_job']               = 'Cancel Delivery',
    ['daily_missions']           = 'Daily Missions',
    ['hour']                     = 'h',
    ['completed']                = 'Completed',
    ['not_completed']            = 'Not Completed',
    ['claimed']                  = 'Claimed',
    ['unlocked']                 = 'AVAILABLE',
    ['locked']                   = 'LOCKED',
    ['trust_point']              = 'Reputation',
    ['company_reputation']       = 'Company reputation',
    ['next_tier']                = 'Next tier',
    ['max_tier']                 = 'Maximum tier',
    ['rep_unknown']              = 'Unknown',
    ['rep_partner']              = 'Partner',
    ['rep_trusted']              = 'Trusted',
    ['rep_specialist']           = 'Specialist',
    ['rep_elite']                = 'Elite',
    ['no_route_selected']        = 'No offer selected',
    ['available_cargo']          = 'Available contracts',
    ['cargo_board']              = 'Cargo board',
    ['route_options']            = 'Contract route',
    ['company_fleet']            = 'Company fleet',
    ['choose_equipment']         = 'Choose the equipment',
    ['driver']                   = 'Driver',
    ['level']                    = 'Level',
    ['level_short']              = 'Lv.',
    ['freight_ops']              = 'Freight operations',

    -- Delivery report
    ['report_title']             = 'DELIVERY COMPLETED',
    ['report_grade']             = 'GRADE',
    ['report_base']              = 'Base payment',
    ['report_market']            = 'Global Market bonus',
    ['report_quality']           = 'Quality bonus',
    ['report_quality_penalty']   = 'Quality adjustment',
    ['report_damage']            = 'Damage penalty',
    ['report_illegal']           = 'Illegal cargo bonus',
    ['report_total']             = 'Total',
    ['report_xp']                = 'XP received',
    ['report_reputation']        = 'Reputation',
    ['report_score']             = 'Score',
    ['report_close']             = 'CLOSE',
    ['score_integrity']          = 'Integrity',
    ['score_punctuality']        = 'Punctuality',
    ['score_steps']              = 'Steps',
    ['score_handover']           = 'Handover',

    -- Profile / stats
    ['completed_jobs']           = 'Completed Deliveries',
    ['total_missions_completed'] = 'Global contracts completed with all companies.',
    ['total_earnings']           = 'Total Earnings',
    ['total_earnings_desc']      = 'Total money earned on validated deliveries.',
    ['current_level']            = 'Current Level',
    ['xp_to_next']               = 'XP to next level',
    ['latest_works']             = 'Latest Deliveries',
    ['recent_deliveries']        = 'Recent deliveries',
    ['earned']                   = 'Earned',
    ['no_history']               = 'No deliveries recorded yet.',
    ['result_completed']         = 'Completed',
    ['result_failed']            = 'Failed',
    ['result_failed_system']     = 'Closed (technical)',
    ['base']                     = 'Base',
    ['bonus']                    = 'Bonus',
    ['total']                    = 'Total',

    -- Leaderboard
    ['leaderboard_empty']        = 'No drivers ranked yet. Complete a global contract to appear here.',
    ['your_position']            = 'Your position',
    ['metric_level']             = 'Level',
    ['metric_global']            = 'Global deliveries',
    ['deliveries']               = 'deliveries',

    -- Daily missions (keys used by Config.DailyMissions)
    ['daily_complete_global_header']   = 'Win a cargo',
    ['daily_complete_global_label']    = 'Complete one global contract.',
    ['daily_grade_header']             = 'Excellence',
    ['daily_grade_label']              = 'Finish a delivery with grade A or S.',
    ['daily_two_companies_header']     = 'Diversify',
    ['daily_two_companies_label']      = 'Deliver for two different companies.',
    ['daily_medium_no_damage_header']  = 'Clean run',
    ['daily_medium_no_damage_label']   = 'Complete a medium delivery with at most 10% damage.',
    ['daily_before_expiry_header']     = 'On time',
    ['daily_before_expiry_label']      = 'Complete a contract before its rotation expires.',
}

-- ============================================================
-- PORTUGUÊS (Noir State)
-- ============================================================
translations['pt-BR'] = {
    -- Interação
    ['open_menu']                = 'PRESSIONE E PARA ABRIR O MENU',
    ['talk_to_dealer']           = 'Falar com o contato',
    ['load_box']                 = 'E - Carregar Caixa',
    ['take_box']                 = 'E - Pegar Caixa',
    ['deliver']                  = 'E - Entregar',
    ['finish_job']               = 'E - Devolver Caminhão',
    ['take_illegal']             = 'E - Negócios Ilegais',
    ['go_to_pickup']             = 'Vá até o ponto de coleta e carregue as mercadorias.',
    ['box_progress']             = 'Progresso da Carga',

    -- Feedback do trabalho
    ['get_trailer']              = 'Pegue a carreta no local marcado no seu mapa...',
    ['deliver_trailer']          = 'Entregue a carreta no local marcado no seu mapa...',
    ['return_veh']               = 'Devolva o caminhão à empresa para fechar o contrato...',
    ['wait_call']                = 'Fique por perto, ligamos se tivermos trabalho...',
    ['get_ready']                = 'Prepare-se para o transporte!',
    ['job_cancelled']            = 'Entrega cancelada. A carga não volta ao mercado.',
    ['job_cancelled_cargo_destroyed'] = 'Entrega fracassada: sua carga foi destruída.',
    ['job_cancelled_vehicle_destroyed'] = 'Entrega fracassada: seu caminhão foi destruído.',
    ['job_failed_system']        = 'A entrega foi encerrada por uma falha técnica. Você não foi penalizado.',
    ['job_failed_disconnect']    = 'Sua entrega foi encerrada porque você ficou ausente por muito tempo.',
    ['job_recovered_closed']     = 'Sua entrega anterior foi encerrada após a desconexão. Aguarde a próxima rotação.',

    -- Erros e validação
    ['cant_select_truck']        = 'Você não pode usar este caminhão neste contrato!',
    ['mission_locked']           = 'Contrato bloqueado!',
    ['not_enough_points']        = 'Reputação insuficiente com esta empresa!',
    ['you_charged']              = 'Penalidade por danos: $%s',
    ['not_enough_illegal_box']   = 'Você não tem caixas ilegais suficientes. NECESSÁRIO: 10',
    ['trailer_doesnt_match']     = 'A carreta não corresponde!',
    ['in_vehicle']               = 'Você não pode pegar a caixa dentro do veículo!',
    ['spawn_location_full']      = 'Os pontos de coleta estão ocupados agora!',
    ['leave_vehicle']            = 'Saia do veículo!',
    ['stop_vehicle']             = 'Pare o veículo para entregar!',
    ['notaccessjob']             = 'Você não tem acesso a este trabalho!',
    ['no_active_job']            = 'Você não tem uma entrega ativa.',
    ['already_active_job']       = 'Você já tem uma entrega ativa.',
    ['must_have_job']            = 'Você precisa de uma entrega ativa para negociar comigo.',
    ['already_illegal']          = 'Você já está fazendo uma coleta ilegal ou aguardando uma chamada.',
    ['too_far']                  = 'Você se afastou demais, o negócio foi cancelado.',
    ['edit_hud_hint']            = 'Modo de edição do HUD: arraste para mover. ESC ou /truckhud novamente para salvar.',
    ['illegal_validation_failed'] = 'Falha na verificação da carga ilegal.',

    -- Erros do mercado / contrato (servidor → jogador)
    ['err_offer_taken']          = 'Esta carga acabou de ser iniciada por outro motorista.',
    ['err_offer_expired']        = 'Esta oferta expirou. Confira a nova rotação.',
    ['err_offer_not_found']      = 'Oferta não encontrada.',
    ['err_rotation_used']        = 'Você já iniciou um contrato nesta rotação. Aguarde a próxima.',
    ['err_level_band']           = 'Esta carga é destinada a motoristas de nível %s a %s.',
    ['err_level_band_min']       = 'Esta carga exige nível %s ou superior.',
    ['err_mission_level']        = 'Este contrato exige nível %s.',
    ['err_reputation']           = 'Este contrato exige %s de reputação com %s.',
    ['err_route_reputation']     = 'Esta rota exige %s de reputação com %s.',
    ['err_truck_level']          = 'Este caminhão exige nível %s.',
    ['err_truck_not_allowed']    = 'Este caminhão não é permitido nesta rota.',
    ['err_too_far_central']      = 'Vá até a central de fretes para iniciar um contrato.',
    ['err_active_session']       = 'Conclua ou cancele sua entrega atual primeiro.',
    ['err_db']                   = 'A central de fretes está indisponível no momento. Tente novamente em instantes.',
    ['err_spawn_full']           = 'Os pontos de coleta estão ocupados agora!',
    ['err_invalid']              = 'Pedido inválido.',
    ['err_timeout']              = 'A central não respondeu. Quadro atualizado.',
    ['err_finish_too_fast']      = 'Entrega rápida demais para ser validada. Devolva o caminhão novamente em cerca de %s min.',
    ['err_finish_phase']         = 'Coleta ou entrega não foi validada. Conclua as etapas anteriores primeiro.',
    ['err_finish_area']          = 'Estacione o caminhão na vaga de devolução da empresa.',
    ['err_finish_vehicle']       = 'Devolva o caminhão fornecido para este contrato.',

    -- Bloqueios (motivos nos cards)
    ['lock_level_band']          = 'Somente nível %s–%s',
    ['lock_level_band_min']      = 'Nível %s+',
    ['lock_mission_level']       = 'Nível %s necessário',
    ['lock_reputation']          = '%s de reputação necessária',
    ['lock_route_reputation']    = '%s de reputação na rota',
    ['lock_used_rotation']       = '1 contrato por rotação',
    ['lock_active_session']      = 'Entrega em andamento',
    ['lock_no_truck']            = 'Nenhum caminhão compatível liberado',

    -- Rótulos da UI
    ['transportation_stage']     = 'Etapa de Transporte',
    ['trailer_quality']          = 'Integridade da Carga',
    ['truck_fuel']               = 'Combustível do Caminhão',
    ['detach_trailer']           = 'Soltar Carreta',
    ['mark_location']            = 'Marcar Local',
    ['nts_main']                 = 'NTS PRINCIPAL',
    ['companies']                = 'EMPRESAS',
    ['leaderboard']              = 'CLASSIFICAÇÃO',
    ['profile']                  = 'PERFIL',
    ['global_market']            = 'MERCADO GLOBAL',
    ['new_cargo_in']             = 'Novas cargas em',
    ['rotation']                 = 'Rotação',
    ['one_per_rotation']         = '1 CONTRATO POR ROTAÇÃO',
    ['board_empty_title']        = 'TODAS AS CARGAS DESTA ROTAÇÃO FORAM DISTRIBUÍDAS',
    ['board_empty_sub']          = 'Novas oportunidades em',
    ['board_loading']            = 'Carregando o mercado...',
    ['tier_low']                 = 'Baixo',
    ['tier_medium']              = 'Médio',
    ['tier_high']                = 'Alto',
    ['status_available']         = 'DISPONÍVEL',
    ['status_locked']            = 'BLOQUEADO',
    ['status_starting']          = 'INICIANDO...',
    ['status_in_progress']       = 'EM ANDAMENTO',
    ['status_completed']         = 'CONCLUÍDO',
    ['status_failed']            = 'FRACASSADO',
    ['status_expired']           = 'EXPIRADO',
    ['status_unavailable']       = 'INDISPONÍVEL',
    ['for_beginners']            = 'Para iniciantes',
    ['estimated']                = 'Est.',
    ['minutes_short']            = 'min',
    ['market_bonus']             = 'Bônus de mercado',
    ['payment']                  = 'Pagamento',
    ['xp']                       = 'XP',
    ['reputation']               = 'Reputação',
    ['requirements']             = 'Requisitos',
    ['route']                    = 'Rota',
    ['routes']                   = 'rotas',
    ['company']                  = 'Empresa',
    ['cargo']                    = 'Carga',
    ['eligibility']              = 'Elegibilidade',
    ['eligible']                 = 'Elegível',
    ['not_eligible']             = 'Não elegível',
    ['reward_summary']           = 'Resumo da recompensa',
    ['select_offer']             = 'Selecione uma oferta',
    ['select_truck']             = 'Selecione um Caminhão',
    ['select_your_truck']        = 'Selecione seu caminhão',
    ['select_mission_and_route'] = 'Selecione uma oferta',
    ['start_the_job']            = 'Inicie o contrato',
    ['stop_job']                 = 'CANCELAR ENTREGA',
    ['start_job']                = 'INICIAR CONTRATO',
    ['starting_job']             = 'INICIANDO...',
    ['requirement_not_met']      = 'REQUISITO NÃO ATENDIDO',
    ['cancel_job']               = 'Cancelar Entrega',
    ['daily_missions']           = 'Missões Diárias',
    ['hour']                     = 'h',
    ['completed']                = 'Concluída',
    ['not_completed']            = 'Não Concluída',
    ['claimed']                  = 'Recebida',
    ['unlocked']                 = 'DISPONÍVEL',
    ['locked']                   = 'BLOQUEADA',
    ['trust_point']              = 'Reputação',
    ['company_reputation']       = 'Reputação da empresa',
    ['next_tier']                = 'Próximo patamar',
    ['max_tier']                 = 'Patamar máximo',
    ['rep_unknown']              = 'Desconhecido',
    ['rep_partner']              = 'Parceiro',
    ['rep_trusted']              = 'Confiável',
    ['rep_specialist']           = 'Especialista',
    ['rep_elite']                = 'Elite',
    ['no_route_selected']        = 'Nenhuma oferta selecionada',
    ['available_cargo']          = 'Contratos disponíveis',
    ['cargo_board']              = 'Quadro de cargas',
    ['route_options']            = 'Rota do contrato',
    ['company_fleet']            = 'Frota da empresa',
    ['choose_equipment']         = 'Escolha o equipamento',
    ['driver']                   = 'Motorista',
    ['level']                    = 'Nível',
    ['level_short']              = 'Nv.',
    ['freight_ops']              = 'Operações de frete',

    -- Relatório de entrega
    ['report_title']             = 'ENTREGA CONCLUÍDA',
    ['report_grade']             = 'NOTA',
    ['report_base']              = 'Pagamento base',
    ['report_market']            = 'Bônus do Mercado Global',
    ['report_quality']           = 'Bônus de qualidade',
    ['report_quality_penalty']   = 'Ajuste de qualidade',
    ['report_damage']            = 'Penalidade por danos',
    ['report_illegal']           = 'Bônus de carga ilegal',
    ['report_total']             = 'Total',
    ['report_xp']                = 'XP recebido',
    ['report_reputation']        = 'Reputação',
    ['report_score']             = 'Pontuação',
    ['report_close']             = 'FECHAR',
    ['score_integrity']          = 'Integridade',
    ['score_punctuality']        = 'Pontualidade',
    ['score_steps']              = 'Etapas',
    ['score_handover']           = 'Devolução',

    -- Perfil / estatísticas
    ['completed_jobs']           = 'Entregas Concluídas',
    ['total_missions_completed'] = 'Contratos globais concluídos com todas as empresas.',
    ['total_earnings']           = 'Ganhos Totais',
    ['total_earnings_desc']      = 'Total de dinheiro ganho em entregas validadas.',
    ['current_level']            = 'Nível Atual',
    ['xp_to_next']               = 'XP para o próximo nível',
    ['latest_works']             = 'Últimas Entregas',
    ['recent_deliveries']        = 'Entregas recentes',
    ['earned']                   = 'Ganho',
    ['no_history']               = 'Nenhuma entrega registrada ainda.',
    ['result_completed']         = 'Concluída',
    ['result_failed']            = 'Fracassada',
    ['result_failed_system']     = 'Encerrada (técnica)',
    ['base']                     = 'Base',
    ['bonus']                    = 'Bônus',
    ['total']                    = 'Total',

    -- Ranking
    ['leaderboard_empty']        = 'Nenhum motorista classificado ainda. Conclua um contrato global para aparecer aqui.',
    ['your_position']            = 'Sua posição',
    ['metric_level']             = 'Nível',
    ['metric_global']            = 'Entregas globais',
    ['deliveries']               = 'entregas',

    -- Missões diárias (chaves usadas por Config.DailyMissions)
    ['daily_complete_global_header']   = 'Conquiste uma carga',
    ['daily_complete_global_label']    = 'Conclua um contrato global.',
    ['daily_grade_header']             = 'Excelência',
    ['daily_grade_label']              = 'Finalize uma entrega com nota A ou S.',
    ['daily_two_companies_header']     = 'Diversifique',
    ['daily_two_companies_label']      = 'Entregue para duas empresas diferentes.',
    ['daily_medium_no_damage_header']  = 'Corrida limpa',
    ['daily_medium_no_damage_label']   = 'Conclua uma entrega média com no máximo 10% de dano.',
    ['daily_before_expiry_header']     = 'No prazo',
    ['daily_before_expiry_label']      = 'Conclua um contrato antes da rotação expirar.',
}

local currentLocale = (Config and Config.Locale) or 'pt-BR'
if not translations[currentLocale] then currentLocale = 'en' end

--- Returns the localised string for the given key, optionally formatted.
--- Falls back to English, then to the raw key if not found.
--- @param key string
--- @param ... any Format arguments (optional)
--- @return string
function Locales.Get(key, ...)
    local str = translations[currentLocale] and translations[currentLocale][key]
    if not str then
        str = translations['en'] and translations['en'][key]
    end
    if not str then
        return key
    end
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

--- Sets the active locale.
--- @param locale string ISO locale code, e.g. 'en', 'pt-BR'
function Locales.SetLocale(locale)
    if translations[locale] then
        currentLocale = locale
        Config.Language = Locales.Flatten()
    end
end

--- Registers a custom locale's translation table.
--- @param locale string
--- @param strings table Key-value translation map
function Locales.AddLocale(locale, strings)
    translations[locale] = strings
end

--- Builds a flat map (active locale over English fallback) for the NUI.
--- @return table
function Locales.Flatten()
    local out = {}
    for k, v in pairs(translations['en'] or {}) do out[k] = v end
    for k, v in pairs(translations[currentLocale] or {}) do out[k] = v end
    return out
end

-- Shorthand alias used throughout the codebase.
L = Locales.Get

Config = Config or {}
Config.Language = Locales.Flatten()
