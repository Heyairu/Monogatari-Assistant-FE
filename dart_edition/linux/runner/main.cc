#include "my_application.h"
#include <gtk/gtk.h>

int main(int argc, char** argv) {
  // 設置 GTK 環境變數以優化 Arch Linux 渲染
  g_setenv("GDK_BACKEND", "x11", TRUE);  // 強制使用 X11 後端
  g_setenv("GDK_RENDERING", "gl", TRUE);  // 啟用 OpenGL 渲染
  g_setenv("GTK_THEME", "Adwaita", FALSE);  // 使用預設主題避免衝突
  
  // 初始化 GTK
  gtk_init(&argc, &argv);
  
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
