#Dockerfile

FROM php:8.3-apache

# Gerekli sistem kütüphanelerini yükleyelim (PostgreSQL için libpq-dev eklendi)
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libxml2-dev \
    libicu-dev \
    libonig-dev \
    libsodium-dev \
    libcurl4-openssl-dev \
    libpq-dev \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Moodle için zorunlu PHP eklentilerini derleyip kuralım (mysqli yerine pgsql ve pdo_pgsql eklendi)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    pgsql \
    pdo_pgsql \
    zip \
    xml \
    intl \
    soap \
    opcache \
    mbstring \
    exif \
    sodium \
    curl

# =========================================================================
# [SON GÜNCELLEME 1]: APACHE YÖNLENDİRME (ROUTING) VE .HTACCESS AYARLARI
# Moodle 5.x ile gelen yeni API/Yönlendirme yapısının çalışması için:
# 
# 1. 'a2enmod rewrite': URL yönlendirmelerinin (RewriteEngine) aktif edilmesini sağlar.
# 2. 'sed... AllowOverride All': Apache'de varsayılan olarak kapalı olan .htaccess 
#    dosyalarının okunmasına izin verir. Bu, "Router not configured" uyarısını çözer.
# 3. 'AcceptPathInfo On': Moodle'ın modern PathInfo URL'lerini doğru işlemesini sağlar.
# =========================================================================
RUN a2enmod rewrite \
    && sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && echo "AcceptPathInfo On" >> /etc/apache2/apache2.conf

# Apache DocumentRoot ayarını Moodle 5.x standartlarına göre /var/www/html/public yapalım
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Moodle için önerilen PHP konfigürasyonlarını ayarlayalım
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.use_cwd=1'; \
    echo 'max_execution_time=600'; \
    echo 'memory_limit=512M'; \
    echo 'post_max_size=128M'; \
    echo 'upload_max_filesize=128M'; \
    echo 'max_input_vars=5000'; \
    } > /usr/local/etc/php/conf.d/moodle-recommended.ini

# =========================================================================
# [SON GÜNCELLEME 2]: COMPOSER ENTEGRASYONU VE OTOMATİK SİNIF YÜKLEYİCİ
# Moodle 5.x bağımlılıklarını yönetmek ve sunucu kontrollerindeki 
# "Composer installed data not found" uyarısını kalıcı olarak çözmek için:
# 
# 1. 'COPY --from=composer...': Resmi Composer imajından çalıştırılabilir dosyayı kopyalarız.
# 2. 'COMPOSER_ALLOW_SUPERUSER=1': Root kullanıcısıyla çalıştırılmasına izin veririz.
# =========================================================================
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Resmi Moodle paketini indirip çıkaralım (Moodle 5.2.1 sürümü için stable502 dalı kullanılıyor)
ARG MOODLE_VERSION=5.2.1
RUN curl -fSL "https://download.moodle.org/download.php/direct/stable502/moodle-${MOODLE_VERSION}.tgz" -o moodle.tgz \
    && tar -xzf moodle.tgz --strip-components=1 -C /var/www/html \
    && rm moodle.tgz

# =========================================================================
# [SON GÜNCELLEME 2'NİN DEVAMI]: BAĞIMLILIKLARIN KURULUMU VE SINIF HARİTALARI
# Çalışma dizinini Moodle kök dizini yapıp sınıf haritalarını (classmaps) 
# optimize edilmiş şekilde yeniden oluştururuz.
# =========================================================================
WORKDIR /var/www/html
RUN composer install --no-dev --classmap-authoritative --no-interaction

# Verilerin saklanacağı moodledata klasörünü web erişimi dışına oluşturalım
RUN mkdir -p /var/www/moodledata \
    && chown -R www-data:www-data /var/www/moodledata /var/www/html

# Başlangıç betiğini kopyalayalım
COPY docker-entrypoint.sh /usr/local/bin/

# Windows/CRLF satır sonu uyumsuzluğunu gidermek için sed ile temizlik yapalım
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]