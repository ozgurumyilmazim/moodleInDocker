#!/bin/bash
set -e

#docker-entrypoint.sh

# Görünmez Windows satır sonu (\r) karakterlerini tüm değişkenlerden temizleyen koruma bloğu
MOODLE_DATABASE_HOST=$(echo -n "$MOODLE_DATABASE_HOST" | tr -d '\r')
MOODLE_DATABASE_USER=$(echo -n "$MOODLE_DATABASE_USER" | tr -d '\r')
MOODLE_DATABASE_PASSWORD=$(echo -n "$MOODLE_DATABASE_PASSWORD" | tr -d '\r')
MOODLE_DATABASE_NAME=$(echo -n "$MOODLE_DATABASE_NAME" | tr -d '\r')
MOODLE_URL=$(echo -n "$MOODLE_URL" | tr -d '\r')
MOODLE_SITENAME=$(echo -n "$MOODLE_SITENAME" | tr -d '\r')
MOODLE_SITENAME_SHORT=$(echo -n "$MOODLE_SITENAME_SHORT" | tr -d '\r')
MOODLE_USERNAME=$(echo -n "$MOODLE_USERNAME" | tr -d '\r')
MOODLE_PASSWORD=$(echo -n "$MOODLE_PASSWORD" | tr -d '\r')
MOODLE_EMAIL=$(echo -n "$MOODLE_EMAIL" | tr -d '\r')

# Veritabanının hazır olmasını bekleyen kontrol mekanizması
echo "PostgreSQL veritabanı bağlantısı bekleniyor..."
until php -r "
    \$conn = @pg_connect('host=${MOODLE_DATABASE_HOST} port=5432 dbname=${MOODLE_DATABASE_NAME} user=${MOODLE_DATABASE_USER} password=${MOODLE_DATABASE_PASSWORD}');
    if (!\$conn) {
        exit(1);
    }
" 2>/dev/null; do
    echo "Veritabanı henüz hazır değil, 3 saniye sonra tekrar denenecek..."
    sleep 3
done
echo "PostgreSQL bağlantısı başarılı!"

# Eğer config.php yoksa, Moodle'ı otomatik kuralım
if [ ! -f /var/www/html/config.php ]; then
    echo "İlk kurulum algılandı. Resmi Moodle CLI kurulumu başlatılıyor..."
    
    # Satır sonu (CRLF) birleşme hatalarını önlemek için tek satırda güvenli kurulum komutu
    php /var/www/html/admin/cli/install.php --lang=tr --wwwroot="${MOODLE_URL}" --dataroot="/var/www/moodledata" --dbtype="pgsql" --dbhost="${MOODLE_DATABASE_HOST}" --dbname="${MOODLE_DATABASE_NAME}" --dbuser="${MOODLE_DATABASE_USER}" --dbpass="${MOODLE_DATABASE_PASSWORD}" --dbport=5432 --fullname="${MOODLE_SITENAME}" --shortname="${MOODLE_SITENAME_SHORT}" --adminuser="${MOODLE_USERNAME}" --adminpass="${MOODLE_PASSWORD}" --adminemail="${MOODLE_EMAIL}" --agree-license --non-interactive

    # --- CLOUDFLARE TUNNEL & REVERSE PROXY ENJEKSİYONU ---
    echo "Cloudflare Tunnel / Reverse Proxy ayarları config.php dosyasına otomatik ekleniyor..."
    cat << 'EOF' >> /var/www/html/config.php

// Cloudflare Tunnel / Reverse Proxy Konfigürasyonu
$CFG->reverseproxy = true;
if (!empty($_SERVER['HTTP_CF_CONNECTING_IP'])) {
    $_SERVER['REMOTE_ADDR'] = $_SERVER['HTTP_CF_CONNECTING_IP'];
}
EOF
    # --- ENJEKSİYON SONU ---

    # Güvenlik için dosya yetkilerini sıkılaştıralım
    chown www-data:www-data /var/www/html/config.php
    chmod 640 /var/www/html/config.php

   # Cloudflare Tunnel / Ters Proxy desteği
    if [ "${MOODLE_REVERSEPROXY}" = "true" ]; then
        echo "Ters proxy (Cloudflare Tunnel) modu etkinleştiriliyor..."
        # config.php'ye sslproxy ve reverseproxy ayarlarını ekle
        sed -i "s|require_once(__DIR__ . '/lib/setup.php');|\n\$CFG->sslproxy = true;\n\$CFG->reverseproxy = false;\n\$_SERVER['HTTPS']  = 'on';\n\nrequire_once(__DIR__ . '/lib/setup.php');\n|" /var/www/html/config.php
        
        # Apache'ye X-Forwarded-Proto başlığını okutarak PHP'ye HTTPS olduğunu bildirmesini sağlayalım
        # Bu, Moodle'ın HTTP'ye yönlendirme döngüsüne girmesini engeller
        echo "SetEnvIf X-Forwarded-Proto \"https\" HTTPS=on" >> /var/www/html/.htaccess
        echo "Ters proxy ayarları uygulandı."
    fi

    echo "Moodle kurulumu başarıyla tamamlandı!"
else
    echo "config.php dosyası mevcut. Kurulum adımı atlanıyor."
fi

# Ana süreci (Apache) başlatalım
exec "$@"