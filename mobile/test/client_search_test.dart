// Every client search box (Clients, staff Clients, Dues, the Billing client
// picker) uses customerMatchesQuery. These are the ways a person at the
// counter actually types a name or a number.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/client_search.dart';
import 'package:mobile/data/models.dart';

Customer _c(String name, String phone, {String? email}) =>
    Customer(id: name, name: name, phone: phone, email: email, isVip: false, branchId: 'b');

void main() {
  final priya = _c('Priya Kumari Sharma', '9876500002', email: 'priya@mail.com');
  final plus = _c('Ravi Kumar', '+91 98765-43210');

  test('empty search shows everyone', () {
    expect(customerMatchesQuery(priya, '   '), isTrue);
  });

  test('name words match in any order and in part', () {
    expect(customerMatchesQuery(priya, 'priya'), isTrue);
    expect(customerMatchesQuery(priya, 'SHARMA'), isTrue);
    expect(customerMatchesQuery(priya, 'sharma priya'), isTrue);
    expect(customerMatchesQuery(priya, 'pri sha'), isTrue);
    expect(customerMatchesQuery(priya, 'priya verma'), isFalse);
  });

  test('a mobile number matches however it is spaced or prefixed', () {
    expect(customerMatchesQuery(priya, '9876500002'), isTrue);
    expect(customerMatchesQuery(priya, '98765 00002'), isTrue);
    expect(customerMatchesQuery(priya, '+91 9876500002'), isTrue);
    expect(customerMatchesQuery(priya, '919876500002'), isTrue);
    expect(customerMatchesQuery(plus, '9876543210'), isTrue);
  });

  test('the last few digits are enough', () {
    expect(customerMatchesQuery(priya, '0002'), isTrue);
    expect(customerMatchesQuery(plus, '3210'), isTrue);
    expect(customerMatchesQuery(priya, '3210'), isFalse);
  });

  test('email still works', () {
    expect(customerMatchesQuery(priya, 'priya@mail'), isTrue);
  });
}
