import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- MODELS ---

class Branch {
  final String id;
  final String name;
  final String manager;
  final double monthlyRevenue;
  final int customerCount;
  final double performanceScore;
  final String address;

  Branch({
    required this.id,
    required this.name,
    required this.manager,
    required this.monthlyRevenue,
    required this.customerCount,
    required this.performanceScore,
    required this.address,
  });
}

class Visit {
  final String date;
  final String serviceName;
  final double amount;
  final double rating;

  Visit({
    required this.date,
    required this.serviceName,
    required this.amount,
    required this.rating,
  });
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String avatarUrl;
  final int visitCount;
  final double totalSpent;
  final String status; // 'Green', 'Yellow', 'Red'
  final String lastVisitDate;
  final List<String> servicesTaken;
  final List<Visit> visitHistory;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.avatarUrl,
    required this.visitCount,
    required this.totalSpent,
    required this.status,
    required this.lastVisitDate,
    required this.servicesTaken,
    required this.visitHistory,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    int? visitCount,
    double? totalSpent,
    String? status,
    String? lastVisitDate,
    List<String>? servicesTaken,
    List<Visit>? visitHistory,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      visitCount: visitCount ?? this.visitCount,
      totalSpent: totalSpent ?? this.totalSpent,
      status: status ?? this.status,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      servicesTaken: servicesTaken ?? this.servicesTaken,
      visitHistory: visitHistory ?? this.visitHistory,
    );
  }
}

class Employee {
  final String id;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String avatarUrl;
  final double attendanceRate;
  final double performanceRate;
  final double currentSalary;
  final double commissionRate;
  final double dailyTarget;
  final double completedTarget;
  final String status; // 'Present', 'Absent', 'Late'

  Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.attendanceRate,
    required this.performanceRate,
    required this.currentSalary,
    required this.commissionRate,
    required this.dailyTarget,
    required this.completedTarget,
    required this.status,
  });

  Employee copyWith({
    String? id,
    String? name,
    String? role,
    String? email,
    String? phone,
    String? avatarUrl,
    double? attendanceRate,
    double? performanceRate,
    double? currentSalary,
    double? commissionRate,
    double? dailyTarget,
    double? completedTarget,
    String? status,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      attendanceRate: attendanceRate ?? this.attendanceRate,
      performanceRate: performanceRate ?? this.performanceRate,
      currentSalary: currentSalary ?? this.currentSalary,
      commissionRate: commissionRate ?? this.commissionRate,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      completedTarget: completedTarget ?? this.completedTarget,
      status: status ?? this.status,
    );
  }
}

class Bill {
  final String id;
  final String billNo;
  final String customerName;
  final List<String> services;
  final double discountPercent;
  final double discountAmount;
  final double subtotal;
  final double totalAmount;
  final String paymentMethod; // 'Cash', 'UPI', 'Pending'
  final String date;

  Bill({
    required this.id,
    required this.billNo,
    required this.customerName,
    required this.services,
    required this.discountPercent,
    required this.discountAmount,
    required this.subtotal,
    required this.totalAmount,
    required this.paymentMethod,
    required this.date,
  });
}

class InventoryProduct {
  final String id;
  final String name;
  final String category;
  final int currentStock;
  final int minStockAlertThreshold;
  final String unit;

  InventoryProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.minStockAlertThreshold,
    required this.unit,
  });

  InventoryProduct copyWith({
    String? id,
    String? name,
    String? category,
    int? currentStock,
    int? minStockAlertThreshold,
    String? unit,
  }) {
    return InventoryProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      currentStock: currentStock ?? this.currentStock,
      minStockAlertThreshold: minStockAlertThreshold ?? this.minStockAlertThreshold,
      unit: unit ?? this.unit,
    );
  }
}

class Expense {
  final String id;
  final String category; // 'Tea', 'Cleaning', 'Repair', 'Maintenance', 'Electricity', 'Miscellaneous'
  final String description;
  final double amount;
  final String date;

  Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
  });
}

class DiscountRequest {
  final String id;
  final String customerName;
  final String employeeName;
  final double requestedDiscountPercent;
  final double originalAmount;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final String date;

