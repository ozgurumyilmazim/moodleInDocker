# moodleInDocker

A LMS (moodle) in a docker environment

Docker ile Resmi Moodle (PostgreSQL) Kurulum Şablonu

Bu proje, Resmi PHP ve Resmi PostgreSQL Docker imajları kullanılarak hazırlanmış, tamamen özelleştirilebilir ve üretime hazır bir Moodle LMS şablonudur. Veritabanı motoru olarak yüksek performanslı ve modern PostgreSQL 16 kullanılmıştır.

Hassas şifreler .env dosyasında tutulduğu ve bu dosya Git tarafından yoksayıldığı için bu şablonu güvenle kendi projelerinizde veya GitHub üzerinde public olarak paylaşabilirsiniz.

🛠️ Özellikler

Resmi PHP 8.2-Apache tabanlı özelleştirilmiş Docker imajı (PostgreSQL sürücüleri entegre edilmiştir).

Resmi PostgreSQL 16 veritabanı motoru.

İlk açılışta veritabanının hazır olmasını bekleyen ve kurulumu otomatik yapan akıllı giriş betiği (entrypoint).

Moodle için optimize edilmiş PHP opcache ve bellek limit ayarları.

Tamamen Türkçe dil desteği ile otomatik CLI kurulumu.

🚀 Hızlı Başlangıç

Adım 1: Projeyi Klonlayın

git clone <https://github.com/ozgurumyilmazim/moodleInDocker.git>
cd moodleInDocker

Adım 2: Çevre Değişkenlerini Tanımlayın

Projeyle birlikte gelen şablon niteliğindeki env.local dosyasını, Docker'ın otomatik olarak tanıyacağı .env adıyla kopyalayın:

cp env.local .env

Şimdi oluşturduğunuz .env dosyasını açıp şifrelerinizi ve sitenizin ayarlarını kendinize göre belirleyin.
(Önemli: Güvenlik gereği MOODLE_PASSWORD şifreniz en az 8 karakter, bir büyük, bir küçük, bir rakam ve bir özel karakter içermelidir).

Adım 3: Sistemi Derleyin ve Başlatın

Moodle imajını yerel olarak derlemek ve servisleri ayağa kaldırmak için:

docker-compose up --build -d

Adım 4: Moodle'a Erişin

Konteynerlerin derlenmesi ve veritabanı tablolarının resmi Moodle CLI aracı ile şemalandırılması birkaç dakika sürebilir. Log kayıtlarını izlemek isterseniz:

docker-compose logs -f moodle

İşlem bittiğinde tarayıcınızdan .env dosyasında belirttiğiniz MOODLE_URL adresine (Varsayılan: <http://localhost>) giderek giriş yapabilirsiniz.

📂 Dosya Yapısı

Dockerfile: Moodle için gerekli PostgreSQL PHP bağımlılıklarını yükleyen ve resmi kodu indiren dosya.

docker-entrypoint.sh: Veritabanı durumunu denetleyen ve PostgreSQL üzerinden kurulumu otomatikleştiren başlangıç scripti.

docker-compose.yml: PostgreSQL ve Moodle servislerinin Docker orkestrasyon dosyası.

env.local: Dağıtıma hazır çevre değişkenleri şablon dosyası (Git'e yüklenir).

.gitignore: Hassas bilgileri içeren .env dosyasını git dışı bırakır.

🧹 Durdurma ve Sıfırlama

Sistemi durdurmak için:

docker-compose down

Tüm verileri silip sıfırdan temiz bir kurulum başlatmak için:

docker-compose down -v
