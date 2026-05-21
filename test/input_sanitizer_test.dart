import 'package:flutter_test/flutter_test.dart';
import 'package:local_vyapari_user/shared/utils/input_sanitizer.dart';

void main() {
  group('InputSanitizer Validation Tests', () {
    test('validateEmail checks standard email criteria', () {
      expect(InputSanitizer.validateEmail(''), 'Email cannot be empty.');
      expect(InputSanitizer.validateEmail('a' * 255 + '@gmail.com'), 'Email is too long.');
      expect(InputSanitizer.validateEmail('invalid-email'), 'Please enter a valid email address.');
      expect(InputSanitizer.validateEmail('test@example.com'), isNull);
    });

    test('validatePassword checks length bounds', () {
      expect(InputSanitizer.validatePassword(''), 'Password cannot be empty.');
      expect(InputSanitizer.validatePassword('12345'), 'Password must be at least 6 characters.');
      expect(InputSanitizer.validatePassword('a' * 65), 'Password cannot be longer than 64 characters.');
      expect(InputSanitizer.validatePassword('validpassword123'), isNull);
    });

    test('sanitizeText strips tags and clean input strings', () {
      expect(InputSanitizer.sanitizeText('Hello <script>alert("hack")</script> World'), 'Hello  World');
      expect(InputSanitizer.sanitizeText('<p>Shop details paragraph</p>'), 'Shop details paragraph');
      expect(InputSanitizer.sanitizeText('  Leading and trailing space  '), 'Leading and trailing space');
    });
  });
}
