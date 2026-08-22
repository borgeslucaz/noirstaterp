# noir_chat — Estado atual

> Resource 1.0.0 instalado.

## Função

noir_chat substitui o chat CFX, preserva a API esperada por FiveM/Qbox e não atribui L à visibilidade. O manifest declara provide chat, portanto dependências do chat padrão podem ser atendidas por ele. O resource original não deve rodar em paralelo.

## Controles

| Ação | Controle |
|---|---|
| Abrir | T (controle GTA 245) |
| Enviar | Enter |
| Fechar/cancelar | Esc |
| Trocar modo | Tab |
| Histórico | setas cima/baixo |
| Rolar | Page Up/Page Down |

L não é capturada, desabilitada nem remapeada.

## Configuração

Em [standalone]/noir_chat/config.lua:

- Config.ToggleChatKey = false: não registra keybind de visibilidade;
- Config.MaxMessageLength = 500: limite validado no client e server.

Se ToggleChatKey receber string não vazia, essa tecla será registrada para toggleChat.

## Fluxo

1. A NUI abre dist/ui.html.
2. O JS envia POST HTTPS para loaded usando GetParentResourceName().
3. O client dispara chat:init.
4. Comandos permitidos e temas são enviados à NUI.
5. O client controla foco e visibilidade.

Ao enviar, texto com / vira comando sem a barra; texto comum dispara _chat:messageEntered; o servidor aplica hooks, modo e validação; entrada vazia fecha; Escape cancela.

As callbacks usam HTTPS e nome dinâmico, evitando Mixed Content.

## Visibilidade

Estados persistidos em KVP:

- whenactive: aparece no uso e some após timeout;
- visible: sempre visível;
- hidden: sempre oculto.

Comandos: /toggleChat, /toggleChat visible, /toggleChat hidden e /toggleChat whenactive. Sem argumento, percorre os estados. Fade e pausa ocultam temporariamente.

## Compatibilidade

Eventos client:

~~~text
chatMessage
chat:addTemplate
chat:addMessage
chat:addSuggestion
chat:addSuggestions
chat:addMode
chat:removeMode
chat:removeSuggestion
chat:clear
__cfx_internal:serverPrint
~~~

Exports client: addMessage e addSuggestion.

Exports server: addMessage(target, message), registerMessageHook(hook) e registerMode(modeData). Também mantém say, mensagens de console, modos e hooks do chat padrão.

~~~lua
TriggerClientEvent('chat:addMessage', source, {
    color = { 255, 255, 255 },
    args = { 'NOIR', 'Mensagem do sistema' }
})
~~~

## Temas e sugestões

Ao carregar ou quando resources iniciam/param, o client lê comandos permitidos por ACE, gera sugestões (menos toggleChat), lê chat_theme/chat_theme_extra e atualiza a NUI.

## Observações

- O visual é o frontend CFX compilado/adaptado.
- Keybind antigo de chat pode permanecer no perfil local.
- Não remova L globalmente; ela pode controlar a trava do veículo.
- O aviso -gizmotranslation vem do ps-mdt.
- SetTextChatEnabled não é chamado por não ser implementado.

Para recarregar: restart noir_chat.