  DiscountRequest({
    required this.id,
    required this.customerName,
    required this.employeeName,
    required this.requestedDiscountPercent,
    required this.originalAmount,
    required this.status,
    required this.date,
  });

  DiscountRequest copyWith({
    String? id,
    String? customerName,
    String? employeeName,
    double? requestedDiscountPercent,
    double? originalAmount,
    String? status,
    String? date,
  }) {
    return DiscountRequest(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      employeeName: employeeName ?? this.employeeName,
      requestedDiscountPercent: requestedDiscountPercent ?? this.requestedDiscountPercent,
      originalAmount: originalAmount ?? this.originalAmount,
      status: status ?? this.status,
      date: date ?? this.date,
    );
  }
}

// --- STATE REPRESENTATION ---

class SalonState {
  final List<Branch> branches;
  final List<Employee> employees;
  final List<Customer> customers;
  final List<Bill> bills;
  final List<InventoryProduct> inventory;
  final List<Expense> expenses;
  final List<DiscountRequest> discountRequests;
  
  // Dashboard Live Stats
  final double todaySales;
  final double weeklySales;
  final double monthlySales;
  final double cashCollected;
  final double upiCollected;
  final double pendingPayments;
  final int todayCustomersCount;
  final int todayAttendanceCount;
  
  // Mock display numbers (for higher visual fidelity)
  final int totalCustomersDisplayCount;
  final int totalEmployeesDisplayCount;
  final int totalBranchCount;

  SalonState({
    required this.branches,
    required this.employees,
    required this.customers,
    required this.bills,
    required this.inventory,
    required this.expenses,
    required this.discountRequests,
    required this.todaySales,
    required this.weeklySales,
    required this.monthlySales,
    required this.cashCollected,
    required this.upiCollected,
    required this.pendingPayments,
    required this.todayCustomersCount,
    required this.todayAttendanceCount,
    required this.totalCustomersDisplayCount,
    required this.totalEmployeesDisplayCount,
    required this.totalBranchCount,
  });

  SalonState copyWith({
    List<Branch>? branches,
    List<Employee>? employees,
    List<Customer>? customers,
    List<Bill>? bills,
    List<InventoryProduct>? inventory,
    List<Expense>? expenses,
    List<DiscountRequest>? discountRequests,
    double? todaySales,
    double? weeklySales,
    double? monthlySales,
    double? cashCollected,
    double? upiCollected,
    double? pendingPayments,
    int? todayCustomersCount,
    int? todayAttendanceCount,
    int? totalCustomersDisplayCount,
    int? totalEmployeesDisplayCount,
    int? totalBranchCount,
  }) {
    return SalonState(
      branches: branches ?? this.branches,
      employees: employees ?? this.employees,
      customers: customers ?? this.customers,
      bills: bills ?? this.bills,
      inventory: inventory ?? this.inventory,
      expenses: expenses ?? this.expenses,
      discountRequests: discountRequests ?? this.discountRequests,
      todaySales: todaySales ?? this.todaySales,
      weeklySales: weeklySales ?? this.weeklySales,
      monthlySales: monthlySales ?? this.monthlySales,
      cashCollected: cashCollected ?? this.cashCollected,
      upiCollected: upiCollected ?? this.upiCollected,
      pendingPayments: pendingPayments ?? this.pendingPayments,
      todayCustomersCount: todayCustomersCount ?? this.todayCustomersCount,
      todayAttendanceCount: todayAttendanceCount ?? this.todayAttendanceCount,
      totalCustomersDisplayCount: totalCustomersDisplayCount ?? this.totalCustomersDisplayCount,
      totalEmployeesDisplayCount: totalEmployeesDisplayCount ?? this.totalEmployeesDisplayCount,
      totalBranchCount: totalBranchCount ?? this.totalBranchCount,
    );
  }
}

// --- RIVERPOD NOTIFIER ---

