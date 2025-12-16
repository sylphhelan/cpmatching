import 'dart:ui'; // 用于 ImageFilter
import 'package:flutter/foundation.dart'; // 用于 kIsWeb
import 'package:flutter/gestures.dart'; // 用于配置鼠标拖拽
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

// =========================================================
// 🍬 设计系统：清新马卡龙配色
// =========================================================
class AppColors {
  static const Color background = Color(0xFFE0F7FA);
  static const Color primary = Color(0xFF00BFA5);
  static const Color accentPink = Color(0xFFFF80AB);
  static const Color textMain = Color(0xFF263238);
  static const Color textSub = Color(0xFF546E7A);
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF1744);
  static const Color cardSurface = Colors.white;
  static const Color lineInactive = Color(0xFFB0BEC5);
  static const Color lineActive = Color(0xFF00BFA5);
}

// -----------------------------------------------------------
// 🖱️ 鼠标拖拽支持
// -----------------------------------------------------------
class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

void main() {
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "CP Match",
      scrollBehavior: CustomScrollBehavior(),
      home: const MenuPage(),
    ),
  );
}

// -----------------------------------------------------------
// 🎵 音效 (空实现)
// -----------------------------------------------------------
class SoundHelper {
  static Future<void> playClick() async {
    if (kIsWeb) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}

// -----------------------------------------------------------
// 自定义组件
// -----------------------------------------------------------

class GameBackground extends StatelessWidget {
  final Widget child;
  const GameBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: child),
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  const ResponsiveContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: child,
      ),
    );
  }
}

class MinimalButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFilled;
  final IconData? icon;
  final Color? color;
  final double fontSize;

  const MinimalButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isFilled = true,
    this.icon,
    this.color,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.primary;
    final bool isDisabled = onPressed == null;

    return ElevatedButton(
      onPressed: isDisabled
          ? null
          : () {
              SoundHelper.playClick();
              onPressed!();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled
            ? Colors.grey[300]
            : (isFilled ? themeColor : Colors.white),
        foregroundColor: isDisabled
            ? Colors.grey[500]
            : (isFilled ? Colors.white : themeColor),
        elevation: 2,
        side: BorderSide(
          color: isDisabled ? Colors.transparent : themeColor,
          width: 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24),
            const SizedBox(width: 10),
          ],
          Text(
            text,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// 【关键修复】确保 CleanCard 类在 main.dart 中被正确定义
class CleanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const CleanCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class SmartImageDisplay extends StatelessWidget {
  final ImageProvider? imageProvider;
  final double borderRadius;
  final bool useBlurBackground;
  final Widget? placeholder;
  final BoxFit fit;

  const SmartImageDisplay({
    super.key,
    required this.imageProvider,
    this.borderRadius = 0,
    this.useBlurBackground = true,
    this.placeholder,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 空图片处理
    if (imageProvider == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: placeholder ?? Container(color: Colors.grey[200]),
      );
    }

    // 2. 【核心优化】如果不启用模糊背景（连线列表场景），直接返回简单图片
    // 这能极大减少 GPU 渲染压力，解决卡顿
    if (!useBlurBackground) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          color: Colors.white,
          child: Image(
            image: imageProvider!,
            fit: fit, // 通常是 cover 或 contain
            errorBuilder: (ctx, err, stack) =>
                const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }

    // 3. 启用模糊背景（仅在查看大图或画廊时使用）
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: imageProvider!,
            fit: BoxFit.cover,
            color: Colors.white.withValues(alpha: 0.7),
            colorBlendMode: BlendMode.lighten,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.white.withValues(alpha: 0.1)),
          ),
          Center(
            child: Image(
              image: imageProvider!,
              fit: fit,
              errorBuilder: (ctx, err, stack) =>
                  const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// 数据模型
// -----------------------------------------------------------
class ItemModel {
  String id;
  String assetPath;
  XFile? customFile;
  final bool isOfficialOne;

  ItemModel({
    required this.id,
    required String imagePath,
    this.isOfficialOne = false,
  }) : assetPath = imagePath;

  ImageProvider? get imageProvider {
    if (customFile != null) {
      if (kIsWeb) {
        return NetworkImage(customFile!.path);
      } else {
        return FileImage(File(customFile!.path));
      }
    }
    if (assetPath == 'placeholder' || assetPath.isEmpty) return null;
    return AssetImage(assetPath);
  }
}

class CPPair {
  final String id;
  final String name;
  ItemModel left;
  ItemModel right;
  ItemModel cpPhoto;

  CPPair({
    required this.id,
    required this.name,
    required this.left,
    required this.right,
    required this.cpPhoto,
  });
}

// -----------------------------------------------------------
// 1. 出题人后台 (MenuPage)
// -----------------------------------------------------------
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final ImagePicker _picker = ImagePicker();

  static const int minPairs = 6;
  static const int maxPairs = 12;

  List<CPPair> pairs = [];

  @override
  void initState() {
    super.initState();
    _updatePairCount(8);
  }

  void _updatePairCount(int count) {
    setState(() {
      if (count > pairs.length) {
        for (int i = pairs.length + 1; i <= count; i++) {
          pairs.add(
            CPPair(
              id: 'cp$i',
              name: 'CP 组 $i',
              left: ItemModel(
                id: 'cp$i',
                imagePath: 'assets/images/1.png',
                isOfficialOne: true,
              ),
              right: ItemModel(
                id: 'cp$i',
                imagePath: 'assets/images/r1.png',
                isOfficialOne: false,
              ),
              cpPhoto: ItemModel(id: 'cp$i', imagePath: 'placeholder'),
            ),
          );
        }
      } else if (count < pairs.length) {
        pairs = pairs.sublist(0, count);
      }
    });
  }

  Future<void> _pickImage(
    ItemModel targetModel, {
    bool isCPPhoto = false,
  }) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (Platform.isAndroid) await Permission.photos.request();
    }
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (pickedFile == null) return;
      if (!mounted) return;

      XFile? finalFile;
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        finalFile = pickedFile;
      } else {
        if (kIsWeb) {
          finalFile = pickedFile;
        } else {
          final cropRatio = isCPPhoto
              ? const CropAspectRatio(ratioX: 16, ratioY: 9)
              : const CropAspectRatio(ratioX: 3, ratioY: 4);
          final CroppedFile? croppedFile = await ImageCropper().cropImage(
            sourcePath: pickedFile.path,
            aspectRatio: cropRatio,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: '裁切',
                toolbarColor: Colors.white,
                toolbarWidgetColor: Colors.black,
                activeControlsWidgetColor: AppColors.primary,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: true,
              ),
              IOSUiSettings(title: '裁切', aspectRatioLockEnabled: true),
            ],
          );
          if (croppedFile != null) finalFile = XFile(croppedFile.path);
        }
      }

      if (finalFile != null) {
        // 【新增优化】如果之前有图片，从缓存中驱逐它，释放内存
        if (targetModel.customFile != null) {
          await FileImage(File(targetModel.customFile!.path)).evict();
        }

        setState(() {
          targetModel.customFile = finalFile;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _swapPosition(int index) {
    setState(() {
      final temp = pairs[index].left;
      pairs[index].left = pairs[index].right;
      pairs[index].right = temp;
    });
  }

  void _startPlayerMode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SortPage(allPairs: pairs)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameBackground(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "出题配置",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMain,
                      ),
                    ),
                    MinimalButton(
                      text: "开始游戏",
                      icon: Icons.play_arrow_rounded,
                      onPressed: _startPlayerMode,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "请注意：左为 1 (攻)，右为 0 (受)，中间按钮可交换。",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.grey,
                            size: 30,
                          ),
                          onPressed: pairs.length > minPairs
                              ? () => _updatePairCount(pairs.length - 1)
                              : null,
                        ),
                        const Text(
                          "减少CP",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "${pairs.length} 组",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: AppColors.primary,
                            size: 30,
                          ),
                          onPressed: pairs.length < maxPairs
                              ? () => _updatePairCount(pairs.length + 1)
                              : null,
                        ),
                        const Text(
                          "增加CP",
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 900
                    ? 3
                    : (constraints.maxWidth > 600 ? 2 : 1);

                return ResponsiveContainer(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: pairs.length,
                    itemBuilder: (context, index) {
                      final pair = pairs[index];
                      return CleanCard(
                        key: ValueKey(pair.id),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  pair.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textMain,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildClickableImage(
                                      pair.left,
                                      () => _pickImage(pair.left),
                                      "点击上传\n1 (攻)",
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.swap_horiz,
                                          color: AppColors.primary,
                                          size: 32,
                                        ),
                                        onPressed: () => _swapPosition(index),
                                        tooltip: "交换位置",
                                      ),
                                      const Text(
                                        "交换",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSub,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: _buildClickableImage(
                                      pair.right,
                                      () => _pickImage(pair.right),
                                      "点击上传\n0 (受)",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    _pickImage(pair.cpPhoto, isCPPhoto: true),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: SmartImageDisplay(
                                    imageProvider: pair.cpPhoto.imageProvider,
                                    borderRadius: 12,
                                    fit: BoxFit.cover,
                                    placeholder: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.add_photo_alternate_rounded,
                                            color: AppColors.accentPink,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            "上传横屏合照 (奖励)",
                                            style: TextStyle(
                                              color: AppColors.accentPink,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableImage(ItemModel item, VoidCallback onTap, String hint) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
        ),
        child: SmartImageDisplay(
          imageProvider: item.imageProvider,
          borderRadius: 12,
          placeholder: Center(
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// 2. 第一关：分阵营 (SortPage) - 【增量修复：双击放大+提示】
// -----------------------------------------------------------
class SortPage extends StatefulWidget {
  final List<CPPair> allPairs;
  const SortPage({super.key, required this.allPairs});
  @override
  State<SortPage> createState() => _SortPageState();
}

class _SortPageState extends State<SortPage> {
  late List<ItemModel> unsortedQueue;
  final List<ItemModel> leftList = [];
  final List<ItemModel> rightList = [];
  final List<ItemModel> historyStack = [];
  bool isSortingFinished = false;

  @override
  void initState() {
    super.initState();
    List<ItemModel> allItems = [];
    for (var p in widget.allPairs) {
      allItems.add(p.left);
      allItems.add(p.right);
    }
    unsortedQueue = List.from(allItems)..shuffle();
  }

  void _vote(bool isOne) {
    if (unsortedQueue.isEmpty) return;
    SoundHelper.playClick();
    HapticFeedback.selectionClick();
    setState(() {
      final item = unsortedQueue.removeAt(0);
      historyStack.add(item);
      if (isOne)
        leftList.add(item);
      else
        rightList.add(item);
      if (unsortedQueue.isEmpty) isSortingFinished = true;
    });
  }

  void _undo() {
    if (historyStack.isEmpty) return;
    SoundHelper.playClick();
    setState(() {
      final lastItem = historyStack.removeLast();
      if (leftList.contains(lastItem))
        leftList.remove(lastItem);
      else
        rightList.remove(lastItem);
      unsortedQueue.insert(0, lastItem);
      isSortingFinished = false;
    });
  }

  void _moveItemInReview(ItemModel item, bool toRight) {
    SoundHelper.playClick();
    setState(() {
      if (toRight) {
        leftList.remove(item);
        rightList.add(item);
      } else {
        rightList.remove(item);
        leftList.add(item);
      }
    });
  }

  // 【新增】双击放大功能
  void _showZoomDialog(ItemModel item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: InteractiveViewer(
          child: Center(
            child: Image(image: item.imageProvider!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  void _goToConnectStage() {
    if (leftList.length != rightList.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("两边人数不平衡，无法开始！"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CPGamePage(
          userSelectedLeft: leftList,
          userSelectedRight: rightList,
          allPairs: widget.allPairs,
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("退出"),
            content: const Text("退出将丢失进度，确定吗？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text("退出"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: GameBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textMain,
                    ),
                    onPressed: () async {
                      if (await _onWillPop()) {
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                  Text(
                    isSortingFinished ? "确认攻受" : "第一关：辨别攻受",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  if (!isSortingFinished && historyStack.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.undo, color: AppColors.textMain),
                      onPressed: _undo,
                      tooltip: "撤销",
                    ),
                ],
              ),
            ),
            // 【新增】文字提示：双击放大
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                "(双击图片可放大)",
                style: TextStyle(color: AppColors.textSub, fontSize: 14),
              ),
            ),
            Expanded(
              child: isSortingFinished ? _buildReviewUI() : _buildSortingUI(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortingUI() {
    final currentItem = unsortedQueue.first;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            const Spacer(),
            Container(
              height: MediaQuery.of(context).size.height * 0.6,
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: GestureDetector(
                onDoubleTap: () => _showZoomDialog(currentItem),
                child: SmartImageDisplay(
                  imageProvider: currentItem.imageProvider,
                  borderRadius: 24,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "他是 1 还是 0 ？",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MinimalButton(
                    text: "1 (攻)",
                    onPressed: () => _vote(true),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 30),
                  MinimalButton(
                    text: "0 (受)",
                    onPressed: () => _vote(false),
                    color: AppColors.accentPink,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewUI() {
    return Column(
      children: [
        const Text(
          "点击箭头可微调",
          style: TextStyle(fontSize: 14, color: AppColors.textSub),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildColumn("1号阵营", leftList, AppColors.primary, true),
              ),
              Expanded(
                child: _buildColumn(
                  "0号阵营",
                  rightList,
                  AppColors.accentPink,
                  false,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: MinimalButton(
            text: "确认无误，去连线",
            icon: Icons.check,
            onPressed: _goToConnectStage,
          ),
        ),
      ],
    );
  }

  Widget _buildColumn(
    String title,
    List<ItemModel> list,
    Color color,
    bool isLeft,
  ) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 18,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // 【新增】双击放大支持
                      GestureDetector(
                        onDoubleTap: () => _showZoomDialog(item),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: SmartImageDisplay(
                            imageProvider: item.imageProvider,
                            borderRadius: 8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          isLeft ? Icons.arrow_forward : Icons.arrow_back,
                          color: color,
                          size: 24,
                        ),
                        onPressed: () => _moveItemInReview(item, isLeft),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// 3 & 4 & 5. 玩家连线 (CPGamePage) - 【增量修复：红框只看1/0错误】
// -----------------------------------------------------------
class CPGamePage extends StatefulWidget {
  final List<ItemModel> userSelectedLeft;
  final List<ItemModel> userSelectedRight;
  final List<CPPair> allPairs;

  const CPGamePage({
    super.key,
    required this.userSelectedLeft,
    required this.userSelectedRight,
    required this.allPairs,
  });
  @override
  State<CPGamePage> createState() => _CPGamePageState();
}

class _CPGamePageState extends State<CPGamePage> {
  late List<ItemModel> leftItems;
  late List<ItemModel> rightItems;
  final Map<ItemModel, GlobalKey> keys = {};
  final Map<ItemModel, ItemModel> connectedPairs = {};
  final GlobalKey _scrollingContentKey = GlobalKey();

  ItemModel? selectedItem;
  bool isSubmitted = false;
  bool isSecondRound = false;
  bool isRound1ReviewMode = false;
  int round1MatchScore = 0;
  int round1PositionScore = 0;

  @override
  void initState() {
    super.initState();
    leftItems = List.from(widget.userSelectedLeft);
    rightItems = List.from(widget.userSelectedRight);
    rightItems.shuffle();
    _initGame();
  }

  void _initGame() {
    keys.clear();
    for (var item in [...leftItems, ...rightItems]) {
      keys[item] = GlobalKey();
    }
  }

  void _submit() {
    if (connectedPairs.length < leftItems.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("还没连完！"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!isSecondRound) {
      int matchScore = 0;
      int positionScore = 0;
      connectedPairs.forEach((left, right) {
        if (left.id == right.id) matchScore++;
        if (left.isOfficialOne) positionScore++;
      });
      round1MatchScore = matchScore;
      round1PositionScore = positionScore;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("第一轮成绩"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _resultRow(
                "配对正确",
                round1MatchScore,
                leftItems.length,
                AppColors.primary,
              ),
              const SizedBox(height: 10),
              _resultRow(
                "攻受站对",
                round1PositionScore,
                leftItems.length,
                AppColors.accentPink,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  isSubmitted = true;
                  isRound1ReviewMode = true;
                  selectedItem = null;
                });
              },
              child: const Text(
                "复盘 (查看连线)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            MinimalButton(
              text: "进入终极连线",
              onPressed: () {
                Navigator.pop(context);
                _startSecondRound();
              },
            ),
          ],
        ),
      );
    } else {
      int finalMatchScore = 0;
      connectedPairs.forEach((left, right) {
        if (left.id == right.id) finalMatchScore++;
      });

      bool isPerfect = finalMatchScore == leftItems.length;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("最终成绩"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPerfect
                    ? "完美通关！🎉"
                    : "最终结果: $finalMatchScore/${leftItems.length}",
                style: const TextStyle(color: AppColors.textMain, fontSize: 18),
              ),
              const SizedBox(height: 20),
              const Text(
                "🎁 通关奖励：\nCP 相册",
                style: TextStyle(
                  color: AppColors.accentPink,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            if (!isPerfect)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    isSubmitted = true;
                    isRound1ReviewMode = true;
                    selectedItem = null;
                  });
                },
                child: const Text(
                  "复盘 (查看答案)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

            MinimalButton(
              text: "前往CP相册",
              icon: Icons.collections,
              color: AppColors.accentPink,
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CPGalleryPage(pairs: widget.allPairs),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _resultRow(String label, int score, int total, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: AppColors.textSub),
        ),
        Text(
          "$score/$total",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _startSecondRound() {
    setState(() {
      isSubmitted = false;
      isRound1ReviewMode = false;
      connectedPairs.clear();
      selectedItem = null;
      isSecondRound = true;
      List<ItemModel> allItems = [...leftItems, ...rightItems];
      leftItems = allItems.where((i) => i.isOfficialOne).toList();
      rightItems = allItems.where((i) => !i.isOfficialOne).toList();
      rightItems.shuffle();
      _initGame();
    });
  }

  void _handleItemTap(ItemModel item) {
    if (isSubmitted) return;
    SoundHelper.playClick();
    HapticFeedback.selectionClick();
    setState(() {
      if (selectedItem == null)
        selectedItem = item;
      else if (selectedItem == item)
        selectedItem = null;
      else {
        bool isItemTop = leftItems.contains(item);
        bool isSelectedTop = leftItems.contains(selectedItem);

        if (isItemTop == isSelectedTop) {
          selectedItem = item;
        } else {
          HapticFeedback.lightImpact();
          ItemModel topOne = isSelectedTop ? selectedItem! : item;
          ItemModel bottomOne = isSelectedTop ? item : selectedItem!;
          connectedPairs.remove(topOne);
          connectedPairs.removeWhere((key, value) => value == bottomOne);
          connectedPairs[topOne] = bottomOne;
          selectedItem = null;
        }
      }
    });
  }

  void _showZoomDialog(ItemModel item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: InteractiveViewer(
          child: Center(
            child: Image(image: item.imageProvider!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("⚠️ 警告"),
            content: const Text("现在退出将丢失进度，确定吗？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("继续"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text("退出"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            isSecondRound ? "第二关：终极连线" : "第二关：直觉连线",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1600),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    isSubmitted
                        ? (isRound1ReviewMode ? "查看结果 (绿=对 红=错)" : "查看结果")
                        : "点击连线 (需全部连完) (双击可放大)",
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double totalWidth = constraints.maxWidth;
                      int itemCount = leftItems.length;
                      double availableWidth =
                          totalWidth - 40 - ((itemCount - 1) * 20);
                      double cardWidth = (availableWidth / itemCount).clamp(
                        80.0,
                        200.0,
                      );

                      if (itemCount > 8 && !kIsWeb) cardWidth = 60;

                      double cardHeight = cardWidth * (4 / 3);

                      // 判断是否手机布局
                      bool isMobileLayout =
                          constraints.maxWidth < 600 ||
                          constraints.maxHeight > constraints.maxWidth;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          key: _scrollingContentKey,
                          child: Stack(
                            children: [
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (!isMobileLayout) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      "1 (攻)",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                  ],

                                  // 上排 / 左列
                                  isMobileLayout
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  const Text(
                                                    "1 (攻)",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  ...leftItems
                                                      .map(
                                                        (e) => _buildItem(
                                                          e,
                                                          100,
                                                          133,
                                                          true,
                                                        ),
                                                      )
                                                      .toList(),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 40),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  const Text(
                                                    "0 (受)",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppColors.accentPink,
                                                    ),
                                                  ),
                                                  ...rightItems
                                                      .map(
                                                        (e) => _buildItem(
                                                          e,
                                                          100,
                                                          133,
                                                          true,
                                                        ),
                                                      )
                                                      .toList(),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: leftItems
                                                    .map(
                                                      (e) => _buildItem(
                                                        e,
                                                        cardWidth,
                                                        cardHeight,
                                                        false,
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 350,
                                            ), // 中间连线区
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: rightItems
                                                    .map(
                                                      (e) => _buildItem(
                                                        e,
                                                        cardWidth,
                                                        cardHeight,
                                                        false,
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            const Text(
                                              "0 (受)",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accentPink,
                                              ),
                                            ),
                                            const SizedBox(height: 80),
                                          ],
                                        ),
                                ],
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: LinePainter(
                                      connectedPairs: connectedPairs,
                                      currentStartItem: selectedItem,
                                      itemKeys: keys,
                                      isSubmitted: isSubmitted,
                                      contentKey: _scrollingContentKey,
                                      isRound1ReviewMode: isRound1ReviewMode,
                                      leftItems: leftItems,
                                      rightItems: rightItems,
                                      isMobileLayout: isMobileLayout,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: isRound1ReviewMode
            ? (isSecondRound
                  ? MinimalButton(
                      text: "前往CP相册",
                      icon: Icons.collections,
                      color: AppColors.accentPink,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CPGalleryPage(pairs: widget.allPairs),
                          ),
                        );
                      },
                    )
                  : MinimalButton(
                      text: "进入第二轮",
                      onPressed: _startSecondRound,
                      icon: Icons.arrow_forward,
                    ))
            : (!isSubmitted
                  ? MinimalButton(
                      text: "提交答案",
                      onPressed: _submit,
                      icon: Icons.check_circle,
                    )
                  : null),
      ),
    );
  }

  Widget _buildItem(ItemModel item, double w, double h, bool isMobile) {
    bool isSelected = selectedItem == item;
    bool isConnected =
        connectedPairs.containsKey(item) || connectedPairs.containsValue(item);

    Color borderColor = Colors.transparent;
    double borderWidth = 0;
    IconData? statusIcon;

    // 【核心修复：第一轮复盘逻辑】
    // 只判定 1/0 站位是否正确，不判定连线
    if (isRound1ReviewMode && isSubmitted && !isSecondRound) {
      bool isLeft = leftItems.contains(item);
      bool isOfficialOne = item.isOfficialOne;
      // 规则：在左边且是1 OR 在右边且是0 -> 正确
      bool isPosCorrect =
          (isLeft && isOfficialOne) || (!isLeft && !isOfficialOne);

      if (isPosCorrect) {
        borderColor = AppColors.success;
        borderWidth = 4;
        statusIcon = Icons.check;
      } else {
        borderColor = AppColors.error;
        borderWidth = 4;
        statusIcon = Icons.close; // 错误显示 X
      }
    } else {
      // 游戏进行中
      if (isSelected) {
        borderColor = AppColors.primary;
        borderWidth = 4;
      } else if (isConnected) {
        borderColor = AppColors.primary.withValues(alpha: 0.3);
        borderWidth = 2;
        statusIcon = Icons.check;
      }
    }

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8.0 : 6.0),
      // 【点击响应修复】
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 确保空白处也能点
        onTap: () => _handleItemTap(item),
        onDoubleTap: () => _showZoomDialog(item),
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 50),
          child: Container(
            key: keys[item],
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth > 0
                          ? borderWidth
                          : (isSelected ? 3 : 0),
                    ),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : (borderColor == AppColors.error
                                  ? AppColors.error.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.05)),
                        blurRadius: isSelected ? 15 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    child: AspectRatio(
                      aspectRatio: 3.0 / 4.0,
                      child: SmartImageDisplay(
                        imageProvider: item.imageProvider,
                        borderRadius: 13,
                        useBlurBackground: false,
                      ),
                    ),
                  ),
                ),
                // 只有已连接 或 复盘时 才显示图标
                if (isConnected || (isRound1ReviewMode && !isSecondRound))
                  Positioned(
                    bottom: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: borderColor == AppColors.error
                            ? AppColors.error
                            : AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        statusIcon ?? Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// 5. CP相册 (修复：无图时使用 bg.png 占位，防止放大卡死)
// -----------------------------------------------------------
class CPGalleryPage extends StatelessWidget {
  final List<CPPair> pairs;
  const CPGalleryPage({super.key, required this.pairs});

  @override
  Widget build(BuildContext context) {
    return GameBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "CP相册",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.home, color: AppColors.textMain),
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              "点击图片可查看大图",
              style: TextStyle(color: AppColors.textSub),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: pairs.length,
              itemBuilder: (context, index) {
                final pair = pairs[index];

                // 【核心修复】如果没上传合照，强制使用 bg.png
                final ImageProvider displayImage =
                    pair.cpPhoto.imageProvider ??
                    const AssetImage('assets/images/bg.png');

                return CleanCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black,
                                builder: (ctx) => GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: InteractiveViewer(
                                    child: Center(
                                      // 【修复】这里使用安全的 displayImage，不会报错了
                                      child: Image(image: displayImage),
                                    ),
                                  ),
                                ),
                              );
                            },
                            // 【修复】展示图也使用 displayImage
                            child: SmartImageDisplay(
                              imageProvider: displayImage,
                              borderRadius: 0,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Text(
                              pair.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.favorite,
                              color: AppColors.accentPink,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final Map<ItemModel, ItemModel> connectedPairs;
  final ItemModel? currentStartItem;
  final Map<ItemModel, GlobalKey> itemKeys;
  final bool isSubmitted;
  final GlobalKey contentKey;
  final bool isRound1ReviewMode;
  final List<ItemModel>? leftItems;
  final List<ItemModel>? rightItems;
  final bool isMobileLayout;

  LinePainter({
    required this.connectedPairs,
    required this.currentStartItem,
    required this.itemKeys,
    required this.isSubmitted,
    required this.contentKey,
    this.isRound1ReviewMode = false,
    this.leftItems,
    this.rightItems,
    this.isMobileLayout = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    connectedPairs.forEach((startItem, endItem) {
      final start = _getOffset(startItem);
      final end = _getOffset(endItem);
      if (start != null && end != null) {
        bool isDimmed = currentStartItem != null;

        if (!isSubmitted) {
          paint.color = isDimmed ? AppColors.lineInactive : AppColors.primary;
          paint.strokeWidth = isDimmed ? 1.5 : 3.0;
        } else {
          // 第二关(官方修正)：连线对错显示红绿
          // 第一关(直觉)：根据需求“错误的连线把连线标红”
          bool isCorrect = (startItem.id == endItem.id);
          paint.color = isCorrect ? AppColors.success : AppColors.error;
          paint.strokeWidth = 3.0;
        }
        _drawCurve(canvas, start, end, paint);
      }
    });
  }

  void _drawCurve(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final Path path = Path();
    path.moveTo(p1.dx, p1.dy);

    if (isMobileLayout) {
      double controlX = (p2.dx - p1.dx) / 2;
      path.cubicTo(
        p1.dx + controlX,
        p1.dy,
        p2.dx - controlX,
        p2.dy,
        p2.dx,
        p2.dy,
      );
    } else {
      double controlY = (p2.dy - p1.dy) / 2;
      path.cubicTo(
        p1.dx,
        p1.dy + controlY,
        p2.dx,
        p2.dy - controlY,
        p2.dx,
        p2.dy,
      );
    }
    canvas.drawPath(path, paint);
  }

  Offset? _getOffset(ItemModel item) {
    final key = itemKeys[item];
    final RenderBox? contentBox =
        contentKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? itemBox =
        key?.currentContext?.findRenderObject() as RenderBox?;
    if (key == null || contentBox == null || itemBox == null) return null;

    final center = itemBox.size.center(Offset.zero);
    final globalPos = itemBox.localToGlobal(center, ancestor: contentBox);
    double halfSize = isMobileLayout
        ? itemBox.size.width / 2
        : itemBox.size.height / 2;

    if (isMobileLayout) {
      // 手机模式：左列连右边，右列连左边
      bool isLeftCol = leftItems?.contains(item) ?? false;
      return globalPos.translate(
        isLeftCol ? (halfSize + 0) : -(halfSize + 0),
        0,
      );
    } else {
      // 【核心修复】连线坐标偏移
      // 电脑模式：上列连下边(BottomCenter)，下列连上边(TopCenter)
      bool isTopRow = leftItems?.contains(item) ?? false;

      // 注意：halfSize 是半高
      // isTopRow (1号) -> 需要连下面 -> center.dy + halfHeight
      // !isTopRow (0号) -> 需要连上面 -> center.dy - halfHeight
      // 之前代码加了 padding 导致偏移，现在直接用边缘
      return globalPos.translate(
        0,
        isTopRow ? (halfSize + 2) : -(halfSize + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) => true;
}
