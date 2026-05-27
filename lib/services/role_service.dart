import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class RoleService {
  static final RoleService instance = RoleService._internal();
  RoleService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  /// Reads roles from JWT Claims, with a fallback to RTDB if claims are stale or missing.
  Future<Map<String, bool>> getRoles({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {};
    }

    try {
      final tokenResult = await user.getIdTokenResult(forceRefresh);
      final claims = tokenResult.claims;
      final rolesClaim = claims?['roles'];

      if (rolesClaim is Map) {
        final rolesMap = Map<String, bool>.from(
          rolesClaim.map((key, value) => MapEntry(key.toString(), value == true)),
        );
        if (rolesMap.isNotEmpty) {
          return rolesMap;
        }
      }
    } catch (e) {
      print("Error fetching roles from JWT claims: $e");
    }

    // Fallback to RTDB
    return await getRolesFromDatabase(user.uid);
  }

  /// Reads roles directly from RTDB
  Future<Map<String, bool>> getRolesFromDatabase(String uid) async {
    try {
      final snapshot = await _rtdb.ref('users').child(uid).child('roles').get();
      if (snapshot.exists && snapshot.value is Map) {
        return Map<String, bool>.from(
          (snapshot.value as Map).map((key, value) => MapEntry(key.toString(), value == true)),
        );
      }
    } catch (e) {
      print("Error fetching roles from database: $e");
    }
    return {};
  }

  /// Reads activeRole from RTDB
  Future<String?> getActiveRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _rtdb.ref('users').child(user.uid).child('activeRole').get();
      return snapshot.value?.toString();
    } catch (e) {
      print("Error fetching activeRole: $e");
      return null;
    }
  }

  /// Switches activeRole in RTDB
  Future<void> switchActiveRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User is not authenticated");

    final roles = await getRoles();
    if (roles[role] != true) {
      throw Exception("User does not possess the '$role' role. Unauthorized switch.");
    }

    try {
      await _rtdb.ref('users').child(user.uid).child('activeRole').set(role);
    } catch (e) {
      throw Exception("Failed to update active role: $e");
    }
  }

  /// Validates role access helper
  Future<bool> hasRole(String role) async {
    final roles = await getRoles();
    return roles[role] == true;
  }

  Future<bool> canUseCustomerApp() async {
    final roles = await getRoles();
    return roles['customer'] == true || roles['merchant'] == true;
  }

  Future<bool> canUseVendorApp() async {
    final roles = await getRoles();
    return roles['merchant'] == true;
  }

  Future<void> switchRoleAndLaunchApp(String targetRole) async {
    await switchActiveRole(targetRole);

    final String targetUrl = targetRole == 'merchant'
        ? 'https://vendor.localvyapari.com/switch-role'
        : 'https://app.localvyapari.com/switch-role';

    final String detectScheme = targetRole == 'merchant' 
        ? 'localvyaparivendor://' 
        : 'localvyapari://';

    final String storeUrl = targetRole == 'merchant'
        ? 'https://play.google.com/store/apps/details?id=com.localvyapari.vendor'
        : 'https://play.google.com/store/apps/details?id=com.localvyapari.customer';

    try {
      if (await canLaunchUrl(Uri.parse(detectScheme))) {
        await launchUrl(Uri.parse(targetUrl), mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      throw Exception("Error switching app: $e");
    }
  }
}
