import 'package:android_tool/page/common/app.dart';
import 'package:android_tool/page/common/base_view_model.dart';
import 'package:android_tool/page/flie_manager/u_disk_model.dart';
import 'package:android_tool/widget/text_view.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:process_run/shell.dart';
import 'package:selector_plus/selector_plus.dart';

import '../../widget/list_filter_dialog.dart';
import 'file_model.dart';

class FileManagerViewModel extends BaseViewModel {
  static const int typeFolder = 0;
  static const int typeFile = 1;
  static const int typeLinkFile = 2;
  static const int typeBackFolder = 2;

  SelectorListPlusData<FileModel> files = SelectorListPlusData();

  String deviceId;

  //根目录
  SelectorListPlusData<String> rootAndCurPath = SelectorListPlusData();

  String rootPath = '/sdcard/';
  String currentPath = '/sdcard/';

  bool isDragging = false;

  FileManagerViewModel(
    BuildContext context,
    this.deviceId,
  ) : super(context) {
    App().eventBus.on<DeviceIdEvent>().listen((event) {
      deviceId = event.deviceId;
    });
    App().eventBus.on<AdbPathEvent>().listen((event) {
      adbPath = event.path;
    });
  }

  init() async {
    adbPath = await App().getAdbPath();
    await getFileList();
  }

  getFileList() async {
    var result =
        await execAdb(["-s", deviceId, "shell", "ls", "-FA", currentPath]);
    if (result == null) return;
    files.value = [];
    for (var value in result.outLines) {
      if (value.endsWith("/")) {
        files.add(FileModel(
          value.substring(0, value.length - 1),
          typeFolder,
          Icons.folder,
        ));
      } else if (value.endsWith("@")) {
        files.add(FileModel(
          value.substring(0, value.length - 1),
          typeLinkFile,
          Icons.attach_file,
        ));
      } else if (value.endsWith("*")) {
        files.add(FileModel(
          value.substring(0, value.length - 1),
          typeFile,
          Icons.insert_drive_file,
        ));
      } else {
        files.add(FileModel(
          value,
          typeFile,
          Icons.insert_drive_file,
        ));
      }
    }
    notifyListeners();
  }

  void openFolder(FileModel value) {
    if (value.type == typeFolder) {
      currentPath += value.name + "/";
      getFileList();
    }
  }

  void backFolder() {
    if (currentPath == rootPath) return;
    currentPath = currentPath.substring(
        0, currentPath.lastIndexOf("/", currentPath.lastIndexOf("/") - 1) + 1);
    getFileList();
  }

  void onDragDone(DropDoneDetails data, int index) async {
    if (index == -1 && isDragging) return;
    String msg = "";
    String devicePath =
        index == -1 ? currentPath : currentPath + files.value[index].name;
    for (var file in data.files) {
      if (file.path.endsWith(".apk")) {
        var isInstall = await showInstallApkDialog(deviceId, file);
        if (isInstall == null || !isInstall) {
          msg += await pushFileToDevices(file.path, file.name, devicePath);
        }
      } else {
        msg += await pushFileToDevices(file.path, file.name, devicePath);
      }
    }
    if (msg.isNotEmpty) {
      showResultDialog(content: msg);
    }
    if (index != -1) {
      setItemSelectState(index, false);
    } else {
      getFileList();
    }
    isDragging = false;
  }

  void onDragUpdated(DropEventDetails data, int index) {
    print("onDragUpdated");
    isDragging = true;
  }

  void onDragExited(DropEventDetails data, int index) {
    print("onDragExited");
    isDragging = false;
    setItemSelectState(index, false);
  }

  void onDragEntered(DropEventDetails data, int index) {
    print("onDragEntered");
    isDragging = true;
    setItemSelectState(index, true);
  }

  void setItemSelectState(int index, bool isSelect) {
    files.value[index].isSelect = isSelect;
    notifyListeners();
  }

  Future<String> pushFileToDevices(
      String filePath, String fileName, String devicePath) async {
    var result = await execAdb([
      "-s",
      deviceId,
      "push",
      filePath,
      devicePath,
    ]);
    return result != null && result.exitCode == 0
        ? "$fileName 传输成功\n"
        : "$fileName 传输失败\n";
  }

