import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_vyapari_user/features/location/models/location_result.dart';
import 'package:local_vyapari_user/services/cache/security_helper.dart';

class LocationCache {
  static Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  static Future<void> saveActiveLocation(LocationResult location) async {
    try {
      final file = await _getFile('active_location.json');
      final jsonString = json.encode(location.toMap());
      final encryptedString = await SecurityHelper.encryptData(jsonString);
      await file.writeAsString(encryptedString);
    } catch (e) {
      debugPrint('Error saving active location locally: $e');
    }
  }

  static Future<LocationResult?> getActiveLocation() async {
    try {
      final file = await _getFile('active_location.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return null;
        
        String decryptedContent;
        try {
          decryptedContent = await SecurityHelper.decryptData(content);
        } catch (e) {
          // If decryption fails (e.g. key changed or legacy unencrypted file), delete the file
          await file.delete();
          return null;
        }

        final map = json.decode(decryptedContent) as Map<String, dynamic>;
        return LocationResult.fromMap(map);
      }
    } catch (e) {
      debugPrint('Error loading active location locally: $e');
    }
    return null;
  }

  static Future<void> saveRecentLocation(LocationResult location) async {
    try {
      final recent = await getRecentLocations();
      
      // Remove if already exists (to push to top/first)
      recent.removeWhere((loc) => loc.geohash == location.geohash);
      recent.insert(0, location);
      
      // Limit to 5 items
      if (recent.length > 5) {
        recent.removeRange(5, recent.length);
      }

      final file = await _getFile('recent_locations.json');
      final list = recent.map((l) => l.toMap()).toList();
      final jsonString = json.encode(list);
      final encryptedString = await SecurityHelper.encryptData(jsonString);
      await file.writeAsString(encryptedString);
    } catch (e) {
      debugPrint('Error saving recent location locally: $e');
    }
  }

  static Future<List<LocationResult>> getRecentLocations() async {
    try {
      final file = await _getFile('recent_locations.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];
        
        String decryptedContent;
        try {
          decryptedContent = await SecurityHelper.decryptData(content);
        } catch (e) {
          // If decryption fails (e.g. key changed or legacy unencrypted file), delete the file
          await file.delete();
          return [];
        }

        final list = json.decode(decryptedContent) as List<dynamic>;
        return list
            .map((item) => LocationResult.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading recent locations locally: $e');
    }
    return [];
  }
}
