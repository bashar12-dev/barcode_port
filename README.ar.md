# BarcodePort

واجهة موحّدة لاستقبال قراءات أجهزة الباركود في Flutter على Android وiOS وWindows وmacOS وLinux والويب.

[English](https://github.com/bashar12-dev/barcode_port/blob/main/README.md) · [مرجع الواجهة](https://pub.dev/documentation/barcode_port/latest/) · [المثال](https://github.com/bashar12-dev/barcode_port/tree/main/example) · [توافق الأجهزة](https://github.com/bashar12-dev/barcode_port/blob/main/doc/device-compatibility.md)

تستقبل المكتبة قارئات HID التي ترسل كلوحة مفاتيح على المنصات المدعومة، وبث أجهزة iMin على Android، دون الحاجة
إلى إبقاء حقل نصي محددًا. يبقى البحث عن المنتجات وقواعد الفواتير داخل تطبيقك.

- معرّف مستقل ووقت UTC لكل قراءة، حتى عند مسح القيمة نفسها مرتين.
- إدارة اختيارية للاستقبال حسب الشاشة وحالة التطبيق باستخدام `ScannerListener`.
- تعديل النص والفلترة وحذف التكرار المتتالي خيارات معطّلة افتراضيًا.
- تشخيص أسباب رفض القراءة دون تضمين قيمة الباركود أو تسجيلها تلقائيًا.
- إدارة مالك واحد للاستقبال، مع تشغيل وإيقاف وتحرير غير متزامن.

![مثال BarcodePort يعرض قراءة 123](https://raw.githubusercontent.com/bashar12-dev/barcode_port/main/doc/images/example.png)

## المتطلبات والدعم

Dart ‏3.10.7 فأحدث وFlutter ‏3.38.6 فأحدث. يحتاج Android أيضًا إلى API 24 فأحدث،
وcompileSdk 36، واستهداف Java/Kotlin 17. تتبع متطلبات بقية الأنظمة إصدار Flutter المستخدم.

| المنصة | قارئ يعمل كلوحة مفاتيح HID | بث iMin |
|---|---|---|
| Android | مدعوم | مدعوم بإعدادات وصيغة بث متوافقة |
| iOS وiPadOS | مدعوم عبر أحداث لوحة المفاتيح في Flutter | غير متاح |
| Windows | مدعوم عبر أحداث لوحة المفاتيح في Flutter | غير متاح |
| macOS | مدعوم عبر أحداث لوحة المفاتيح في Flutter | غير متاح |
| Linux | مدعوم عبر أحداث لوحة المفاتيح في Flutter | غير متاح |
| الويب | مدعوم عبر أحداث لوحة المفاتيح في Flutter | غير متاح |

يجب ضبط قارئ USB أو Bluetooth على وضع لوحة المفاتيح، مع Enter أو Tab افتراضيًا؛
يتولى نظام التشغيل توصيله. دعم المنصات الجديدة مبني بـDart وFlutter فقط، دون إضافة
كود أصلي خاص بالقارئ أو حزم الشركات المصنّعة. يبقى تكامل Android الحالي كما هو.

راجع [فحوص المنصات](https://github.com/bashar12-dev/barcode_port/blob/main/doc/platform-validation.md)
لمعرفة نتائج بناء الإصدار **1.1.0** وما ينتظر تجربة قارئ فعلي.

راجع [سجل الأجهزة](https://github.com/bashar12-dev/barcode_port/blob/main/doc/device-compatibility.md) لمعرفة الموديلات التي اجتازت
التحقق الفعلي وحالة جاهزية الإصدار. لا تعني التقنية المدعومة ضمان كل الموديلات.
لا تتضمن المكتبة قراءة بالكاميرا أو BLE/SPP أو USB Serial أو اكتشاف الأجهزة
أو معالجة GS1 الجاهزة أو الاستقبال المستمر في الخلفية.

## التثبيت

```sh
flutter pub add barcode_port
```

أو أضف `barcode_port: ^1.1.0` إلى `dependencies`.

## البدء

```dart
import 'package:barcode_port/scanner_widgets.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: ScannerListener(
        createScanner: () => Scanner(),
        onScan: (scan) => debugPrint('Read: ${scan.barcode}'),
        onError: (error, stack) => FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        ),
        child: const Center(child: Text('Ready to scan')),
      ),
    ),
  ));
}
```

طباعة القراءة هنا اختيار صريح في المثال؛ احذفها إن كانت البيانات لا ينبغي تسجيلها.
يمتلك `ScannerListener` المصدر ويتولى تشغيله وإيقافه وتحريره. يتطلب الاستقبال
أن تكون `enabled=true`، والشاشة الحالية، والتطبيق في حالة resumed. تغطية الشاشة
بصفحة أو نافذة أو إرسال التطبيق للخلفية توقف الاستقبال مؤقتًا. اربط `enabled`
بظهور التبويب في التبويبات المخفية وNavigators المتداخلة.

يُنشأ المصدر مرة واحدة لكل State؛ تحديث دالة الإنشاء لا يستبدله. لاستبداله استخدم
مفتاحًا جديدًا وانتظر تحرير المالك السابق قبل تشغيل التالي.

## إدارة المصدر مباشرة

استورد `package:barcode_port/barcode_port.dart`، واشترك في `events` قبل
`await scanner.start()` حتى تصل قراءات بدء التشغيل. استخدم `stop` للإيقاف القابل
لإعادة التشغيل و`dispose` للتحرير النهائي. ألغِ اشتراكات الأحداث والتشخيص قبل
التحرير، وتعامل مع أخطاء التدفقات وأخطاء عمليات دورة الحياة. يتضمن
[الدليل الإنجليزي](https://github.com/bashar12-dev/barcode_port/blob/main/README.md#direct-lifecycle) مثالًا كاملًا.

## التركيز والسياسات

- لا يحتاج HID حقلًا نصيًا؛ أثناء تركيز حقل قابل للتحرير يترك إدخاله للحقل افتراضيًا.
- يجب أن تستقبل نافذة التطبيق إدخال لوحة المفاتيح؛ وفي الويب يجب أن يكون التركيز داخل عرض Flutter في المتصفح. لا يلتقط إدخال تطبيق أو تبويب آخر.
- طابق تخطيط لوحة المفاتيح في القارئ مع نظام التشغيل؛ تصل الأحرف كما يرسلها Flutter، دون دعم تركيب النص بواسطة IME أو البيانات الثنائية.
- يعمل `Scanner()` نفسه على جميع المنصات. يختار `auto` مسار HID مباشرة خارج Android الأصلي، حتى داخل متصفح يعمل على Android.
- طلب `iminBroadcast` خارج Android الأصلي يعطي `UnsupportedError`، بينما يبقى المصدر المخصص عبر `ScannerPlatform` هو المعتمد عند تمريره صراحة. الواجهة المنخفضة `ScannerBridge` خاصة بـAndroid.
- دخول الحقل يمسح إطار HID الجزئي فورًا، ولا يؤثر في بث iMin.
- HID يستقبل لوحة المفاتيح ولا يثبت أن المدخل صادر عن قارئ؛ قد تُعامل الكتابة البشرية كإطار.
- المهلة الافتراضية ثانيتان بين الأحرف، والحد 4096 وحدة UTF-16، والنهايتان Enter وTab.
- تُزال الفراغات الطرفية وتُرفض النصوص الفارغة؛ تحفظ الأصفار في بداية الأكواد.
- لا تُفعّل الفلترة أو تعديل النص أو حذف التكرار افتراضيًا.

```dart
final scanner = Scanner(
  processing: ScanProcessingOptions(
    normalize: (text) => text.toUpperCase(),
    accept: (text) => text.startsWith('ITEM-'),
    duplicateWindow: const Duration(milliseconds: 500),
  ),
);
```

الترتيب: تعديل النص، إزالة الفراغات، رفض الفارغ، الفلترة، فحص التكرار، التسليم.
تظل هوية الحدث ووقته محفوظتين. عند تفعيل حذف التكرار يخص القراءات المقبولة
المتتالية للقيمة نفسها داخل النافذة فقط؛ الحد الزمني نفسه يُقبل، والقراءة المحذوفة
لا تمدد النافذة، وتسلسل A/B/A يبقى ثلاث قراءات. يُصفّر السجل عند الإيقاف والتشغيل.
مسح المنتج مرتين قد يعني قطعتين؛ فعّل هذه السياسة فقط إذا كان ذلك يناسب تطبيقك.

تعرض `diagnostics` أسباب المهلة وتجاوز الحجم والفراغ والفلترة والتعديل الفارغ
والتكرار المحذوف، دون النص الأصلي. تبقى أخطاء التشغيل على `events`، واستثناء
دالة الفلترة أو التعديل لا يمنع معالجة القراءات التالية.

## تشغيل المثال

```sh
cd example
flutter pub get
flutter run
```

تهيئة مخرجات iMin خيار صريح معطّل افتراضيًا:

```sh
flutter run --dart-define=BARCODE_PORT_CONFIGURE_IMIN_OUTPUT=true
```

هذا الخيار يغيّر إعداد إخراج الجهاز، ولا يعيد الإيقاف الإعداد السابق تلقائيًا.
استخدم Hot Restart بعد تغيير خيارات `dart-define`. ولتجربة سياسة المعالجة شغّل
`flutter run --dart-define=SCANNER_EXAMPLE_POLICY=true`.

## المساعدة والمساهمة

راجع [المثال](https://github.com/bashar12-dev/barcode_port/blob/main/example/README.md) و[الدعم](https://github.com/bashar12-dev/barcode_port/blob/main/SUPPORT.md) و[المساهمة](https://github.com/bashar12-dev/barcode_port/blob/main/CONTRIBUTING.md)
و[قائمة الإصدار](https://github.com/bashar12-dev/barcode_port/blob/main/doc/releasing.md). عند الإبلاغ عن مشكلة أرفق الموديل وإصدار
نظام التشغيل أو المتصفح والبرنامج الثابت وطريقة الاتصال وإعداد الإخراج ومثالًا صغيرًا ببيانات
تجريبية. تُرسل الثغرات عبر الإبلاغ الأمني الخاص في GitHub وفق [سياسة الأمن](https://github.com/bashar12-dev/barcode_port/blob/main/SECURITY.md).

المكتبة بترخيص [MIT](https://github.com/bashar12-dev/barcode_port/blob/main/LICENSE). لا تتضمن SDK مملوكًا لشركة أجهزة.
