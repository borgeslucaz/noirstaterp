# Referência rápida — bgrz_core

> Este arquivo não define comportamento adicional; resume o resource atual.

## Resumo

bgrz_core 0.1.0 é uma camada server-side de leitura sobre qbx_core. Inicia via ensure [bgrz], depende somente do Qbox e não possui client script.

## Interface pública

~~~lua
local character, err = exports.bgrz_core:GetCharacter(source)
~~~

Retorna source/citizenId, nome, nascimento, nacionalidade, telefone, emprego, gangue, dinheiro, status, licenças e fingerprint.

Erros: invalid_source, player_not_found e invalid_player_data.

## Diagnóstico

/bgrztest funciona com BGRZConfig.Debug true. Por jogador, imprime o objeto e mostra notificação. Não funciona pelo console e não altera estado.

## Limites

Não escreve PlayerData, não gerencia identidade, não usa oxmysql, não expõe funções client e não implementa economia/empresas/reputação.

Detalhes em CORE.md; panorama em GENERAL.MD.
