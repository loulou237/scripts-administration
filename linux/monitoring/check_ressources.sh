
#!/usr/bin/env bash

# ==================================================
# Script : check_ressources.sh
# Objectif : superviser les ressources d'un serveur
# Compatibilite : Debian, Ubuntu, Rocky Linux
# ==================================================

set -u

# Seuils d'alerte configurables
DISK_THRESHOLD=80
RAM_THRESHOLD=80
LOAD_THRESHOLD=2.0

# Journal des controles
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
LOG_FILE="$LOG_DIR/ressources.log"

# Creer le dossier de logs si necessaire
mkdir -p "$LOG_DIR" || {
    echo "ERREUR : impossible de creer $LOG_DIR" >&2
    exit 1
}

# Fonction de journalisation
log() {
    printf '%s | %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$1" \
        | tee -a "$LOG_FILE"
}

log "===== DEBUT DU CONTROLE ====="

# 1. Informations generales
HOSTNAME_VALUE="$(hostname)"
log "Serveur : $HOSTNAME_VALUE"

# 2. Controle de l'espace disque de /
DISK_USED="$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"

if [[ "$DISK_USED" =~ ^[0-9]+$ ]]; then
    log "Disque / : ${DISK_USED}% utilise"

    if (( DISK_USED >= DISK_THRESHOLD )); then
        log "ALERTE : utilisation disque superieure ou egale a ${DISK_THRESHOLD}%"
    fi
else
    log "ERREUR : impossible de lire l'utilisation du disque"
fi

# 3. Controle de la RAM
RAM_USED="$(free | awk '/Mem:/ {
    if ($2 > 0) printf "%.0f", (($2 - $7) / $2) * 100
}')"

if [[ "$RAM_USED" =~ ^[0-9]+$ ]]; then
    log "RAM utilisee (estimation) : ${RAM_USED}%"

    if (( RAM_USED >= RAM_THRESHOLD )); then
        log "ALERTE : utilisation RAM superieure ou egale a ${RAM_THRESHOLD}%"
    fi
else
    log "ERREUR : impossible de lire l'utilisation de la RAM"
fi

# 4. Controle de la charge systeme
LOAD_VALUE="$(awk '{print $1}' /proc/loadavg)"
CPU_COUNT="$(nproc)"

log "Charge moyenne sur 1 minute : $LOAD_VALUE"
log "Nombre de CPU logiques : $CPU_COUNT"

# Comparer la charge au nombre de CPU, sans outil externe
if awk -v load="$LOAD_VALUE" -v cpus="$CPU_COUNT" \
    -v threshold="$LOAD_THRESHOLD" \
    'BEGIN { exit !(load >= cpus * threshold) }'
then
    log "ALERTE : charge systeme elevee par rapport au nombre de CPU"
fi

log "===== FIN DU CONTROLE ====="
