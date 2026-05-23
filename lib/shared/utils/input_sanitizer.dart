class InputSanitizer {
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  /// Validates email and returns a warning message if invalid, or null if valid.
  static String? validateEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return 'Email cannot be empty.';
    }
    if (trimmed.length > 254) {
      return 'Email is too long.';
    }
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Sanitizes text input by removing dangerous characters and tags (HTML, scripts).
  static String sanitizeText(String text) {
    var result = text.trim();
    
    // Remove script tags and style tags
    result = result.replaceAll(RegExp(r'<script[^>]*?>[\s\S]*?<\/script>'), '');
    result = result.replaceAll(RegExp(r'<style[^>]*?>[\s\S]*?<\/style>'), '');
    
    // Remove HTML tags
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');
    
    return result;
  }

  /// Validates password constraints (e.g. length limits).
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (password.length > 64) {
      return 'Password cannot be longer than 64 characters.';
    }
    return null;
  }
}
