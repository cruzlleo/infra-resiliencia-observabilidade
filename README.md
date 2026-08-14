# Infraestrutura Resiliente e Observabilidade Própria — Case Study

> Case study técnico. Ambiente e dados anonimizados/generalizados por confidencialidade — o foco é a engenharia aplicada, não detalhes de nenhuma organização específica.

## Contexto

Ambiente corporativo com um servidor legado (fora de suporte oficial do fabricante) atuando, ao mesmo tempo, como único provedor de DHCP, DNS e autenticação de VPN da rede. Um único ponto de falha sustentando três serviços críticos simultaneamente.

## Desafio

- Eliminar a dependência sem gerar downtime nem exigir troca abrupta do servidor.
- Migrar autenticação de VPN sem perder resiliência a falhas do serviço de autenticação central.
- Ganhar visibilidade proativa da infraestrutura, sem depender de ferramenta paga de terceiros para monitoramento.
- Resolver gargalos de storage identificados via alertas de performance.

## Abordagem — Eliminação de ponto único de falha

**Padrão adotado em toda a migração:** instalar o substituto, rodar em paralelo, validar formalmente que o ambiente funciona com o serviço legado desligado, só então desativar o legado.

1. **DHCP** migrado para novo host, com reservas por MAC preservadas e range revisado.
2. **DNS** promovido gradualmente: começou como forwarder simples, depois assumiu papel de servidor autoritativo das zonas internas — evitando um "big bang" de corte total.
3. **Autenticação de VPN** passou a usar cache local com expiração curta (poucas horas), permitindo continuidade mesmo em caso de indisponibilidade momentânea do serviço de autenticação central — com verificação periódica automática para revogar acessos de contas desabilitadas/removidas.
4. **Teste de corte formal**: serviço legado desligado propositalmente em ambiente controlado para confirmar que internet, DNS e VPN continuavam operacionais antes do desligamento definitivo.

## Abordagem — Observabilidade própria

Em vez de depender de uma única ferramenta comercial, foi montada uma stack combinando:

- **Métricas de infraestrutura** via ferramenta de monitoramento já existente no ambiente, com thresholds ajustados para reduzir ruído.
- **Métricas de negócio/uso** (ex: sessões ativas de VPN) coletadas por processo próprio e armazenadas em banco relacional dedicado, visualizadas em dashboards customizados — permitindo perguntas que a ferramenta de monitoramento genérica não respondia (picos por horário, por grupo de usuário, etc.).
- **Alertas** entregues via canal de mensageria já usado pela equipe, evitando fadiga de alerta por email.

## Abordagem — Storage e FinOps

Alertas de latência de disco levaram a uma investigação que identificou volumes de máquinas virtuais obsoletas — desligadas ou substituídas, mas nunca removidas — ocupando espaço significativo de um volume compartilhado. A limpeza (após confirmação de que os volumes não estavam mais em uso):

- Liberou múltiplos terabytes de espaço.
- Zerou a latência de I/O reportada pelos alertas imediatamente.
- Evitou um custo de expansão de storage que estava sendo cogitado antes da causa raiz ser identificada — economia direta ao invés de investimento em capacidade adicional.

## Abordagem — Continuidade de conectividade (failover automático)

O gateway de borda dependia de um único link de internet — qualquer instabilidade da operadora tirava a empresa inteira do ar. Solução: um segundo link de operadora diferente, com um script próprio monitorando ambos:

- Verificação de saúde de cada link a cada minuto (via cron, não um daemon separado — simplicidade deliberada para um componente crítico).
- Troca automática de rota default para o link backup ao detectar falha, com reversão automática assim que o link principal volta.
- Reinício automático de um túnel VPN site-to-site dependente do link ativo, para não deixar a rota da VPN presa no link antigo depois de uma troca.
- Alertas (mensageria + e-mail) e métrica reportada à ferramenta de monitoramento a cada mudança de estado — com deduplicação para não alertar repetidamente enquanto o estado não muda.

Resultado: instabilidade de um dos links deixou de significar "empresa sem internet" — a troca acontece sozinha, tipicamente em menos de um minuto, sem intervenção manual.

## O que eu tiraria disso pra próxima vez

- Observabilidade de negócio (não só infraestrutura) paga o investimento rápido: métricas customizadas revelaram padrões que uma ferramenta genérica de monitoramento não capturava.
- Antes de pedir mais recursos (storage, capacidade), vale investigar causa raiz — muita "necessidade de upgrade" é, na prática, débito acumulado sem limpeza.
- Migração de ponto único de falha é sempre mais segura com uma janela de teste formal de corte, não só "torcer pra funcionar".

---

**Stack:** Grafana · PostgreSQL · isc-dhcp-server · BIND9 · OpenVPN · Docker · Bash/cron
