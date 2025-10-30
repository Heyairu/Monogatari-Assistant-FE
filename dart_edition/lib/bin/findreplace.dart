import 'package:flutter/material.dart';

// 搜尋選項類別
class FindReplaceOptions {
  bool matchCase; // 大小寫相同
  bool wholeWord; // 全字拼寫需相符(限半形字元)
  bool useWildcard; // 使用萬用字元
  bool matchWidth; // 全半形須相符
  bool ignorePunctuation; // 略過標點符號
  bool ignoreWhitespace; // 略過空白字元

  FindReplaceOptions({
    this.matchCase = false,
    this.wholeWord = false,
    this.useWildcard = false,
    this.matchWidth = false,
    this.ignorePunctuation = false,
    this.ignoreWhitespace = false,
  });
}

// 全域函數：顯示查找取代浮動視窗
void showFindReplaceWindow(
  BuildContext context, {
  TextEditingController? findController,
  TextEditingController? replaceController,
  FindReplaceOptions? options,
  Function(String findText, String replaceText, FindReplaceOptions options)? onFindNext,
  Function(String findText, String replaceText, FindReplaceOptions options)? onFindPrevious,
  Function(String findText, String replaceText, FindReplaceOptions options)? onReplace,
  Function(String findText, String replaceText, FindReplaceOptions options)? onReplaceAll,
  int? currentMatchIndex,
  int? totalMatches,
}) {
  // 如果沒有提供 controller，創建臨時的
  final tempFindController = findController ?? TextEditingController();
  final tempReplaceController = replaceController ?? TextEditingController();
  final tempOptions = options ?? FindReplaceOptions();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => FindReplaceFloatingWindow(
      findController: tempFindController,
      replaceController: tempReplaceController,
      options: tempOptions,
      onFindNext: onFindNext,
      onFindPrevious: onFindPrevious,
      onReplace: onReplace,
      onReplaceAll: onReplaceAll,
      currentMatchIndex: currentMatchIndex,
      totalMatches: totalMatches,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}

class FindReplaceFloatingWindow extends StatefulWidget {
  final TextEditingController findController;
  final TextEditingController replaceController;
  final FindReplaceOptions options;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onFindNext;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onFindPrevious;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onReplace;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onReplaceAll;
  final int? currentMatchIndex;
  final int? totalMatches;
  final VoidCallback? onClose;

  const FindReplaceFloatingWindow({
    Key? key,
    required this.findController,
    required this.replaceController,
    required this.options,
    this.onFindNext,
    this.onFindPrevious,
    this.onReplace,
    this.onReplaceAll,
    this.currentMatchIndex,
    this.totalMatches,
    this.onClose,
  }) : super(key: key);

  @override
  State<FindReplaceFloatingWindow> createState() => _FindReplaceFloatingWindowState();
}

class _FindReplaceFloatingWindowState extends State<FindReplaceFloatingWindow> {
  bool _isExpanded = false;
  bool _showOptions = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 40,
          top: 40,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.surface,
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 尋找內容列
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          '尋找內容:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: TextField(
                            controller: widget.findController,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              isDense: true,
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 顯示匹配數量
                      if (widget.totalMatches != null && widget.totalMatches! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(widget.currentMatchIndex ?? -1) + 1}/${widget.totalMatches}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // 尋找上一個按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onFindPrevious?.call(
                              widget.findController.text,
                              widget.replaceController.text,
                              widget.options,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.arrow_upward, size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 尋找下一個按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onFindNext?.call(
                              widget.findController.text,
                              widget.replaceController.text,
                              widget.options,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.arrow_downward, size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 折疊/展開按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                          ),
                          tooltip: _isExpanded ? '摺疊' : '展開取代',
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 選項按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _showOptions = !_showOptions;
                            });
                          },
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.tune,
                            size: 18,
                          ),
                          tooltip: '搜尋選項',
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 關閉按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  
                  // 可折疊的取代區域
                  if (_isExpanded) ...[
                    const SizedBox(height: 12),
                    
                    // 取代為列
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            '取代為:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: TextField(
                              controller: widget.replaceController,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                isDense: true,
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 取代按鈕（圖標）
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onReplace?.call(
                                widget.findController.text,
                                widget.replaceController.text,
                                widget.options,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                            child: Tooltip(
                              message: '取代',
                              child: const Icon(Icons.find_replace, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // 全部取代按鈕（圖標）
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onReplaceAll?.call(
                                widget.findController.text,
                                widget.replaceController.text,
                                widget.options,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                            ),
                            child: Tooltip(
                              message: '全部取代',
                              child: const Icon(Icons.library_add_check, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // 搜尋選項區域
                  if (_showOptions) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildOptionChip(
                          label: '大小寫需相同',
                          value: widget.options.matchCase,
                          onChanged: (value) {
                            setState(() {
                              widget.options.matchCase = value;
                            });
                          },
                        ),
                        _buildOptionChip(
                          label: '全字拼寫相符',
                          value: widget.options.wholeWord,
                          onChanged: (value) {
                            setState(() {
                              widget.options.wholeWord = value;
                            });
                          },
                        ),
                        _buildOptionChip(
                          label: '使用萬用字元',
                          value: widget.options.useWildcard,
                          onChanged: (value) {
                            setState(() {
                              widget.options.useWildcard = value;
                            });
                          },
                        ),
                        _buildOptionChip(
                          label: '全半形須相符',
                          value: widget.options.matchWidth,
                          onChanged: (value) {
                            setState(() {
                              widget.options.matchWidth = value;
                            });
                          },
                        ),
                        _buildOptionChip(
                          label: '略過標點符號',
                          value: widget.options.ignorePunctuation,
                          onChanged: (value) {
                            setState(() {
                              widget.options.ignorePunctuation = value;
                            });
                          },
                        ),
                        _buildOptionChip(
                          label: '略過空白字元',
                          value: widget.options.ignoreWhitespace,
                          onChanged: (value) {
                            setState(() {
                              widget.options.ignoreWhitespace = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOptionChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
      selected: value,
      onSelected: onChanged,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      labelPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
