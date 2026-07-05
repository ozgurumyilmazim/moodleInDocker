#!/bin/bash

# Renk tanımlamaları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}   Moodle & PostgreSQL Otomatik Kurulum Aracı  ${NC}"
echo -e "${BLUE}===============================================${NC}"

# 1. Gereksinim Kontrolleri
echo -e "\n${YELLOW}[1/4] Sistem gereksinimleri kontrol ediliyor...${NC}"

if ! [ -x "$(command -v docker)" ]; then
  echo -e "${RED}Hata: Docker yüklü değil! Lütfen önce Docker'ı kurun.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✔ Docker yüklü.${NC}"

if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}Hata: 'docker compose' komutu bulunamadı! Lütfen Docker Compose V2 kurun.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✔ Docker Compose yüklü.${NC}"

if [ ! -f "env.local" ]; then
  echo -e "${RED}Hata: 'env.local' şablon dosyası bulunamadı! Lütfen dosyanın mevcut olduğunu doğrulayın.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✔ env.local şablonu bulundu.${NC}"

# 2. .env Dosyası Kontrolü
if [ -f ".env" ]; then
  echo -e "\n${YELLOW}Mevcut bir '.env' dosyası tespit edildi!${NC}"
  read -p "Üzerine yazmak istiyor musunuz? (e/h): " overwrite
  if [[ ! "$overwrite" =~ ^[Ee]$ ]]; then
    echo -e "${RED}Kurulum iptal edildi.${NC}"
    exit 0
  fi
fi

# 3. Kullanıcıdan Bilgileri Alma (Varsayılan değerleri env.local'den oku)
echo -e "\n${YELLOW}[2/4] Kurulum parametrelerini belirleyin...${NC}"
echo -e "Parantez içindeki değerleri varsayılan olarak kabul etmek için direkt [Enter] tuşuna basabilirsiniz.\n"

# env.local dosyasından varsayılanları okuma fonksiyonu
get_default() {
  grep "^$1=" env.local | cut -d'=' -f2-
}

DEFAULT_POSTGRES_USER=$(get_default "POSTGRES_USER")
DEFAULT_POSTGRES_DB=$(get_default "POSTGRES_DB")
DEFAULT_PORT=$(get_default "PORT")
DEFAULT_MOODLE_URL=$(get_default "MOODLE_URL")
DEFAULT_MOODLE_SITENAME=$(get_default "MOODLE_SITENAME")
DEFAULT_MOODLE_SITENAME_SHORT=$(get_default "MOODLE_SITENAME_SHORT")
DEFAULT_MOODLE_USERNAME=$(get_default "MOODLE_USERNAME")
DEFAULT_MOODLE_EMAIL=$(get_default "MOODLE_EMAIL")

# PostgreSQL Kullanıcı Adı
read -p "PostgreSQL Kullanıcı Adı [$DEFAULT_POSTGRES_USER]: " postgres_user
postgres_user=${postgres_user:-$DEFAULT_POSTGRES_USER}

# PostgreSQL Şifresi (Güvenli olması için rastgele üretelim veya kullanıcı girsin)
RANDOM_DB_PASS=$(openssl rand -hex 12)
read -p "PostgreSQL Şifresi [$RANDOM_DB_PASS]: " postgres_password
postgres_password=${postgres_password:-$RANDOM_DB_PASS}

# PostgreSQL Veritabanı Adı
read -p "PostgreSQL Veritabanı Adı [$DEFAULT_POSTGRES_DB]: " postgres_db
postgres_db=${postgres_db:-$DEFAULT_POSTGRES_DB}

# Yayınlanacak Port
read -p "Moodle Hangi Porttan Yayınlansın? [$DEFAULT_PORT]: " port
port=${port:-$DEFAULT_PORT}

# Moodle URL
read -p "Moodle URL [$DEFAULT_MOODLE_URL]: " moodle_url
moodle_url=${moodle_url:-$DEFAULT_MOODLE_URL}

# Moodle Site Adı
read -p "Moodle Site Adı [$DEFAULT_MOODLE_SITENAME]: " moodle_sitename
moodle_sitename=${moodle_sitename:-$DEFAULT_MOODLE_SITENAME}

# Moodle Site Kısa Adı
read -p "Moodle Site Kısa Adı [$DEFAULT_MOODLE_SITENAME_SHORT]: " moodle_sitename_short
moodle_sitename_short=${moodle_sitename_short:-$DEFAULT_MOODLE_SITENAME_SHORT}

