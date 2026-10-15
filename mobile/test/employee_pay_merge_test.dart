import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/firebase/firestore_models.dart';

void main() {
  const payDoc = FSEmployeePay(baseSalary: 20000, serviceCommissionPct: 10, productCommissionPct: 5);

  test('moved salon: pay comes from the employeePay doc', () {
    final p = mergePay(legacy: const {}, payDoc: payDoc);
    expect(p.baseSalary, 20000);
    expect(p.serviceCommissionPct, 10);
    expect(p.productCommissionPct, 5);
  });

  test('not moved yet: pay comes from the roster doc', () {
    final p = mergePay(legacy: const {'baseSalary': 15000, 'serviceCommissionPct': 8, 'productCommissionPct': 3});
    expect(p.baseSalary, 15000);
    expect(p.serviceCommissionPct, 8);
    expect(p.productCommissionPct, 3);
  });

  test('a field left on the roster doc (old app edit) wins, field by field', () {
    final p = mergePay(legacy: const {'baseSalary': 25000}, payDoc: payDoc);
    expect(p.baseSalary, 25000);
    expect(p.serviceCommissionPct, 10);
    expect(p.productCommissionPct, 5);
  });

  test('no pay anywhere reads as zero', () {
    final p = mergePay(legacy: const {});
    expect(p.baseSalary, 0);
    expect(p.serviceCommissionPct, 0);
    expect(p.productCommissionPct, 0);
  });
}
