import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class PrinterService {
  final int _printerPort = 9100;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _defaultIp = '192.168.1.200';

  Future<String> getStoredIp() async {
    try {
      final doc = await _db.collection('config').doc('printer').get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('ip')) {
        return doc.data()!['ip'] as String;
      }
    } catch (e) {
      print("Error fetching printer IP: $e");
    }
    return _defaultIp;
  }

  Future<void> savePrinterIp(String ip) async {
    await _db.collection('config').doc('printer').set({'ip': ip});
  }

  Future<String> printReceipt(OrderModel order, double total, Map<String, double> priceMap) async {
    Socket? socket;
    try {
      final printerIp = await getStoredIp();
      print("Attempting to connect to $printerIp:$_printerPort...");

      socket = await Socket.connect(printerIp, _printerPort, timeout: const Duration(seconds: 3));
      print("Connected to printer!");

      final List<int> bytes = [];

      bytes.addAll([0x1B, 0x40]);
      bytes.addAll([0x1B, 0x61, 0x01]);

      try {
        final ByteData data = await rootBundle.load('assets/images/Logo_Panzon_BN.png');
        final Uint8List imgBytes = data.buffer.asUint8List();
        final img.Image? originalImage = img.decodeImage(imgBytes);

        if (originalImage != null) {
          final img.Image resized = img.copyResize(originalImage, width: 350);
          bytes.addAll(_generatorImage(resized));
          bytes.addAll(_utf8("\n"));
        }
      } catch (e) {
        print("Error processing logo: $e");
        bytes.addAll(_utf8("[EL PANZON]\n"));
      }

      bytes.addAll([0x1D, 0x21, 0x11]);
      bytes.addAll(_utf8("EL PANZON\n"));
      bytes.addAll([0x1D, 0x21, 0x00]);

      bytes.addAll(_utf8("Tacos & Bebidas\n"));
      bytes.addAll(_utf8("--------------------------------\n"));

      bytes.addAll([0x1B, 0x61, 0x00]);

      String id = order.tableNumber == 0
          ? "Para Llevar: ${order.customerName ?? 'Cliente'}"
          : "Mesa: ${order.tableNumber}";

      bytes.addAll(_utf8("Fecha: ${_formatDate(DateTime.now())}\n"));
      bytes.addAll(_utf8("Orden: #${order.orderNumber}\n"));
      bytes.addAll(_utf8("$id\n"));
      bytes.addAll(_utf8("--------------------------------\n"));

      // Print items per person if available
      if (order.people.isNotEmpty) {
        order.people.forEach((pId, person) {
          // Check if person has ANY served items before printing header
          bool hasItems = person.items.any((i) => (i.extras['served'] ?? 0) > 0 || i.name == 'Desechables');
          if (hasItems) {
            bytes.addAll(_utf8("-- ${person.name} --\n"));
            for (var item in person.items) {
               // Only print served items (Handle Desechables specially)
               int served = item.extras['served'] ?? 0;
               if (item.name == 'Desechables') served = item.quantity;

               if (served > 0) {
                 double price = priceMap[item.name] ?? 0.0;
                 double lineTotal = price * served;
                 bytes.addAll(_utf8(_formatLineItem(served, item.name, lineTotal)));
               }
            }
            bytes.addAll(_utf8("\n"));
          }
        });
      } else {
        // Fallback for legacy orders
        order.tacoCounts.forEach((name, qty) {
           double price = priceMap[name] ?? 0.0;
           double lineTotal = price * qty;
           bytes.addAll(_utf8(_formatLineItem(qty, name, lineTotal)));
        });
        order.simpleExtraCounts.forEach((name, qty) {
           double price = priceMap[name] ?? 0.0;
           double lineTotal = price * qty;
           bytes.addAll(_utf8(_formatLineItem(qty, name, lineTotal)));
        });
        order.sodaCounts.forEach((name, temps) {
          int qty = (temps['Frío'] ?? 0) + (temps['Al Tiempo'] ?? 0);
          if (qty > 0) {
             double price = priceMap[name] ?? 0.0;
             double lineTotal = price * qty;
             bytes.addAll(_utf8(_formatLineItem(qty, name, lineTotal)));
          }
        });
      }

      bytes.addAll(_utf8("--------------------------------\n"));

      bytes.addAll([0x1B, 0x61, 0x02]);
      bytes.addAll([0x1D, 0x21, 0x01]);
      bytes.addAll(_utf8("TOTAL: \$${total.toStringAsFixed(2)}\n"));
      bytes.addAll([0x1D, 0x21, 0x00]);

      bytes.addAll([0x1B, 0x61, 0x01]);
      bytes.addAll(_utf8("\n"));

      try {
        final ByteData footerData = await rootBundle.load('assets/images/Panzon_BN_visita.png');
        final Uint8List footerBytes = footerData.buffer.asUint8List();
        final img.Image? footerImage = img.decodeImage(footerBytes);

        if (footerImage != null) {
          final img.Image resizedFooter = img.copyResize(footerImage, width: 350);
          bytes.addAll(_generatorImage(resizedFooter));
        }
      } catch (e) {
        print("Error processing footer image: $e");
      }

      bytes.addAll(_utf8("\n\n\n"));
      bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

      socket.add(Uint8List.fromList(bytes));
      await socket.flush();

      return "Success";

    } catch (e) {
      print("Error printing: $e");
      return "Error: $e";
    } finally {
      await socket?.close();
    }
  }

  List<int> _generatorImage(img.Image image) {
    List<int> bytes = [];
    final img.Image gray = img.grayscale(image);
    final int width = gray.width;
    final int height = gray.height;
    final int xL = (width + 7) ~/ 8;

    bytes.addAll([0x1D, 0x76, 0x30, 0x00]);
    bytes.addAll([xL % 256, xL ~/ 256]);
    bytes.addAll([height % 256, height ~/ 256]);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x += 8) {
        int byte = 0;
        for (int b = 0; b < 8; b++) {
          if (x + b < width) {
            final pixel = gray.getPixel(x + b, y);
            // FIXED: Use direct property access for image v4
            final lum = pixel.luminance;
            final alpha = pixel.a;

            if (alpha > 128 && lum < 128) {
              byte |= (1 << (7 - b));
            }
          }
        }
        bytes.add(byte);
      }
    }
    return bytes;
  }

  List<int> _utf8(String text) {
    var clean = text
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u')
        .replaceAll('ñ', 'n').replaceAll('Ñ', 'N');
    return clean.codeUnits;
  }

  String _formatLineItem(int qty, String name, double total) {
    String q = "$qty x ";
    // Max width 32 chars
    // specific layout: "2 x Taco Suadero       $30.00"
    
    String priceStr = "\$${total.toStringAsFixed(2)}";
    int priceLen = priceStr.length;
    
    // Remaining space for Name (including Qty prefix)
    int maxNameLen = 32 - priceLen - 1; // -1 for at least one space
    
    String leftSide = "$q$name";
    if (leftSide.length > maxNameLen) {
      leftSide = leftSide.substring(0, maxNameLen);
    }
    
    // Calculate padding
    int padding = 32 - leftSide.length - priceLen;
    String spaces = " " * (padding > 0 ? padding : 1);
    
    return "$leftSide$spaces$priceStr\n";
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}";
  }
}