class Participant {
  String email;
  double amount;
  double? percentage;
  bool isIncluded;

  Participant({
    required this.email,
    this.amount = 0.0,
    this.percentage,
    required this.isIncluded,
  });
}
