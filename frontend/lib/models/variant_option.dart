// lib/models/variant_option.dart

class VariantOption {
  final String text;
  final bool selected;
  final String? value;

  VariantOption({
    required this.text,
    required this.selected,
    this.value,
  });

  factory VariantOption.fromJson(Map<String, dynamic> json) {
    return VariantOption(
      text: json['text'] ?? '',
      selected: json['selected'] ?? false,
      value: json['value'],
    );
  }
}