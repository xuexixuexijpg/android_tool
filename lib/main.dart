import 'package:android_tool/page/cusmain/cus_main.dart';
import 'package:android_tool/page/main/main_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  Get.put(NavController()); // 注册控制器
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => HomePage()),
        GetPage(name: '/add', page: () => AddNavItemPage()),
        GetPage(name: '/bottomSheet', page: () => BottomSheetWidget()),
      ],
      theme: ThemeData(primaryColor: Colors.greenAccent),
    );
  }

}
