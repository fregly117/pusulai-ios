# PusulAI iOS Uygulaması (.ipa)

Uygulama, Railway'deki sitenin (https://pusulai.up.railway.app) birebir aynısını gösterir. Altyapı,
FotMob verileri, kupon motoru, tema ve favoriler aynıdır. Siteye yaptığın her güncelleme uygulamaya
otomatik olarak gelir.

## Uygulamada neler var
- Gerçek uygulama ikonu ve açılış ekranı var, Safari çubuğu hiç görünmez.
- Gol, düdük ve sinyal sesleri ekrana dokunmadan da çalar.
- **Favori maç bildirimleri** SofaScore biçiminde gelir: maç başladı, gol (dakika, skor ve atan oyuncu),
  kırmızı kart, VAR iptali, devre arası, ikinci yarı, maç sonucu ve gol alarmı.
- **Bildirim sesleri sitendeki seslerle aynı** (uygulama kapalıyken de): gol → `gol`, maç başladı →
  `baslama`, devre arası → `devre`, ikinci yarı / kırmızı kart / VAR → `duduk`, maç sonu → `bitis`,
  gol alarmı → `sinyal`. Sesler `PusulAI/Sounds` klasöründe; değiştirmek için aynı adla yeni bir
  `.caf` dosyası koyman yeterli (en fazla 30 sn).
- **Dinamik Ada ve kilit ekranında canlı skor (takım logolarıyla):** SofaScore gibi solda ev sahibinin
  logosu ve skoru, sağda deplasmanın skoru ve logosu görünür. Ada açılınca logolar, takım adları, skor,
  dakika ve lig gösterilir; devre arası ve maç sonu da işaretlenir. Gol olunca ada büyür ve "⚽ GOL!" yazar. Dinamik Ada'sı olmayan iPhone'larda aynı kart
  kilit ekranında görünür.
- Site dışındaki bağlantılar uygulamanın içinde açılır. Aşağı çekip bırakarak sayfayı yenileyebilirsin.
  İnternet yoksa "Tekrar dene" ekranı çıkar.

## Uygulama kapalıyken: iki çalışma şekli
Uygulama hangi Apple ID ile kurulduğunu kendisi algılar ve uygun şekilde çalışır.

| | Ücretsiz Apple ID | Apple Developer üyeliği (yıllık 99 $) |
|---|---|---|
| Uygulama açıkken bildirim ve Dinamik Ada | ✅ | ✅ |
| Arka planda (en fazla 3 saat) | ✅ | ✅ |
| **Uygulama tamamen kapalıyken** bildirim | ❌ | ✅ |
| **Uygulama kapalıyken** Dinamik Ada güncellemesi | ❌ | ✅ |
| Maç başlayınca Dinamik Ada kendiliğinden açılır (iOS 17.2+) | ❌ | ✅ |
| Uygulamanın süresi | 7 günde bir yeniden yükleme | 1 yıl |

Uygulama kapalıyken bildirim göndermeye Apple yalnızca Developer üyeliğiyle izin veriyor; SofaScore
da aynı sistemi kullanıyor. Gerekli kodun tamamı hem uygulamada hem sitende hazır. Üyelik alındıktan
sonra aşağıdaki **3. bölüm** bir kez yapılır.

---

## 1) .ipa dosyasını üret (GitHub ücretsiz Mac'te derler)
0. Masaüstündeki **PusulAI-iOS.zip** dosyasına sağ tıkla → **Tümünü Ayıkla** → Masaüstü. Böylece
   derleme ayarlarını içeren `.github` klasörü de gelir.
1. github.com'da **New repository** → adı `pusulai-ios` (Private olabilir) → **Create**.
2. **uploading an existing file** bağlantısına tıkla. `PusulAI-iOS` klasörünün **içindeki her şeyi**
   (`.github`, `PusulAI`, `PusulAIWidgets`, `Shared`, `project.yml`) sürükleyip bırak → **Commit changes**.
3. **Actions** sekmesinde "PusulAI iOS (.ipa)" kendiliğinden başlar ve yaklaşık 5–10 dakika sürer.
   Bittiğinde **Releases** bölümünden `PusulAI.ipa` dosyasını indir.

## 2) iPhone'a kur (Windows + Sideloadly)
1. **Sideloadly** (sideloadly.io) kur. Ayrıca Apple'ın sitesinden **iTunes** ve **iCloud** kur
   (Microsoft Store sürümleri değil).
2. iPhone'u USB ile bağla → `PusulAI.ipa` dosyasını seç → Apple ID'ni yaz → **Start**.
   Advanced Options'taki **"Remove app extensions" işaretli OLMASIN**, çünkü Dinamik Ada o eklentide.
3. iPhone'da: **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu → Aç** (telefon yeniden başlar).
4. **Ayarlar → Genel → VPN ve Aygıt Yönetimi** → Apple ID'ne dokun → **Güven**.
5. PusulAI'yi aç, bir maçı yıldızla. Bildirim izni sorulunca **İzin Ver**'e dokun.
6. **Ayarlar → PusulAI → Canlı Etkinlikler** açık olmalı (varsayılan olarak açık).

## 3) Uygulama kapalıyken bildirim ve Dinamik Ada (Developer üyeliği ile, tek seferlik)
1. developer.apple.com/programs üzerinden **Apple Developer Program**'a katıl.
2. developer.apple.com → **Certificates, IDs & Profiles → Keys → +** → bir ad ver →
   **Apple Push Notifications service (APNs)** kutusunu işaretle → **Continue → Register → Download**.
   İnen dosya `AuthKey_XXXXXXXXXX.p8`. Bu dosya yalnızca bir kez indirilebilir, sakla.
   Sayfadaki **Key ID** değerini not et.
3. **Membership** sayfasındaki **Team ID** değerini not et.
4. **Railway → PusulAI servisi → Variables** bölümüne şunları ekle:
   - `APNS_KEY_ID` = Key ID
   - `APNS_TEAM_ID` = Team ID
   - `APNS_KEY` = .p8 dosyasını Not Defteri ile aç ve tüm içeriğini yapıştır
     (`-----BEGIN PRIVATE KEY-----` satırı dahil)
5. Uygulamayı Sideloadly'de **Developer üyeliği olan Apple ID ile** yeniden kur (2. bölüm).
6. Test: uygulamayı aç, bildirim izni ver, sonra tarayıcıda şu adresi aç:
   `https://pusulai.up.railway.app/api/push/ios-test`. Telefona örnek bir gol bildirimi gelmeli.
   Gelmezse developer.apple.com → **Identifiers** → uygulamanın kimliği (`com.klennys.pusulai`
   veya Sideloadly'nin verdiği kimlik) → **Push Notifications** kutusunu işaretleyip kaydet ve 5. adımı
   tekrarla.

Bu ayarlardan sonra uygulama, sunucunun bildirim gönderebildiğini kendisi anlar. Arka planda uyanık
kalma özelliğini kapatır (pil harcamaz); bildirimler ve Dinamik Ada sunucudan gelir.

## Ayarlar
- Site adresi: `PusulAI/WebViewController.swift` → `homeURL` / `appHost`
- Sunucu kayıt adresi: `PusulAI/PushRegistrar.swift` → `endpoint`
- Arka planda uyanık kalma süresi (ücretsiz hesap): `PusulAI/BackgroundKeeper.swift` → `maxDuration`
- Dinamik Ada tasarımı: `PusulAIWidgets/MatchLiveActivity.swift`
