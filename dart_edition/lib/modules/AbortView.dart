import "package:flutter/material.dart";

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 應用圖標
              Container(
                padding: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icon/Title.png',

                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // 如果圖片載入失敗，顯示預設圖標
                      return Icon(
                        Icons.edit_note,
                        size: 80,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 應用名稱
              Text(
                "物語Assistant",
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 版本狀態
              Text(
                "Beta 1",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              // 版本號
              Text(
                "版本 0.1.14",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 描述
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  "物語Assistant 是一個專為作家和創作者設計的寫作輔助工具。"
                  "它提供了完整的故事管理功能，包括章節管理、角色設定、世界觀建構等，"
                  "讓您能夠更輕鬆地組織和創作您的故事。",
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 功能特點
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "主要功能",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(context, Icons.book, "故事設定管理"),
                    _buildFeatureItem(context, Icons.menu_book, "章節與段落編輯"),
                    _buildFeatureItem(context, Icons.list, "大綱規劃"),
                    _buildFeatureItem(context, Icons.public, "世界觀設定"),
                    _buildFeatureItem(context, Icons.person, "角色資料庫"),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 版權信息
              Text(
                "© 2025 Heyairu(部屋伊琉).",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