class SalonStateNotifier extends Notifier<SalonState> {
  @override
  SalonState build() {
    return SalonState(
      branches: _initBranches(),
      employees: _initEmployees(),
      customers: _initCustomers(),
      bills: _initBills(),
      inventory: _initInventory(),
      expenses: _initExpenses(),
      discountRequests: _initDiscountRequests(),
      todaySales: 34250.0,
      weeklySales: 215000.0,
      monthlySales: 924000.0,
      cashCollected: 12150.0,
      upiCollected: 18600.0,
      pendingPayments: 3500.0,
      todayCustomersCount: 14,
      todayAttendanceCount: 8,
      totalCustomersDisplayCount: 1250,
      totalEmployeesDisplayCount: 25,
      totalBranchCount: 3,
    );
  }

  // --- ACTIONS ---

  void addCustomer(String name, String phone, String email, String status) {
    final newCust = Customer(
      id: 'cust_${state.customers.length + 1}',
      name: name,
      phone: phone,
      email: email.isEmpty ? '${name.toLowerCase().replaceAll(' ', '')}@demo.com' : email,
      avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=$name',
      visitCount: 1,
      totalSpent: 0.0,
      status: status,
      lastVisitDate: 'Today',
      servicesTaken: ['Consultation'],
      visitHistory: [
        Visit(date: 'Today', serviceName: 'Consultation', amount: 0.0, rating: 5.0)
      ],
    );

    state = state.copyWith(
      customers: [newCust, ...state.customers],
      totalCustomersDisplayCount: state.totalCustomersDisplayCount + 1,
      todayCustomersCount: state.todayCustomersCount + 1,
    );
  }

  void updateEmployeeAttendance(String employeeId, String status) {
    int attendanceCountDelta = 0;
    final updatedEmployees = state.employees.map((emp) {
      if (emp.id == employeeId) {
        final oldStatus = emp.status;
        if (oldStatus != 'Present' && status == 'Present') {
          attendanceCountDelta = 1;
        } else if (oldStatus == 'Present' && status != 'Present') {
          attendanceCountDelta = -1;
        }
        return emp.copyWith(status: status);
      }
      return emp;
    }).toList();

    state = state.copyWith(
      employees: updatedEmployees,
      todayAttendanceCount: state.todayAttendanceCount + attendanceCountDelta,
    );
  }

  void addEmployee(
    String name,
    String role,
    String email,
    String phone,
    double currentSalary,
    double commissionRate,
    double dailyTarget,
  ) {
    final newEmp = Employee(
      id: 'emp_${state.employees.length + 1}',
      name: name,
      role: role.isEmpty ? 'Hair Stylist' : role,
      email: email,
      phone: phone.isEmpty ? '+91 98765 43210' : phone,
      avatarUrl: '',
      attendanceRate: 100.0,
      performanceRate: 90.0,
      currentSalary: currentSalary,
      commissionRate: commissionRate,
      dailyTarget: dailyTarget,
      completedTarget: 0.0,
      status: 'Present',
    );

    state = state.copyWith(
      employees: [newEmp, ...state.employees],
      totalEmployeesDisplayCount: state.totalEmployeesDisplayCount + 1,
    );
  }

  void createBill({
    required String customerName,
    required List<String> services,
    required double subtotal,
    required double discountPercent,
    required double discountAmount,
    required double totalAmount,
    required String paymentMethod,
  }) {
    final billId = state.bills.length + 1;
    final newBill = Bill(
      id: 'bill_$billId',
      billNo: 'TXN${1000 + billId}',
      customerName: customerName,
      services: services,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      subtotal: subtotal,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      date: 'Today, ${_formatCurrentTime()}',
    );

    double newCash = state.cashCollected;
    double newUpi = state.upiCollected;
    double newPending = state.pendingPayments;

    if (paymentMethod == 'Cash') {
      newCash += totalAmount;
    } else if (paymentMethod == 'UPI') {
      newUpi += totalAmount;
    } else {
      newPending += totalAmount;
    }

    // Update customer stats if customer exists
    final updatedCustomers = state.customers.map((c) {
      if (c.name.toLowerCase() == customerName.toLowerCase()) {
        return c.copyWith(
          visitCount: c.visitCount + 1,
          totalSpent: c.totalSpent + totalAmount,
          lastVisitDate: 'Today',
          servicesTaken: {...c.servicesTaken, ...services}.toList(),
          visitHistory: [
            Visit(date: 'Today', serviceName: services.join(', '), amount: totalAmount, rating: 5.0),
            ...c.visitHistory,
          ],
        );
      }
      return c;
    }).toList();

    state = state.copyWith(
      bills: [newBill, ...state.bills],
      customers: updatedCustomers,
      todaySales: state.todaySales + totalAmount,
      weeklySales: state.weeklySales + totalAmount,
      monthlySales: state.monthlySales + totalAmount,
      cashCollected: newCash,
      upiCollected: newUpi,
      pendingPayments: newPending,
      todayCustomersCount: state.todayCustomersCount + 1,
    );
  }

