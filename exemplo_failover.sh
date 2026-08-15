#!/usr/bin/env bash
# Exemplo ilustrativo simplificado do monitor de failover descrito no README.
# Roda via cron a cada minuto. IPs/interfaces abaixo são exemplos genéricos,
# não refletem nenhum ambiente real.

set -euo pipefail

LINK_A_GW="203.0.113.1"     # gateway do link principal (exemplo)
LINK_B_GW="203.0.113.2"     # gateway do link backup (exemplo)
ALVO_TESTE="8.8.8.8"
STATE_FILE="/tmp/failover.last_state"
LOG_FILE="/var/log/failover.log"

log() { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG_FILE"; }

testar_link() {
  local via_gw="$1"
  ping -c 2 -W 2 -I "$via_gw" "$ALVO_TESTE" >/dev/null 2>&1
}

estado_anterior=""
[ -f "$STATE_FILE" ] && estado_anterior=$(cat "$STATE_FILE")

if testar_link "$LINK_A_GW"; then
  novo_estado="link_a"
elif testar_link "$LINK_B_GW"; then
  novo_estado="link_b"
else
  novo_estado="blackout"
fi

if [ "$novo_estado" != "$estado_anterior" ]; then
  case "$novo_estado" in
    link_a)
      ip route replace default via "$LINK_A_GW"
      log "Link principal OK — rota restaurada para link_a"
      systemctl restart vpn-site-to-site 2>/dev/null || true
      ;;
    link_b)
      ip route replace default via "$LINK_B_GW"
      log "ALERTA: link principal falhou — failover ativado para link_b"
      systemctl restart vpn-site-to-site 2>/dev/null || true
      # enviar_alerta "Failover ativado — link principal fora do ar"
      ;;
    blackout)
      log "CRÍTICO: ambos os links falharam — sem conectividade de saída"
      # enviar_alerta_critico "Blackout total de conectividade"
      ;;
  esac
  echo "$novo_estado" > "$STATE_FILE"
else
  log "Sem mudança de estado ($novo_estado) — nenhuma ação necessária"
fi