# Moodle Yönetici Kullanıcı Adı
read -p "Moodle Yönetici Kullanıcı Adı [$DEFAULT_MOODLE_USERNAME]: " moodle_username
moodle_username=${moodle_username:-$DEFAULT_MOODLE_USERNAME}

# Moodle Yönetici Şifresi (Validasyonlu)
while true; do
  echo -e "\n${BLUE}NOT: Moodle şifresi en az 8 karakter olmalı; en az 1 büyük, 1 küçük harf, 1 rakam ve 1 özel karakter içermelidir.${NC}"
  read -sp "Moodle Yönetici Şifresi girin: " moodle_password
  echo ""
  
  # Moodle şifre doğrulama kuralları
  if [ ${#moodle_password} -lt 8 ]; then
    echo -e "${RED}Hata: Şifre en az 8 karakter olmalıdır!${NC}"
    continue
  fi
  if ! [[ "$moodle_password" =~ [A-Z] ]]; then
    echo -e "${RED}Hata: Şifre en az bir büyük harf içermelidir!${NC}"
    continue
  fi
  if ! [[ "$moodle_password" =~ [a-z] ]]; then
    echo -e "${RED}Hata: Şifre en az bir küçük harf içermelidir!${NC}"
    continue
  fi
  if ! [[ "$moodle_password" =~ [0-9] ]]; then
    echo -e "${RED}Hata: Şifre en az bir rakam içermelidir!${NC}"
    continue
  fi
  if ! [[ "$moodle_password" =~ [^a-zA-Z0-9] ]]; then
    echo -e "${RED}Hata: Şifre en az bir özel karakter (*, -, !, # vb.) içermelidir!${NC}"
    continue
  fi
  
  break
done

# Moodle Yönetici E-Posta
read -p "Moodle Yönetici E-Posta [$DEFAULT_MOODLE_EMAIL]: " moodle_email
moodle_email=${moodle_email:-$DEFAULT_MOODLE_EMAIL}

# 4. .env Dosyasını Oluşturma
echo -e "\n${YELLOW}[3/4] .env dosyası oluşturuluyor...${NC}"

cat <<EOF > .env
# PostgreSQL (Veritabanı) Ayarları
POSTGRES_USER=${postgres_user}
POSTGRES_PASSWORD=${postgres_password}
POSTGRES_DB=${postgres_db}

# Moodle Genel Ayarları
MOODLE_URL=${moodle_url}
MOODLE_SITENAME=${moodle_sitename}
MOODLE_SITENAME_SHORT=${moodle_sitename_short}

# Moodle Yönetici Giriş Bilgileri
MOODLE_USERNAME=${moodle_username}
MOODLE_PASSWORD=${moodle_password}
MOODLE_EMAIL=${moodle_email}

# Ağ / Port Ayarları
PORT=${port}
EOF

echo -e "${GREEN}✔ .env dosyası başarıyla oluşturuldu.${NC}"

# 5. Docker Compose Başlatma
echo -e "\n${YELLOW}[4/4] Docker konteynerleri derleniyor ve başlatılıyor...${NC}"
echo -e "Bu işlem internet hızınıza ve bilgisayarınızın performansına bağlı olarak birkaç dakika sürebilir.\n"

docker compose up --build -d

if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}===============================================${NC}"
  echo -e "${GREEN}  KURULUM BAŞARIYLA BAŞLATILDI!                ${NC}"
  echo -e "${GREEN}===============================================${NC}"
  echo -e "\nSistem arka planda yapılandırılıyor. Log kayıtlarını izlemek için şu komutu kullanabilirsiniz:"
  echo -e "${YELLOW}docker compose logs -f moodle${NC}\n"
  echo -e "Kurulum tamamlandığında erişim bilgileriniz:"
  echo -e "🔗 Web Adresi: ${BLUE}${moodle_url}:${port}${NC}"
  echo -e "👤 Giriş Kullanıcı Adı: ${BLUE}${moodle_username}${NC}"
  echo -e "🔑 Giriş Şifresi: ${BLUE}${moodle_password}${NC}"
  echo -e "${GREEN}===============================================${NC}"
else
  echo -e "\n${RED}Hata: Docker servisleri başlatılamadı! Lütfen yukarıdaki hata mesajlarını kontrol edin.${NC}"
  exit 1
fi