  void approveDiscountRequest(String requestId) {
    double billAmountAdjustment = 0;
    String paymentMethod = 'UPI';
    String customerName = '';

    final updatedRequests = state.discountRequests.map((req) {
      if (req.id == requestId) {
        billAmountAdjustment = req.originalAmount * (1 - (req.requestedDiscountPercent / 100));
        customerName = req.customerName;
        return req.copyWith(status: 'Approved');
      }
      return req;
    }).toList();

    state = state.copyWith(
      discountRequests: updatedRequests,
    );

    // Also automatically trigger creation of the bill for this discount
    createBill(
      customerName: customerName.isNotEmpty ? customerName : 'Walk-in Customer',
      services: ['Premium Haircut & Styling (Discount Approved)'],
      subtotal: billAmountAdjustment / 0.8, // back-calculated subtotal approx
      discountPercent: reqDiscountPercent(requestId),
      discountAmount: (billAmountAdjustment / 0.8) - billAmountAdjustment,
      totalAmount: billAmountAdjustment,
      paymentMethod: paymentMethod,
    );
  }

  double reqDiscountPercent(String id) {
    for (var r in state.discountRequests) {
      if (r.id == id) return r.requestedDiscountPercent;
    }
    return 0.0;
  }

  void rejectDiscountRequest(String requestId) {
    final updatedRequests = state.discountRequests.map((req) {
      if (req.id == requestId) {
        return req.copyWith(status: 'Rejected');
      }
      return req;
    }).toList();

    state = state.copyWith(
      discountRequests: updatedRequests,
    );
  }

  void updateProductStock(String productId, int newStock) {
    final updatedInventory = state.inventory.map((prod) {
      if (prod.id == productId) {
        return prod.copyWith(currentStock: newStock);
      }
      return prod;
    }).toList();

    state = state.copyWith(
      inventory: updatedInventory,
    );
  }

  void addExpenseItem(String category, String description, double amount) {
    final newExpense = Expense(
      id: 'exp_${state.expenses.length + 1}',
      category: category,
      description: description,
      amount: amount,
      date: 'Today',
    );

    state = state.copyWith(
      expenses: [newExpense, ...state.expenses],
    );
  }

  // --- INITIALIZERS WITH REALISTIC MOCK DATA ---

  List<Branch> _initBranches() {
    return [
      Branch(
        id: 'br_1',
        name: 'Glamour Studio - Downtown',
        manager: 'Marcus Aurelius',
        monthlyRevenue: 520000.0,
        customerCount: 420,
        performanceScore: 94.0,
        address: '102 Main Street, Business District',
      ),
      Branch(
        id: 'br_2',
        name: 'Glamour Studio - Westside',
        manager: 'Diana Prince',
        monthlyRevenue: 480000.0,
        customerCount: 380,
        performanceScore: 88.0,
        address: '404 Ocean Drive, Westside Mall',
      ),
      Branch(
        id: 'br_3',
        name: 'Glamour Studio - Uptown',
        manager: 'Peter Parker',
        monthlyRevenue: 610000.0,
        customerCount: 510,
        performanceScore: 96.0,
        address: '77 Skyview Towers, Uptown Heights',
      ),
    ];
  }

