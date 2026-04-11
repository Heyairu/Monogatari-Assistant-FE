import "package:flutter/material.dart";

class MonogatariTopAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final double iconSize;
  final bool isLoading;
  final bool showPunctuationPanel;
  final bool showFindReplaceWindow;
  final ValueChanged<String> onFileAction;
  final ValueChanged<String> onEditorAction;
  final VoidCallback onTogglePunctuationPanel;
  final VoidCallback onToggleFindReplaceWindow;

  const MonogatariTopAppBar({
    super.key,
    required this.iconSize,
    required this.isLoading,
    required this.showPunctuationPanel,
    required this.showFindReplaceWindow,
    required this.onFileAction,
    required this.onEditorAction,
    required this.onTogglePunctuationPanel,
    required this.onToggleFindReplaceWindow,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(
          "assets/icon/app_icon.png",
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.auto_stories, size: iconSize + 8);
          },
        ),
      ),
      titleSpacing: 0,
      title: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              PopupMenuButton<String>(
                icon: const Icon(Icons.folder),
                iconSize: iconSize,
                tooltip: "檔案",
                onSelected: onFileAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: "new",
                    child: ListTile(
                      leading: Icon(Icons.note_add),
                      title: Text("新建檔案"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: "open",
                    child: ListTile(
                      leading: Icon(Icons.folder_open),
                      title: Text("開啟檔案"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: "save",
                    child: ListTile(
                      leading: Icon(Icons.save),
                      title: Text("儲存檔案"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: "saveAs",
                    child: ListTile(
                      leading: Icon(Icons.save_as),
                      title: Text("另存新檔"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: "export_selective",
                    child: ListTile(
                      leading: Icon(Icons.output),
                      title: Text("匯出..."),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.select_all),
                onPressed: () => onEditorAction("selectAll"),
                tooltip: "Select All",
              ),
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.content_cut),
                onPressed: () => onEditorAction("cut"),
                tooltip: "Cut",
              ),
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.content_copy),
                onPressed: () => onEditorAction("copy"),
                tooltip: "Copy",
              ),
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.content_paste),
                onPressed: () => onEditorAction("paste"),
                tooltip: "Paste",
              ),

              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.undo),
                onPressed: () => onEditorAction("undo"),
                tooltip: "Undo",
              ),
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.redo),
                onPressed: () => onEditorAction("redo"),
                tooltip: "Redo",
              ),
              Container(
                decoration: showPunctuationPanel
                    ? BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: IconButton(
                  iconSize: iconSize,
                  icon: Icon(
                    showPunctuationPanel
                        ? Icons.keyboard_hide
                        : Icons.keyboard_alt,
                  ),
                  color: showPunctuationPanel
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                  onPressed: onTogglePunctuationPanel,
                  tooltip: showPunctuationPanel ? "關閉標點符號" : "標點符號",
                ),
              ),
              Container(
                decoration: showFindReplaceWindow
                    ? BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: IconButton(
                  iconSize: iconSize,
                  icon: Icon(
                    showFindReplaceWindow ? Icons.search_off : Icons.search,
                  ),
                  color: showFindReplaceWindow
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                  onPressed: onToggleFindReplaceWindow,
                  tooltip: showFindReplaceWindow ? "關閉搜尋" : "搜尋",
                ),
              ),

              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      elevation: 0,
    );
  }
}
