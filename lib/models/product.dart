import 'dart:convert';

List<Products> productFromJson(String str) =>
    List<Products>.from(json.decode(str).map((x) => Products.fromJson(x)));

String productToJson(List<Products> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Products {
  Products({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.discountPercentage,
    required this.rating,
    required this.stock,
    required this.brand,
    required this.category,
    required this.thumbnail,
    required this.images,
  });
  late final int id;
  late final String? title;
  late final String? description;
  late final int? price;
  late final double? discountPercentage;
  late final double? rating;
  late final int? stock;
  late final String? brand;
  late final String? category;
  late final String? thumbnail;
  late final List<String> images;

  Products.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    description = json['description'];
    price = json['price'];
    discountPercentage = json['discountPercentage'];
    rating = json['rating'];
    stock = json['stock'];
    brand = json['brand'];
    category = json['category'];
    thumbnail = json['thumbnail'];
    images = List.castFrom<dynamic, String>(json['images']);
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['title'] = title;
    _data['description'] = description;
    _data['price'] = price;
    _data['discountPercentage'] = discountPercentage;
    _data['rating'] = rating;
    _data['stock'] = stock;
    _data['brand'] = brand;
    _data['category'] = category;
    _data['thumbnail'] = thumbnail;
    _data['images'] = images;
    return _data;
  }
}