  List<Employee> _initEmployees() {
    return [
      Employee(
        id: 'emp_1',
        name: 'Marcus Aurelius',
        role: 'Salon Manager',
        email: 'marcus@salon.com',
        phone: '+91 98765 43210',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Marcus',
        attendanceRate: 98.0,
        performanceRate: 96.0,
        currentSalary: 65000.0,
        commissionRate: 5.0,
        dailyTarget: 15000.0,
        completedTarget: 14500.0,
        status: 'Present',
      ),
      Employee(
        id: 'emp_2',
        name: 'Elena Rostova',
        role: 'Senior Hair Stylist',
        email: 'elena@salon.com',
        phone: '+91 98765 43211',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Elena',
        attendanceRate: 95.0,
        performanceRate: 92.0,
        currentSalary: 45000.0,
        commissionRate: 15.0,
        dailyTarget: 12000.0,
        completedTarget: 11000.0,
        status: 'Present',
      ),
      Employee(
        id: 'emp_3',
        name: 'Rohan Sharma',
        role: 'Hair Color Expert',
        email: 'rohan@salon.com',
        phone: '+91 98765 43212',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Rohan',
        attendanceRate: 92.0,
        performanceRate: 94.0,
        currentSalary: 42000.0,
        commissionRate: 12.5,
        dailyTarget: 10000.0,
        completedTarget: 8500.0,
        status: 'Late',
      ),
      Employee(
        id: 'emp_4',
        name: 'Priya Patel',
        role: 'Skincare Specialist',
        email: 'priya@salon.com',
        phone: '+91 98765 43213',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Priya',
        attendanceRate: 97.0,
        performanceRate: 95.0,
        currentSalary: 48000.0,
        commissionRate: 10.0,
        dailyTarget: 8000.0,
        completedTarget: 8200.0,
        status: 'Present',
      ),
      Employee(
        id: 'emp_5',
        name: 'Sarah Connor',
        role: 'Nail Artist & Stylist',
        email: 'employee@salon.com',
        phone: '+91 98765 43214',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
        attendanceRate: 94.0,
        performanceRate: 89.0,
        currentSalary: 35000.0,
        commissionRate: 8.0,
        dailyTarget: 100000.0, // Used for Target view: target is 100,000
        completedTarget: 24000.0, // Motivational Card: 24,000 completed
        status: 'Present',
      ),
      Employee(
        id: 'emp_6',
        name: 'Vikram Malhotra',
        role: 'Makeup Artist',
        email: 'vikram@salon.com',
        phone: '+91 98765 43215',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Vikram',
        attendanceRate: 88.0,
        performanceRate: 85.0,
        currentSalary: 40000.0,
        commissionRate: 15.0,
        dailyTarget: 10000.0,
        completedTarget: 6000.0,
        status: 'Absent',
      ),
      Employee(
        id: 'emp_7',
        name: 'Anjali Desai',
        role: 'Junior Stylist',
        email: 'anjali@salon.com',
        phone: '+91 98765 43216',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Anjali',
        attendanceRate: 96.0,
        performanceRate: 90.0,
        currentSalary: 28000.0,
        commissionRate: 8.0,
        dailyTarget: 5000.0,
        completedTarget: 4800.0,
        status: 'Present',
      ),
      Employee(
        id: 'emp_8',
        name: 'David Beckham',
        role: 'Barber Specialist',
        email: 'david@salon.com',
        phone: '+91 98765 43217',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=David',
        attendanceRate: 93.0,
        performanceRate: 91.0,
        currentSalary: 38000.0,
        commissionRate: 10.0,
        dailyTarget: 7000.0,
        completedTarget: 7500.0,
        status: 'Present',
      ),
    ];
  }

