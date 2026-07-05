#Dockerfile

FROM php:8.2-apache

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

# Apache mod_rewrite modülünü aktif edelim
RUN a2enmod rewrite

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

# Resmi Moodle paketini indirip çıkaralım (Moodle 5.1.5 sürümü için stable501 dalı kullanılıyor)
ARG MOODLE_VERSION=5.1.5
RUN curl -fSL "https://download.moodle.org/download.php/direct/stable501/moodle-${MOODLE_VERSION}.tgz" -o moodle.tgz \
    && tar -xzf moodle.tgz --strip-components=1 -C /var/www/html \
    && rm moodle.tgz

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