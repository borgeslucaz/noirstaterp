# noir_burnerphone

Burner phone com interface própria, simples e inspirada em celulares antigos.
O item `burner_phone` abre o menu de canais ilegais; as atividades continuam
desativadas até que seus fluxos server-side sejam integrados.

## Telefone atual

O servidor usa `sd-phone`. A integração futura é possível por meio da API de apps
de terceiros (`exports['sd-phone']:addCustomApp`) e pelos itens únicos de
telefone/SIM do próprio recurso. O burner phone atual não abre o `sd-phone`: ele
tem UI própria e mantém essa ponte desligada (`phoneIntegration.enabled = false`).

## Próximas decisões

1. Definir se cada item terá uma identidade/linha descartável única.
2. Escolher as primeiras atividades: venda de drogas, entregas, contratos ou
   mercado negro.
3. Definir consequências ao descartar/apreender o aparelho (apagamento, heat e
   rastreabilidade policial).
