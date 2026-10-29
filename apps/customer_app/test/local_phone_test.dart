import 'package:customer_app/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localIndian strips +91 so "+91 " prefixed fields validate', () {
    expect(Validators.localIndian('+919999900001'), '9999900001');
    expect(Validators.localIndian('919876543210'), '9876543210');
    expect(Validators.localIndian('09876543210'), '9876543210');
    expect(Validators.localIndian('9876543210'), '9876543210');
    expect(Validators.localIndian(null), '');
    expect(Validators.localIndian('+14155550123'), '+14155550123');
  });
}
