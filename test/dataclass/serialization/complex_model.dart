import 'package:macro_kit/macro.dart';

part 'complex_model.g.dart';

/// Basic data class with various field types
@dataClassMacro
class User with UserData {
  final String id;
  final String name;
  final int age;
  final String? email;
  final bool isActive;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.age,
    this.email,
    this.isActive = true,
    required this.createdAt,
  });
}

/// Data class with nested objects
@dataClassMacro
class Address with AddressData {
  final String street;
  final String city;
  final String? state;
  final String country;
  final String zipCode;

  const Address({
    required this.street,
    required this.city,
    this.state,
    required this.country,
    required this.zipCode,
  });
}

@dataClassMacro
class Person with PersonData {
  final String name;
  final int age;
  final Address address;
  final Address? billingAddress;
  final List<String> phoneNumbers;

  const Person({
    required this.name,
    required this.age,
    required this.address,
    this.billingAddress,
    required this.phoneNumbers,
  });
}

/// Data class with collections
@dataClassMacro
class ShoppingCart with ShoppingCartData {
  final String userId;
  final List<CartItem> items;
  final Map<String, double> discounts;
  final Set<String> appliedCoupons;
  final DateTime createdAt;
  final DateTime? lastModified;

  const ShoppingCart({
    required this.userId,
    required this.items,
    this.discounts = const {},
    this.appliedCoupons = const {},
    required this.createdAt,
    this.lastModified,
  });
}

@dataClassMacro
class CartItem with CartItemData {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final Map<String, String> metadata;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.metadata = const {},
  });
}

/// Data class with enums
enum UserRole {
  admin,
  moderator,
  user,
  guest,
}

enum AccountStatus {
  active,
  suspended,
  pending,
  deleted,
}

@dataClassMacro
class Account with AccountData {
  final String id;
  final String username;
  final UserRole role;
  final AccountStatus status;
  final List<UserRole> previousRoles;
  final Map<String, dynamic> permissions;

  const Account({
    required this.id,
    required this.username,
    this.role = UserRole.user,
    this.status = AccountStatus.pending,
    this.previousRoles = const [],
    this.permissions = const {},
  });
}

/// Data class with generics
@dataClassMacro
class Result<T> with ResultData<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  final DateTime? timestamp;

  const Result({
    this.data,
    this.error,
    required this.isSuccess,
    required this.timestamp,
  });

  const Result.success(T this.data)
    : error = null,
      isSuccess = true,
      timestamp = null; // In real code, this would need a const DateTime

  const Result.failure(String this.error) : data = null, isSuccess = false, timestamp = null;
}

/// Data class with named constructors
@dataClassMacro
class Payment with PersonData {
  final String id;
  final double amount;
  final String currency;
  final String method;
  final DateTime processedAt;
  final Map<String, String> metadata;

  const Payment({
    required this.id,
    required this.amount,
    required this.currency,
    required this.method,
    required this.processedAt,
    this.metadata = const {},
  });

  const Payment.cash({
    required this.id,
    required this.amount,
    required this.processedAt,
  }) : currency = 'USD',
       method = 'cash',
       metadata = const {};

  const Payment.card({
    required this.id,
    required this.amount,
    this.currency = 'USD',
    required String cardLast4,
    required this.processedAt,
  }) : method = 'card',
       metadata = const {'cardLast4': 'cardLast4'};
}

/// Deeply nested data class
@dataClassMacro
class Organization with OrganizationData {
  final String id;
  final String name;
  final Address headquarters;
  final List<Department> departments;
  final Map<String, Person> employees;
  final Settings settings;

  const Organization({
    required this.id,
    required this.name,
    required this.headquarters,
    required this.departments,
    required this.employees,
    required this.settings,
  });
}

@dataClassMacro
class Department with DepartmentData {
  final String id;
  final String name;
  final Person manager;
  final List<Person> members;
  final Budget budget;

  const Department({
    required this.id,
    required this.name,
    required this.manager,
    required this.members,
    required this.budget,
  });
}

@dataClassMacro
class Budget with BudgetData {
  final double allocated;
  final double spent;
  final String currency;
  final DateTime fiscalYearStart;
  final DateTime fiscalYearEnd;
  final List<Expense> expenses;

  const Budget({
    required this.allocated,
    required this.spent,
    this.currency = 'USD',
    required this.fiscalYearStart,
    required this.fiscalYearEnd,
    this.expenses = const [],
  });
}

@dataClassMacro
class Expense with ExpenseData {
  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final Person approvedBy;

  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.approvedBy,
  });
}

@dataClassMacro
class Settings with SettingsData {
  final bool notificationsEnabled;
  final String theme;
  final Map<String, bool> features;
  final List<String> allowedDomains;

  const Settings({
    this.notificationsEnabled = true,
    this.theme = 'light',
    this.features = const {},
    this.allowedDomains = const [],
  });
}

/// Data class with complex default values
@dataClassMacro
class Configuration with ConfigurationData {
  final String appName;
  final int maxRetries;
  final Duration timeout;
  final Map<String, String> headers;
  final List<String> endpoints;
  final bool debugMode;

  const Configuration({
    this.appName = 'MyApp',
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 30),
    this.headers = const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    this.endpoints = const ['https://api.example.com'],
    this.debugMode = false,
  });
}

/// Data class with private fields (edge case)
@dataClassMacro
class SecureData with SecureDataData {
  final String publicId;
  final String _privateKey;
  final DateTime _createdAt;

  const SecureData({
    required this.publicId,
    required String privateKey,
    required DateTime createdAt,
  }) : _privateKey = privateKey,
       _createdAt = createdAt;

  String get privateKey => _privateKey;

  DateTime get createdAt => _createdAt;
}

/// Data class with factory constructors
@dataClassMacro
class ApiResponse<T> with ApiResponseData<T> {
  final int statusCode;
  final T data;
  final String? message;
  final Map<String, String> headers;

  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.message,
    this.headers = const {},
  });

  factory ApiResponse.success(T data) {
    return ApiResponse(
      statusCode: 200,
      data: data,
      message: 'Success',
    );
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(
      statusCode: 500,
      data: null as T,
      message: message,
    );
  }
}

/// Super complex combined class
@dataClassMacro
class OrderSystem with OrderSystemData {
  final String orderId;
  final Person customer;
  final Address shippingAddress;
  final Address? billingAddress;
  final ShoppingCart cart;
  final List<Payment> payments;
  final OrderStatus status;
  final Map<OrderStatus, DateTime> statusHistory;
  final Set<String> tags;
  final List<OrderNote> notes;
  final Configuration config;

  const OrderSystem({
    required this.orderId,
    required this.customer,
    required this.shippingAddress,
    this.billingAddress,
    required this.cart,
    required this.payments,
    this.status = OrderStatus.pending,
    required this.statusHistory,
    this.tags = const {},
    this.notes = const [],
    required this.config,
  });
}

enum OrderStatus {
  pending,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded,
}

@dataClassMacro
class OrderNote with OrderNoteData {
  final String id;
  final String content;
  final Person author;
  final DateTime createdAt;
  final bool isInternal;

  const OrderNote({
    required this.id,
    required this.content,
    required this.author,
    required this.createdAt,
    this.isInternal = false,
  });
}