  List<Customer> _initCustomers() {
    final List<String> firstNames = [
      'Aarav', 'Aditi', 'Amit', 'Neha', 'Rohan', 'Sneha', 'Kabir', 'Ananya', 'Arjun', 'Deepika',
      'Vihaan', 'Ishaan', 'Kavya', 'Rahul', 'Divya', 'Siddharth', 'Pooja', 'Karan', 'Meera', 'Riya',
      'Akash', 'Shruti', 'Dev', 'Aditya', 'Tanvi', 'Abhishek', 'Kriti', 'Yash', 'Sonal', 'Varun',
      'Nisha', 'Aaryan', 'Ritu', 'Pranav', 'Simran', 'Manish', 'Preeti', 'Sameer', 'Shreya', 'Vivek',
      'Alisha', 'Raj', 'Payal', 'Vikram', 'Nidhi'
    ];
    final List<String> lastNames = [
      'Sharma', 'Patel', 'Verma', 'Gupta', 'Singh', 'Desai', 'Mehta', 'Rao', 'Reddy', 'Joshi',
      'Chawla', 'Kapoor', 'Kumar', 'Shah', 'Nair', 'Malhotra', 'Bose', 'Choudhury', 'Sen', 'Dubey'
    ];

    final services = [
      'Premium Haircut & Styling',
      'Hydra Facial Treatment',
      'Gel Nail Extensions',
      'Balayage Hair Coloring',
      'Keratin Smooth Therapy',
      'Royal Pedicure & Spa',
      'Bridal Makeup Session',
      'Deep Cleansing Facial',
      'Beard Grooming & Trim'
    ];

    final List<Customer> list = [];
    list.add(Customer(
      id: 'cust_1',
      name: 'Aishwarya Rai',
      phone: '+91 98900 12345',
      email: 'aishwarya@demo.com',
      avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Aishwarya',
      visitCount: 32,
      totalSpent: 124500.0,
      status: 'Green',
      lastVisitDate: '3 days ago',
      servicesTaken: ['Bridal Makeup Session', 'Keratin Smooth Therapy', 'Hydra Facial Treatment'],
      visitHistory: [
        Visit(date: '3 days ago', serviceName: 'Hydra Facial Treatment', amount: 4500.0, rating: 5.0),
        Visit(date: '1 month ago', serviceName: 'Keratin Smooth Therapy', amount: 8500.0, rating: 4.5),
        Visit(date: '3 months ago', serviceName: 'Bridal Makeup Session', amount: 45000.0, rating: 5.0),
      ],
    ));

    list.add(Customer(
      id: 'cust_2',
      name: 'Ranbir Kapoor',
      phone: '+91 98900 67890',
      email: 'ranbir@demo.com',
      avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Ranbir',
      visitCount: 18,
      totalSpent: 42000.0,
      status: 'Green',
      lastVisitDate: 'Yesterday',
      servicesTaken: ['Premium Haircut & Styling', 'Beard Grooming & Trim'],
      visitHistory: [
        Visit(date: 'Yesterday', serviceName: 'Premium Haircut & Styling', amount: 1500.0, rating: 4.8),
        Visit(date: '2 weeks ago', serviceName: 'Beard Grooming & Trim', amount: 800.0, rating: 5.0),
      ],
    ));

    list.add(Customer(
      id: 'cust_3',
      name: 'Sushmita Sen',
      phone: '+91 98200 45678',
      email: 'sushmita@demo.com',
      avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Sushmita',
      visitCount: 24,
      totalSpent: 89000.0,
      status: 'Green',
      lastVisitDate: '5 days ago',
      servicesTaken: ['Hydra Facial Treatment', 'Royal Pedicure & Spa'],
      visitHistory: [
        Visit(date: '5 days ago', serviceName: 'Royal Pedicure & Spa', amount: 2500.0, rating: 5.0),
        Visit(date: '1 month ago', serviceName: 'Hydra Facial Treatment', amount: 4500.0, rating: 5.0),
      ],
    ));

    list.add(Customer(
      id: 'cust_4',
      name: 'Vijay Mallya',
      phone: '+91 99999 99999',
      email: 'vijay@demo.com',
      avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Vijay',
      visitCount: 8,
      totalSpent: 35000.0,
      status: 'Red',
      lastVisitDate: '6 months ago',
      servicesTaken: ['Premium Haircut & Styling', 'Royal Pedicure & Spa'],
      visitHistory: [
        Visit(date: '6 months ago', serviceName: 'Premium Haircut & Styling', amount: 1500.0, rating: 3.5),
      ],
    ));

    list.add(Customer(
      id: 'cust_5',
      name: 'Katrina Kaif',
      phone: '+91 98222 11111',
      email: 'katrina@demo.com',
      avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Katrina',
      visitCount: 15,
      totalSpent: 62000.0,
      status: 'Yellow',
      lastVisitDate: '24 days ago',
      servicesTaken: ['Balayage Hair Coloring', 'Gel Nail Extensions'],
      visitHistory: [
        Visit(date: '24 days ago', serviceName: 'Gel Nail Extensions', amount: 3200.0, rating: 4.7),
        Visit(date: '2 months ago', serviceName: 'Balayage Hair Coloring', amount: 9500.0, rating: 5.0),
      ],
    ));

    for (int i = 6; i <= 45; i++) {
      final fName = firstNames[i % firstNames.length];
      final lName = lastNames[(i * 3) % lastNames.length];
      final name = '$fName $lName';
      final isGreen = i % 3 == 0;
      final isYellow = i % 3 == 1;
      final status = isGreen ? 'Green' : (isYellow ? 'Yellow' : 'Red');
      final visitCnt = (i * 2) % 15 + 1;
      final totalSpentVal = visitCnt * 1250.0;
      
      list.add(Customer(
        id: 'cust_$i',
        name: name,
        phone: '+91 98100 ${10000 + i}',
        email: '${fName.toLowerCase()}.${lName.toLowerCase()}@demo.com',
        avatarUrl: 'https://api.dicebear.com/7.x/adventurer/svg?seed=$fName',
        visitCount: visitCnt,
        totalSpent: totalSpentVal,
        status: status,
        lastVisitDate: '${(i % 14) + 1} days ago',
        servicesTaken: [services[i % services.length]],
        visitHistory: [
          Visit(
            date: '${(i % 14) + 1} days ago',
            serviceName: services[i % services.length],
            amount: 1250.0,
            rating: (i % 2 == 0) ? 5.0 : 4.0,
          )
        ],
      ));
    }
    return list;
  }

