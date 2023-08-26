import '../../widget/list_filter_dialog.dart';

class UDiskModel extends ListFilterItem{
  //根目录
  String rootName;
  //根路径
  String rootPath;

  UDiskModel(this.rootName, this.rootPath, ) : super(rootName);

}