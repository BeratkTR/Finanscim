import 'dart:async';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:uuid/uuid.dart';
import 'db_helper.dart';
import '../models/transaction.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _transactionAddedController = StreamController<Transaction>.broadcast();
  Stream<Transaction> get onTransactionAdded => _transactionAddedController.stream;

  StreamSubscription<ServiceNotificationEvent>? _subscription;

  void startListening() async {
    bool isPermissionGranted = await NotificationListenerService.isPermissionGranted();
    if (!isPermissionGranted) {
      print("Notification permission not granted");
      return;
    }

    await _subscription?.cancel();
    _subscription = NotificationListenerService.notificationsStream.listen((event) {
      _handleNotification(event);
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }

  void _handleNotification(ServiceNotificationEvent event) async {
    // Yapı Kredi paket adları: com.ykb.android (Bireysel), com.ykb.android.kurumsal (Kurumsal)
    if (event.packageName != "com.ykb.android" && event.packageName != "com.ykb.android.kurumsal") return;

    final String? content = event.content;
    if (content == null) return;

    print("Yapı Kredi Bildirimi Yakalandı: $content");

    // Tutarı ayıkla (Örn: 1.250,50 TL veya 1250.50 TL)
    final amountRegExp = RegExp(r'(\d+[\.,]?\d*)\s?TL');
    final match = amountRegExp.firstMatch(content);
    
    if (match != null) {
      String amountStr = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      double? amount = double.tryParse(amountStr);

      if (amount != null) {
        // İşlem tipini belirle (Harcama genelde "yapılmıştır", "onaylandı" gibi kelimeler içerir)
        // Eğer içerikte "iade" veya "gelen" gibi kelimeler varsa gelir olabilir, ama biz şimdilik harcama odaklı gidelim.
        // Genelde banka bildirimleri harcamadır.
        
        String transactionTitle = "Yapı Kredi Harcaması";
        String lowerContent = content.toLowerCase();

        if (lowerContent.contains("harcaması yapılmıştır")) {
           final parts = content.split(RegExp(r' tutarında ', caseSensitive: false));
           if (parts.length > 1) {
             final detailParts = parts[1].split(RegExp(r' harcaması', caseSensitive: false));
             if (detailParts.isNotEmpty) {
               transactionTitle = detailParts[0].trim();
             }
           }
        } else if (lowerContent.contains("işleminiz gerçekleştirilmiştir")) {
           transactionTitle = "Yapı Kredi İşlemi";
        } else if (lowerContent.contains(" nolu kartınız ile ")) {
           // Örn: ... nolu kartınız ile 100 TL tutarında Starbucks harcaması yapılmıştır.
           final parts = content.split(" nolu kartınız ile ");
           if (parts.length > 1) {
              transactionTitle = "Kart Harcaması";
           }
        }

        final transaction = Transaction(
          id: const Uuid().v4(),
          title: transactionTitle,
          amount: amount,
          date: DateTime.now(),
          color: 0xFFF44336, // Harcamalar için kırmızımsı (örnek)
        );

        await DbHelper.instance.insertTransaction(transaction);
        _transactionAddedController.add(transaction);
        print("Otomatik işlem eklendi: $transactionTitle - $amount TL");
      }
    }
  }
}