  Future<void> onPointerDown(BuildContext context, PointerDownEvent event,
      int index, int fileType) async {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton) {
      setItemSelectState(index, true);
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      final menuItem = await showMenu<int>(
          context: context,
          items: _getOperate(fileType),
          position: RelativeRect.fromSize(
              event.position & const Size(48.0, 48.0),
              overlay?.size ?? const Size(48.0, 48.0)));
      setItemSelectState(index, false);
      switch (menuItem) {
        case 1:
          deleteFile(index);
          break;
        case 2:
          saveFile(index);
          break;
        case 3:
          importFile(index);
          break;
        case 4:
          importFolder(index);
          break;
        default:
      }
    }
  }

  ListFilterController<UDiskModel> controller =
      ListFilterController<UDiskModel>();
  List<UDiskModel> devicesList = [];

  /// 查看系统目录 / 挂载的u盘路径等
  Future<void> getSdcardOrUDisk() async {
    var result = await execAdb(['-s', deviceId, 'shell', 'df', '-h']);
    //找到类似这样的  /mnt/media_rw/XXXX  /mnt/usb_storage/USB_DISK1/udisk0
    // adb shell cd 路径
    // adb shell ls
    devicesList.clear();
    //将获取到的外挂sd放到
    var outLines = result?.outLines;
    if (outLines != null) {
      outLines.forEach((element) {
        print("输出获取挂载sd " + element);
        var str = element.trim();
        // 找到第一个空格和最后一个空格的位置
        var firstSpace = str.indexOf(' ');
        var lastSpace = str.lastIndexOf(' ');
        // 截取两个子字符串
        var first = str.substring(0, firstSpace);
        var last = str.substring(lastSpace + 1);
        // 打印结果
        print(first); // Pictures
        print(last); // /mnt/shared/Pictures
        if(!first.contains("/") && last.contains("/")){
          print(first);
          print(last);
        }
      });
    }
    if (outLines == null || outLines.isEmpty) {
      devicesList.add(UDiskModel('/sdcard/', '/sdcard/'));
    } else {
      var value = await controller.show(
        context,
        devicesList,
        UDiskModel('/sdcard/', '/sdcard/'),
        title: "请选择根目录",
        tipText: "请输入需要筛选的属性",
        notFoundText: "没有找到相关的",
      );
      if (value != null) {
        if (value.rootPath == '/sdcard/') {
          rootPath = value.rootName;
          currentPath = value.rootName;
          await getFileList();
        } else {
          rootPath = value.rootPath;
          currentPath = value.rootPath;
          await getFileList();
        }
      }
    }
  }

  List<PopupMenuEntry<int>> _getOperate(int fileType) {
    if (FileManagerViewModel.typeFolder == fileType) {
      //文件夹的话支持导入
      return [
        const PopupMenuItem(child: TextView('删除'), value: 1),
        const PopupMenuItem(child: TextView('保存至电脑'), value: 2),
        const PopupMenuItem(child: TextView('导入文件'), value: 3),
        const PopupMenuItem(child: TextView('导入文件夹'), value: 4),
      ];
    } else {
      return [
        const PopupMenuItem(child: TextView('删除'), value: 1),
        const PopupMenuItem(child: TextView('保存至电脑'), value: 2),
      ];
    }
  }

  /// 删除文件
  Future<void> deleteFile(int index) async {
    var result = await execAdb([
      "-s",
      deviceId,
      "shell",
      "rm",
      "-rf",
      currentPath + files.value[index].name
    ]);
    if (result != null && result.exitCode == 0) {
      files.removeAt(index);
      notifyListeners();
      showResultDialog(content: "删除成功");
    } else {
      showResultDialog(content: "删除失败");
    }
  }

  //导入文件
  Future<void> importFile(int index) async {
    var file = await openFile();
    if (file == null) return;
    var result = await execAdb([
      "-s",
      deviceId,
      "push",
      file.path,
      currentPath + files.value[index].name
    ]);
    if (result != null && result.exitCode == 0) {
      showResultDialog(content: "导入文件成功");
    } else {
      showResultDialog(content: "导入文件失败");
    }
  }

  //导入文件夹
  Future<void> importFolder(int index) async {
    var folderPath = await getDirectoryPath();
    if (folderPath == null) return;
    var result = await execAdb([
      "-s",
      deviceId,
      "push",
      "-a",
      folderPath,
      currentPath + files.value[index].name
    ]);
    if (result != null && result.exitCode == 0) {
      showResultDialog(content: "导入文件夹成功");
    } else {
      showResultDialog(content: "导入文件夹失败");
    }
  }

  /// 保存文件
  Future<void> saveFile(int index) async {
    var savePath =
        await getSaveLocation(suggestedName: files.value[index].name);
    if (savePath == null) return;
    var result = await execAdb([
      "-s",
      deviceId,
      "pull",
      currentPath + files.value[index].name,
      savePath.path
    ]);
    if (result != null && result.exitCode == 0) {
      showResultDialog(content: "保存成功");
    } else {
      showResultDialog(content: "保存失败");
    }
  }

  void refresh() {
    getFileList();
  }
}
