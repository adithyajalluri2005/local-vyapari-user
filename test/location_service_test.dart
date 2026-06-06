import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:local_vyapari_user/services/location/location_service.dart';

class MockClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) sendHandler;
  MockClient(this.sendHandler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return sendHandler(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: 'GEOAPIFY_API_KEY=mock_key\n');
  });

  group('LocationService HTTP Retry and Autocomplete tests', () {
    test('searchAutocomplete returns parsed features on 200 OK', () async {
      final mockClient = MockClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(json.encode({
            'features': [
              {
                'properties': {
                  'name': 'Tanuku',
                  'formatted': 'Tanuku, AP, India',
                  'lat': 16.751491,
                  'lon': 81.687432,
                }
              }
            ]
          }))),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchAutocomplete('Tanuku');

      expect(results, hasLength(1));
      expect(results.first.name, 'Tanuku');
      expect(results.first.latitude, 16.751491);
      expect(results.first.longitude, 81.687432);
    });

    test('searchAutocomplete retries on 500 internal server error and then succeeds', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.StreamedResponse(
            Stream.value(utf8.encode('Server Error')),
            500,
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(json.encode({
            'features': [
              {
                'properties': {
                  'name': 'Bhimavaram',
                  'formatted': 'Bhimavaram, AP, India',
                  'lat': 16.544893,
                  'lon': 81.522234,
                }
              }
            ]
          }))),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchAutocomplete('Bhimavaram');

      expect(callCount, 2);
      expect(results, hasLength(1));
      expect(results.first.name, 'Bhimavaram');
    });

    test('searchAutocomplete does not retry on 400 Bad Request client error', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.StreamedResponse(
          Stream.value(utf8.encode('Bad Request')),
          400,
        );
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchAutocomplete('Tanuku');

      expect(callCount, 1);
      expect(results, isEmpty);
    });

    test('searchAutocomplete retries on 429 Too Many Requests rate limit', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount < 3) {
          return http.StreamedResponse(
            Stream.value(utf8.encode('Rate Limited')),
            429,
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(json.encode({
            'features': [
              {
                'properties': {
                  'name': 'Palakollu',
                  'formatted': 'Palakollu, AP, India',
                  'lat': 16.5200,
                  'lon': 81.7300,
                }
              }
            ]
          }))),
          200,
        );
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchAutocomplete('Palakollu');

      expect(callCount, 3);
      expect(results, hasLength(1));
      expect(results.first.name, 'Palakollu');
    });
  });
}