  List<Bill> _initBills() {
    return [
      Bill(
        id: 'bill_1',
        billNo: 'TXN1001',
        customerName: 'Aishwarya Rai',
        services: ['Hydra Facial Treatment', 'Royal Pedicure & Spa'],
        discountPercent: 10.0,
        discountAmount: 700.0,
        subtotal: 7000.0,
        totalAmount: 6300.0,
        paymentMethod: 'UPI',
        date: 'Today, 03:30 PM',
      ),
      Bill(
        id: 'bill_2',
        billNo: 'TXN1002',
        customerName: 'Ranbir Kapoor',
        services: ['Premium Haircut & Styling', 'Beard Grooming & Trim'],
        discountPercent: 0.0,
        discountAmount: 0.0,
        subtotal: 2300.0,
        totalAmount: 2300.0,
        paymentMethod: 'Cash',
        date: 'Today, 01:15 PM',
      ),
      Bill(
        id: 'bill_3',
        billNo: 'TXN1003',
        customerName: 'Sushmita Sen',
        services: ['Royal Pedicure & Spa'],
        discountPercent: 15.0,
        discountAmount: 375.0,
        subtotal: 2500.0,
        totalAmount: 2125.0,
        paymentMethod: 'UPI',
        date: 'Today, 11:00 AM',
      ),
      Bill(
        id: 'bill_4',
        billNo: 'TXN1004',
        customerName: 'Aarav Sharma',
        services: ['Keratin Smooth Therapy'],
        discountPercent: 5.0,
        discountAmount: 425.0,
        subtotal: 8500.0,
        totalAmount: 8075.0,
        paymentMethod: 'Pending',
        date: 'Yesterday, 06:45 PM',
      ),
      Bill(
        id: 'bill_5',
        billNo: 'TXN1005',
        customerName: 'Katrina Kaif',
        services: ['Gel Nail Extensions', 'Deep Cleansing Facial'],
        discountPercent: 0.0,
        discountAmount: 0.0,
        subtotal: 5200.0,
        totalAmount: 5200.0,
        paymentMethod: 'UPI',
        date: 'Yesterday, 04:00 PM',
      ),
    ];
  }

