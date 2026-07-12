#!/bin/bash

#setup.sh

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
if [ ! -f ".env" ]; then
  cp env.local .env
  echo -e "${GREEN}✔ env.local dosyası .env olarak kopyalandı.${NC}"
else
  echo -e "\n${YELLOW}Mevcut bir '.env' dosyası tespit edildi!${NC}"
  read -p "env.local dosyasının üzerine yazılmasını istiyor musunuz? (e/h): " overwrite
  if [[ "$overwrite" =~ ^[Ee]$ ]]; then
    cp env.local .env
    echo -e "${GREEN}✔ env.local şablonu .env üzerine yazıldı.${NC}"
  else
    echo -e "${YELLOW}Mevcut .env dosyası korunarak devam ediliyor...${NC}"
  fi
fi

# 3. Kullanıcıdan Bilgileri Alma (Varsayılan değerleri .env dosyasından oku)
echo -e "\n${YELLOW}[2/4] Kurulum parametrelerini belirleyin...${NC}"
echo -e "Parantez içindeki değerleri varsayılan olarak kabul etmek için direkt [Enter] tuşuna basabilirsiniz.\n"

# .env dosyasından varsayılanları okuma ve görünmez \r karakterlerini temizleme fonksiyonu
get_default() {
  grep "^$1=" .env | cut -d'=' -f2- | tr -d '\r'
}

DEFAULT_POSTGRES_USER=$(get_default "POSTGRES_USER")
DEFAULT_POSTGRES_DB=$(get_default "POSTGRES_DB")
DEFAULT_PORT=$(get_default "PORT")
DEFAULT_MOODLE_URL=$(get_default "MOODLE_URL")
DEFAULT_MOODLE_SITENAME=$(get_default "MOODLE_SITENAME")
DEFAULT_MOODLE_SITENAME_SHORT=$(get_default "MOODLE_SITENAME_SHORT")
DEFAULT_MOODLE_USERNAME=$(get_default "MOODLE_USERNAME")
DEFAULT_MOODLE_EMAIL=$(get_default "MOODLE_EMAIL")
DEFAULT_MOODLE_REVERSEPROXY=$(get_default "MOODLE_REVERSEPROXY")

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
echo -e "\n${BLUE}NOT: Kullanıcıların tarayıcıda göreceği PUBLIC adresi girin.${NC}"
echo -e "${BLUE}      Cloudflare Tunnel kullanıyorsanız → https://lms.example.com${NC}"
echo -e "${BLUE}      Yerel/test ortamı için           → http://localhost${NC}"
echo -e "${BLUE}      (Docker arka planda HTTP çalışır, Cloudflare HTTPS'i üstlenir — bu normaldir)${NC}"
read -p "Moodle URL [$DEFAULT_MOODLE_URL]: " moodle_url
moodle_url=${moodle_url:-$DEFAULT_MOODLE_URL}

# Cloudflare Tunnel / Ters Proxy
echo -e "\n${BLUE}NOT: Cloudflare Tunnel veya başka bir ters proxy (Nginx PM vb.) kullanıyorsanız 'true' girin.${NC}"
echo -e "${BLUE}      (Yukarıda https:// ile URL girdiyseniz bu ayar da 'true' olmalıdır)${NC}"
read -p "Ters Proxy Modu (true/false) [$DEFAULT_MOODLE_REVERSEPROXY]: " moodle_reverseproxy
moodle_reverseproxy=${moodle_reverseproxy:-$DEFAULT_MOODLE_REVERSEPROXY}

# Moodle Site Adı
read -p "Moodle Site Adı [$DEFAULT_MOODLE_SITENAME]: " moodle_sitename
moodle_sitename=${moodle_sitename:-$DEFAULT_MOODLE_SITENAME}

# Moodle Site Kısa Adı
read -p "Moodle Site Kısa Adı [$DEFAULT_MOODLE_SITENAME_SHORT]: " moodle_sitename_short
moodle_sitename_short=${moodle_sitename_short:-$DEFAULT_MOODLE_SITENAME_SHORT}

# Moodle Yönetici Kullanıcı Adı
read -p "Moodle Yönetici Kullanıcı Adı [$DEFAULT_MOODLE_USERNAME]: " moodle_username
moodle_username=${moodle_username:-$DEFAULT_MOODLE_USERNAME}

# Moodle Yönetici Şifresi için Moodle uyumlu rastgele şifre üretelim
SPEC_CHARS='!@#%*+=-?'
SPECIALS=""
for i in {1..3}; do
  SPECIALS="${SPECIALS}${SPEC_CHARS:$((RANDOM % ${#SPEC_CHARS})):1}"
done
UPPERS=$(openssl rand -base64 15 | tr -dc 'A-Z' | head -c 3)
LOWERS=$(openssl rand -base64 15 | tr -dc 'a-z' | head -c 3)
DIGITS=$(openssl rand -base64 15 | tr -dc '0-9' | head -c 3)
RAW_PASS="${UPPERS}${LOWERS}${DIGITS}${SPECIALS}"

if command -v shuf >/dev/null 2>&1; then
  RANDOM_ADMIN_PASS=$(echo "$RAW_PASS" | fold -w1 | shuf | tr -d '\n')
else
  RANDOM_ADMIN_PASS="${UPPERS:0:1}${LOWERS:0:1}${DIGITS:0:1}${SPECIALS:0:1}${UPPERS:1:2}${LOWERS:1:2}${DIGITS:1:2}${SPECIALS:1:2}"
fi

# Moodle Yönetici Şifresi (Validasyonlu)
while true; do
  echo -e "\n${BLUE}NOT: Moodle şifresi en az 8 karakter olmalı; en az 1 büyük, 1 küçük harf, 1 rakam ve 1 özel karakter içermelidir.${NC}"
  read -p "Moodle Yönetici Şifresi [$RANDOM_ADMIN_PASS]: " input_password
  
  # Eğer boş geçildiyse varsayılan rastgele şifreyi ata
  moodle_password=${input_password:-$RANDOM_ADMIN_PASS}
  
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

# ÖNEMLİ: Windows CRLF (satır sonu) uyumsuzluğunu gidermek için .env dosyasını temizleyelim
tr -d '\r' < .env > .env.tmp && mv .env.tmp .env

echo -e "${GREEN}✔ .env dosyası başarıyla oluşturuldu ve satır sonları optimize edildi.${NC}"

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