#!/bin/bash
# ============================================
# Pterodactyl Full Backup Script
# Chạy trên máy Panel + Wings (hoặc riêng lẻ)
# ============================================
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="/root/ptero-backups/$DATE"
mkdir -p "$BACKUP_DIR"
echo "🚀 Bắt đầu backup lúc $DATE"

# ─────────────────────────────────────────
# 1. Backup file .env (Panel)
# ─────────────────────────────────────────
if [ -f /var/www/pterodactyl/.env ]; then
    cp /var/www/pterodactyl/.env "$BACKUP_DIR/panel.env"
    echo "✅ Đã backup .env"
fi

# ─────────────────────────────────────────
# 2. Backup Wings config
# ─────────────────────────────────────────
if [ -f /etc/pterodactyl/config.yml ]; then
    cp /etc/pterodactyl/config.yml "$BACKUP_DIR/wings-config.yml"
    echo "✅ Đã backup Wings config"
fi

# ─────────────────────────────────────────
# 3. Backup Database (MySQL)
# ─────────────────────────────────────────
DB_HOST=$(grep DB_HOST /var/www/pterodactyl/.env | cut -d '=' -f2)
DB_USER=$(grep DB_USERNAME /var/www/pterodactyl/.env | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD /var/www/pterodactyl/.env | cut -d '=' -f2)
DB_NAME=$(grep DB_DATABASE /var/www/pterodactyl/.env | cut -d '=' -f2)
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_DIR/database.sql"
echo "✅ Đã backup Database"

# ─────────────────────────────────────────
# 4. Backup storage/ của Panel
# ─────────────────────────────────────────
if [ -d /var/www/pterodactyl/storage ]; then
    tar -czf "$BACKUP_DIR/panel-storage.tar.gz" /var/www/pterodactyl/storage/
    echo "✅ Đã backup Panel storage"
fi

# ─────────────────────────────────────────
# 5. Backup volumes (data game servers) — TÙY CHỌN, có thể rất nặng
# ─────────────────────────────────────────
# Bỏ comment nếu muốn backup data game
# tar -czf "$BACKUP_DIR/volumes.tar.gz" /var/lib/pterodactyl/volumes/
# echo "✅ Đã backup Volumes"

# ─────────────────────────────────────────
# 6. Copy backup từ Pterodactyl (tab Backups) sang thư mục riêng
# ─────────────────────────────────────────
PTERO_BACKUP_SRC="/var/lib/pterodactyl/backups"
PTERO_BACKUP_DEST="/root/backup_containter+data/$DATE"

if [ -d "$PTERO_BACKUP_SRC" ] && [ "$(ls -A $PTERO_BACKUP_SRC 2>/dev/null)" ]; then
    mkdir -p "$PTERO_BACKUP_DEST"
    cp -v "$PTERO_BACKUP_SRC"/*.tar.gz "$PTERO_BACKUP_DEST/" 2>/dev/null
    COPIED=$(ls -1 "$PTERO_BACKUP_DEST" 2>/dev/null | wc -l)
    SIZE=$(du -sh "$PTERO_BACKUP_DEST" 2>/dev/null | cut -f1)
    echo "✅ Đã copy $COPIED file backup container vào: $PTERO_BACKUP_DEST ($SIZE)"
else
    echo "⚠️  Không có file backup nào trong $PTERO_BACKUP_SRC, bỏ qua."
fi

# ─────────────────────────────────────────
# 7. Xóa backup cũ hơn 3 ngày
# ─────────────────────────────────────────
find /root/ptero-backups/ -maxdepth 1 -type d -mtime +3 -exec rm -rf {} \;
find /root/backup_containter+data/ -maxdepth 1 -type d -mtime +3 -exec rm -rf {} \;
echo "🧹 Đã xóa backup cũ hơn 3 ngày"

# ─────────────────────────────────────────
echo ""
echo "✅ Backup hoàn tất! Lưu tại: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
echo ""
echo "📦 Container backups lưu tại: $PTERO_BACKUP_DEST"
ls -lh "$PTERO_BACKUP_DEST" 2>/dev/null || echo "(trống)"
