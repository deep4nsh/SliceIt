class Participant {
  String email;
  double amount;
  bool isIncluded;

  Participant({
    required this.email,
    this.amount = 0.0,
    required this.isIncluded,
  });
}