  List<InventoryProduct> _initInventory() {
    return [
      InventoryProduct(
        id: 'prod_1',
        name: 'L\'Oreal Professional Shampoo',
        category: 'Hair Care',
        currentStock: 14,
        minStockAlertThreshold: 15,
        unit: 'Bottles',
      ),
      InventoryProduct(
        id: 'prod_2',
        name: 'O3+ Facial Glow Whitening Kit',
        category: 'Skin Care',
        currentStock: 8,
        minStockAlertThreshold: 10,
        unit: 'Kits',
      ),
      InventoryProduct(
        id: 'prod_3',
        name: 'Streaks Ultralights Hair Color (Blonde)',
        category: 'Hair Color',
        currentStock: 25,
        minStockAlertThreshold: 12,
        unit: 'Packs',
      ),
      InventoryProduct(
        id: 'prod_4',
        name: 'Rica Liposoluble Wax (Honey)',
        category: 'Waxing',
        currentStock: 4,
        minStockAlertThreshold: 8,
        unit: 'Tins',
      ),
      InventoryProduct(
        id: 'prod_5',
        name: 'Moroccanoil Treatment Oil 100ml',
        category: 'Hair Care',
        currentStock: 18,
        minStockAlertThreshold: 5,
        unit: 'Bottles',
      ),
      InventoryProduct(
        id: 'prod_6',
        name: 'Lotus Herbals Face Scrub 500g',
        category: 'Skin Care',
        currentStock: 2,
        minStockAlertThreshold: 5,
        unit: 'Jars',
      ),
    ];
  }

  List<Expense> _initExpenses() {
    return [
      Expense(
        id: 'exp_1',
        category: 'Tea',
        description: 'Green tea and snacks for clients & staff',
        amount: 340.0,
        date: 'Today',
      ),
      Expense(
        id: 'exp_2',
        category: 'Cleaning',
        description: 'Disinfectants, towels laundry detergents',
        amount: 850.0,
        date: 'Today',
      ),
      Expense(
        id: 'exp_3',
        category: 'Repair',
        description: 'Replacing faulty hydraulic chair valves',
        amount: 2400.0,
        date: 'Yesterday',
      ),
      Expense(
        id: 'exp_4',
        category: 'Electricity',
        description: 'Monthly electricity charges - Main branch',
        amount: 14500.0,
        date: '3 days ago',
      ),
      Expense(
        id: 'exp_5',
        category: 'Maintenance',
        description: 'AC servicing for main styling lounge',
        amount: 3200.0,
        date: '4 days ago',
      ),
      Expense(
        id: 'exp_6',
        category: 'Miscellaneous',
        description: 'Drinking water cans purchase',
        amount: 450.0,
        date: 'Today',
      ),
    ];
  }

  List<DiscountRequest> _initDiscountRequests() {
    return [
      DiscountRequest(
        id: 'req_1',
        customerName: 'Kriti Sanon',
        employeeName: 'Elena Rostova',
        requestedDiscountPercent: 20.0,
        originalAmount: 8500.0,
        status: 'Pending',
        date: 'Today, 02:45 PM',
      ),
      DiscountRequest(
        id: 'req_2',
        customerName: 'Varun Dhawan',
        employeeName: 'Rohan Sharma',
        requestedDiscountPercent: 15.0,
        originalAmount: 6200.0,
        status: 'Pending',
        date: 'Today, 04:10 PM',
      ),
      DiscountRequest(
        id: 'req_3',
        customerName: 'Shraddha Kapoor',
        employeeName: 'Priya Patel',
        requestedDiscountPercent: 25.0,
        originalAmount: 14000.0,
        status: 'Approved',
        date: 'Yesterday, 11:20 AM',
      ),
      DiscountRequest(
        id: 'req_4',
        customerName: 'Kartik Aaryan',
        employeeName: 'Elena Rostova',
        requestedDiscountPercent: 10.0,
        originalAmount: 3500.0,
        status: 'Rejected',
        date: 'Yesterday, 03:50 PM',
      ),
    ];
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

final salonStateProvider = NotifierProvider<SalonStateNotifier, SalonState>(() {
  return SalonStateNotifier();
});
