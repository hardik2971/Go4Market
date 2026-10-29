import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/features/common/version_gate.dart';

void main() {
  test('compareVersions orders dotted versions', () {
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
    expect(compareVersions('2.0.0+5', '2.0.0'), 0);
    expect(compareVersions('1.3', '1.2.9'), greaterThan(0));
  });
}
