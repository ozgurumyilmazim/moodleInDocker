#!/bin/bash
set -e

#docker-entrypoint.sh

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
    php /var/www/html/admin/cli/install.php --lang=tr --webaddress="${MOODLE_URL}" --datadir="/var/www/moodledata" --dbtype="pgsql" --dbhost="${MOODLE_DATABASE_HOST}" --dbname="${MOODLE_DATABASE_NAME}" --dbuser="${MOODLE_DATABASE_USER}" --dbpass="${MOODLE_DATABASE_PASSWORD}" --dbport=5432 --fullname="${MOODLE_SITENAME}" --shortname="${MOODLE_SITENAME_SHORT}" --adminuser="${MOODLE_USERNAME}" --adminpass="${MOODLE_PASSWORD}" --adminemail="${MOODLE_EMAIL}" --agree-license --non-interactive

    # Güvenlik için dosya yetkilerini sıkılaştıralım
    chown www-data:www-data /var/www/html/config.php
    chmod 640 /var/www/html/config.php
    echo "Moodle kurulumu başarıyla tamamlandı!"
else
    echo "config.php dosyası mevcut. Kurulum adımı atlanıyor."
fi

# Ana süreci (Apache) başlatalım
exec "$@"