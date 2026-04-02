import '../models/product.model.dart';

class ProductRepository {
  // هذه قائمة تجريبية للمنتجات مع إحداثيات واقعية لأسواق في صنعاء وعدن
  static List<Product> getMockProducts() {
    return [
      Product(
        id: 1,
        name: "دقيق السنابل (أبيض)",
        category: "حبوب",
        officialPrice: 17500,
        unit: "كيس 50 كجم",
        isStable: true,
        storeName: "سوبر ماركت الهدى - السبعين", // إضافة الاسم المطلوب
        lat: 15.3188, // إضافة خط العرض
        lng: 44.2058, // إضافة خط الطول
        rating: 4.8, // إضافة التقييم
      ),
      Product(
        id: 2,
        name: "أرز بسمتي (الشعلان)",
        category: "حبوب",
        officialPrice: 22000,
        unit: "قطمة 10 كجم",
        isStable: true,
        storeName: "المركز التجاري - المنصورة",
        lat: 12.8714,
        lng: 44.9814,
        rating: 4.2,
      ),
      Product(
        id: 3,
        name: "حليب ممتاز (لونا)",
        category: "ألبان",
        officialPrice: 550,
        unit: "علبة 170 مل",
        isStable: false,
        storeName: "أسواق مكة - الشيخ عثمان",
        lat: 12.8333,
        lng: 45.0000,
        rating: 4.5,
      ),
      Product(
        id: 4,
        name: "غاز منزلي",
        category: "طاقة",
        officialPrice: 6500,
        unit: "أصطوانة 20 لتر",
        isStable: true,
        storeName: "محطة الستين - صنعاء",
        lat: 15.3724,
        lng: 44.1812,
        rating: 3.9,
      ),
      Product(
        id: 5,
        name: "زيت شروق",
        category: "مواد غذائية",
        officialPrice: 3500,
        unit: "لتر",
        isStable: true,
        storeName: "هايبر شملان",
        lat: 15.4022,
        lng: 44.1500,
        rating: 4.1,
      ),
    ];
  }
}
