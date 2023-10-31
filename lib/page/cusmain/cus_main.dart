import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// 数据模型类
class NavItem {
  final int id;
  final String title;
  final IconData icon;

  NavItem({required this.id, required this.title, required this.icon});

  // 将对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': icon.codePoint, // 将图标编码为整数
    };
  }

  // 将Map转换为对象
  factory NavItem.fromMap(Map<String, dynamic> map) {
    return NavItem(
      id: map['id'],
      title: map['title'],
      icon: IconData(map['icon'], fontFamily: 'MaterialIcons'), // 将整数解码为图标
    );
  }
}

// 数据库操作类
class DatabaseHelper {
  static final _databaseName = "nav.db";
  static final _databaseVersion = 1;
  static final table = "nav";
  static final columnId = 'id';
  static final columnTitle = 'title';
  static final columnIcon = 'icon';

  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 初始化数据库
  _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
    }
    print(Directory.current.path);
    // Change the default factory. On iOS/Android, if not using `sqlite_flutter_lib` you can forget
    // this step, it will use the sqlite version available on the system.
    databaseFactory = databaseFactoryFfi;
    String path = join(await getDatabasesPath(), _databaseName);
    print("数据库路径 ${path}");
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  // 创建表
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnTitle TEXT NOT NULL,
            $columnIcon INTEGER NOT NULL
          )
          ''');
    // 插入一些初始数据
    await db.insert(
        table, NavItem(id: 0, title: "add", icon: Icons.add).toMap());
  }

  // 查询所有数据
  Future<List<NavItem>> queryAllRows() async {
    Database db = await instance.database;
    var res = await db.query(table);
    return res.map((e) => NavItem.fromMap(e)).toList();
  }

  // 插入一条数据
  Future<int> insert(NavItem navItem) async {
    Database db = await instance.database;
    var res = await db.insert(table, navItem.toMap());
    return res;
  }

  // 删除一条数据
  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }
}

// 控制器类
class NavController extends GetxController {
  static NavController get to => Get.find();

  // 导航栏按钮列表
  var navItems = <NavItem>[].obs;

  // 当前选中的按钮索引
  var selectedIndex = 0.obs;

  // 初始化方法，从数据库中获取数据
  @override
  void onInit() {
    super.onInit();
    getNavItems();
  }

  // 获取导航栏按钮列表
  void getNavItems() async {
    var items = await DatabaseHelper.instance.queryAllRows();
    printInfo(info: '${items}');
    if (items.isEmpty) {
      navItems.value = [NavItem(id: 0, title: "add", icon: Icons.add)];
    } else {
      navItems.value = items;
    }
  }

  // 添加一个导航栏按钮
  void addNavItem(String title, IconData icon) async {
    int id = await DatabaseHelper.instance.insert(
        NavItem(id: navItems.length, title: title, icon: icon)); // 插入数据库并获取id
    navItems.add(NavItem(id: id, title: title, icon: icon)); // 添加到列表中
    Get.back(); // 关闭对话框
    Get.snackbar("Success", "Added a new navigation item"); // 显示提示信息
  }

  // 删除一个导航栏按钮
  void deleteNavItem(int index) async {
    int id = navItems[index].id; // 获取要删除的id
    if (id == 0) {
      //无法删除添加的
      return;
    }
    await DatabaseHelper.instance.delete(id); // 删除数据库中的记录
    navItems.removeAt(index); // 删除列表中的元素
    if (selectedIndex.value == index) {
      // 如果删除的是当前选中的按钮，则将选中索引设为0
      selectedIndex.value = 0;
    }
    Get.back(); // 关闭底部表单
    Get.snackbar("Success", "Deleted a navigation item"); // 显示提示信息
  }

  // 切换当前选中的按钮索引
  void changeSelectedIndex(int index) {
    selectedIndex.value = index;
  }
}

// 视图类，主界面
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            child: NavigationListWidget(),
            width: 120,
            height: double.infinity,
          ), // 左侧导航栏组件
          VerticalDivider(thickness: 1, width: 1), // 分隔线组件
          ContentWidget(), // 右侧内容组件
        ],
      ),
    );
  }
}

// 左侧导航栏组件，使用GetX的Obx包裹，实现响应式更新
class NavigationListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView.builder(
          itemExtent: 66,
          itemCount: NavController.to.navItems.length,
          itemBuilder: (context, index) {
            return Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  if (NavController.to.navItems[index].id == 0) {
                    Get.to(AddNavItemPage()); //跳转
                  } else {
                    NavController.to.changeSelectedIndex(index);
                  }
                },
                icon: Icon(NavController.to.navItems[index].icon),
                label: AutoSizeText(
                  NavController.to.navItems[index].title,
                  style: TextStyle(fontSize: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                    return NavController.to.selectedIndex.value == index
                        ? Colors.blue
                        : Colors.grey;
                  }),
                  minimumSize:
                      MaterialStateProperty.all(Size(double.infinity, 50)),
                ),
              ),
            );
            return ListTile(
              leading: SizedBox(
                width: 50,
                height: 50,
                child: Icon(NavController.to.navItems[index].icon),
              ),
              title: AutoSizeText(
                NavController.to.navItems[index].title,
                style: TextStyle(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: NavController.to.selectedIndex.value == index,
              // 根据选中状态显示不同的颜色
              onTap: () {
                NavController.to.changeSelectedIndex(index); // 点击按钮时切换选中状态
              },
            );
          },
        ));
  }
}

// 左侧导航栏组件，使用GetX的Obx包裹，实现响应式更新
class NavigationRailWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() => NavigationRail(
          destinations: NavController.to.navItems.map((e) {
            return NavigationRailDestination(
              icon: Icon(e.icon),
              label: Text(e.title),
            );
          }).toList(),
          selectedIndex: NavController.to.selectedIndex.value,
          onDestinationSelected: (index) {
            NavController.to.changeSelectedIndex(index);
          },
          trailing: IconButton(
            icon: Icon(Icons.more_horiz),
            onPressed: () {
              Get.bottomSheet(BottomSheetWidget()); // 显示底部表单组件，用于删除导航栏按钮
            },
          ),
        ));
  }
}

// 右侧内容组件，使用GetX的Obx包裹，实现响应式更新
class ContentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (NavController.to.navItems.isEmpty) {
        return Container();
      }
      return Expanded(
        child: Center(
          child: Text(
            NavController
                .to.navItems[NavController.to.selectedIndex.value].title,
            style: TextStyle(fontSize: 32),
          ),
        ),
      );
    });
  }
}

// 添加导航栏按钮页面，使用GetX的GetView包裹，实现获取控制器实例的简化写法
class AddNavItemPage extends GetView<NavController> {
  final titleController = TextEditingController();
  final iconController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("新增功能"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: iconController,
                decoration: InputDecoration(
                  labelText: "Icon",
                  border: OutlineInputBorder(),
                  hintText: "Enter the name of a Material icon",
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  String title = titleController.text;
                  String icon = iconController.text;
                  if (title.isEmpty || icon.isEmpty) {
                    Get.snackbar("Error", "Please enter both title and icon");
                  } else {
                    IconData? iconData = IconDataGetter.getIconData(icon);
                    // 使用一个自定义的类来根据图标名称获取图标对象
                    if (iconData == null) {
                      Get.snackbar("Error", "Invalid icon name");
                    } else {
                      /// 调用控制器的方法添加导航栏按钮
                      controller.addNavItem(title, iconData);
                    }
                  }
                },
                child: Text("Add"),
              )
            ],
          ),
        ));
  }
}

// 底部表单组件，使用GetX的Obx包裹，实现响应式更新
class BottomSheetWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView.builder(
          itemCount: NavController.to.navItems.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: Icon(NavController.to.navItems[index].icon),
              title: Text(NavController.to.navItems[index].title),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  // 调用控制器的方法删除导航栏按钮
                  NavController.to.deleteNavItem(index);
                },
              ),
            );
          },
        ));
  }
}

// 自定义的类，用于根据图标名称获取图标对象
class IconDataGetter {
  static Map<String, IconData> icons = {
    'home': Icons.home,
    'settings': Icons.settings,
    'info': Icons.info,
    'add': Icons.add
    // … 其他图标名称和对象的映射
  };

  static IconData? getIconData(String name) {
    return icons[name];
  }
}
