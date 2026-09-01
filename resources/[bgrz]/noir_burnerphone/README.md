# noir_burnerphone

Burner phone com interface própria, simples e inspirada em celulares antigos.
O item `burner_phone` abre o menu de canais ilegais. O canal de contratos de
invasão residencial está integrado ao `noir_houserobbery`: o jogador conversa
com o contato configurado e recebe a localização pela própria conversa.

## Telefone atual

O servidor usa `sd-phone`. A integração futura é possível por meio da API de apps
de terceiros (`exports['sd-phone']:addCustomApp`) e pelos itens únicos de
telefone/SIM do próprio recurso. O burner phone atual não abre o `sd-phone`: ele
tem UI própria e mantém essa ponte desligada (`phoneIntegration.enabled = false`).

## Integração server-side

`sendContactMessage(source, message, location)` é o export usado por atividades
para responder na conversa do burner. Pedidos de invasão são encaminhados ao
export server-side do recurso de roubo; não há evento client-side que atribua
diretamente um contrato.

## Próximas decisões

1. Definir se cada item terá uma identidade/linha descartável única.
2. Integrar entregas e mercado negro.
3. Definir consequências ao descartar/apreender o aparelho (apagamento, heat e
   rastreabilidade policial).
