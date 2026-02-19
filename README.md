# 🛡️ Luma Shield

**Luma Shield**, ağ paketlerini manipüle ederek DPI (Deep Packet Inspection) engellerini aşmak için tasarlanmış, hibrit mimarili ve yüksek performanslı bir siber güvenlik aracıdır. C tabanlı bir çekirdek ile Flutter'ın modern arayüzünü birleştirir.

---

## ✨ Öne Çıkan Özellikler

* **Native Core:** Performans ve düşük gecikme için saf **C** diliyle geliştirilmiş proxy motoru.
* **Modern UI:** Kullanıcı deneyimini ön plana çıkaran, dinamik Cyberpunk temalı **Flutter** arayüzü.
* **macOS Entegrasyonu:** `LaunchAgents` desteği ile sistem açılışında otomatik başlama (Persistence) seçeneği.
* **Akıllı Temizlik:** Uygulama kapandığında geçici dosyaları ve proxy ayarlarını otomatik sıfırlama.
* **Canlı Log Akışı:** C motorundan gelen ağ trafiği verilerini anlık olarak arayüzde görüntüleme.

---

## 🛠️ Teknik Mimari

Luma Shield, sistem düzeyinde ağ manipülasyonu yapabilmek için iki ana katmandan oluşur:

| Katman | Teknoloji | Fonksiyon |
| :--- | :--- | :--- |
| **Arayüz (Frontend)** | Flutter (Dart) | Sistem kontrolü, durum izleme ve süreç yönetimi. |
| **Çekirdek (Core)** | Native C | TCP paket parçalama (fragmentation) ve yerel HTTP proxy sunucusu. |
| **Sistem Servisi** | macOS `launchctl` | Arka plan süreci (Launch Agent) kontrolü ve kalıcı kurulum. |



### Nasıl Çalışır?
C motoru, yerel cihazda bir proxy sunucusu başlatır. Flutter arayüzü bu motoru yönetirken aynı zamanda macOS ağ ayarlarını (networksetup) bu yerel proxy'ye yönlendirir. Motor, giden paketleri DPI sistemlerinin tanıyamayacağı şekilde parçalara ayırarak hedefe ulaştırır.

---

## 📥 Kurulum ve Kullanım

### 1. İndirme
[Releases](../../releases) sayfasından en güncel `.dmg` dosyasını indirin.

### 2. Yükleme
İndirdiğiniz `.dmg` dosyasını açın ve **Luma Shield** uygulamasını **Uygulamalar (Applications)** klasörüne sürükleyin.

### 3. Önemli: Gatekeeper İzni
Uygulama yerel bir binary (C motoru) çalıştırdığı için Apple tarafından engellenebilir. Bunu aşmak için terminali açın ve şu komutu çalıştırın:
```bash
xattr -cr /Applications/Luma\ Shield.app
```
4. Çalıştırma

Uygulamayı başlatın ve "GEÇİCİ BAŞLAT" butonuna basarak tüneli aktif hale getirin. Sisteminiz otomatik olarak konfigüre edilecektir.


⚖️ Yasal Uyarı

Bu araç sadece eğitim ve ağ güvenlik testleri (penetrasyon testleri) amacıyla geliştirilmiştir. Uygulamanın kullanımından doğabilecek tüm yasal sorumluluk son kullanıcıya aittir. Geliştirici, kötüye kullanım durumunda sorumluluk kabul etmez.
