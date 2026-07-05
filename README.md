Docker ile Resmi Moodle (PostgreSQL) Kurulum Şablonu

Bu proje, Resmi PHP ve Resmi PostgreSQL Docker imajları kullanılarak hazırlanmış, tamamen özelleştirilebilir ve üretime hazır bir Moodle LMS şablonudur. Veritabanı motoru olarak yüksek performanslı ve modern PostgreSQL 16 kullanılmıştır.

Hassas şifreler .env dosyasında tutulduğu ve bu dosya Git tarafından yoksayıldığı için bu şablonu güvenle kendi projelerinizde veya GitHub üzerinde public olarak paylaşabilirsiniz.

🛠️ Özellikler

Resmi PHP 8.2-Apache tabanlı özelleştirilmiş Docker imajı (PostgreSQL sürücüleri entegre edilmiştir).

Resmi PostgreSQL 16 veritabanı motoru.

İlk açılışta veritabanının hazır olmasını bekleyen ve kurulumu otomatik yapan akıllı giriş betiği (entrypoint).

Moodle için optimize edilmiş PHP opcache ve bellek limit ayarları.

Tamamen Türkçe dil desteği ile otomatik CLI kurulumu.

setup.sh interaktif kurulum asistanı.

🚀 Hızlı Başlangıç (Önerilen)

Projeyi bilgisayarınıza klonladıktan sonra tek yapmanız gereken interaktif kurulum betiğini çalıştırmaktır. Betik sistem gereksinimlerini kontrol edecek, şifrelerinizi güvenli kurallara göre almanızı sağlayacak ve Docker sistemini ayağa kaldıracaktır.

Adım 1: Projeyi Klonlayın

git clone <https://github.com/ozgurumyilmazim/moodleInDocker.git>
cd moodleInDocker

Adım 2: Kurulum Betiğini Çalıştırın

Betiğe çalışma izni verin ve çalıştırın:

chmod +x setup.sh
./setup.sh

Ekranda beliren yönergeleri takip edin. Sistem sizden Moodle başlığı, şifreleri ve portları isteyecektir.

Adım 3: Logları İzleyin (İsteğe Bağlı)

Konteynerlerin derlenmesi ve veritabanı tablolarının resmi Moodle CLI aracı ile şemalandırılması birkaç dakika sürebilir. Bu süreci takip etmek için:

docker compose logs -f moodle

İşlem bittiğinde tarayıcınızdan belirttiğiniz adrese giderek giriş yapabilirsiniz.

⚙️ Manuel Kurulum (Alternatif)

Eğer kurulum betiğini kullanmak istemiyorsanız, adımları elle şu şekilde gerçekleştirebilirsiniz:

Çevre Değişkenlerini Tanımlayın:

cp env.local .env

.env dosyasını açarak veritabanı şifrelerini, portu ve Moodle giriş şifresini kendinize göre güncelleyin. (Moodle şifresinin en az 8 karakter, bir büyük, bir küçük, bir rakam ve bir özel karakter içermesi zorunludur).

Konteynerleri Başlatın:

docker compose up --build -d

📂 Dosya Yapısı

setup.sh: İnteraktif, hata denetimli kurulum asistanı scripti.

Dockerfile: Moodle için gerekli PostgreSQL PHP bağımlılıklarını yükleyen ve resmi kodu indiren dosya.

docker-entrypoint.sh: Veritabanı durumunu denetleyen ve PostgreSQL üzerinden kurulumu otomatikleştiren başlangıç scripti.

docker-compose.yml: PostgreSQL ve Moodle servislerinin Docker orkestrasyon dosyası.

env.local: Dağıtıma hazır çevre değişkenleri şablon dosyası (Git'e yüklenir).

.gitignore: Hassas bilgileri içeren .env dosyasını git dışı bırakır.

🧹 Durdurma ve Sıfırlama

Sistemi durdurmak için:

docker compose down

Tüm verileri silip sıfırdan temiz bir kurulum başlatmak için (Dikkat: Tüm verileriniz kalıcı olarak silinir):

docker compose down -v
