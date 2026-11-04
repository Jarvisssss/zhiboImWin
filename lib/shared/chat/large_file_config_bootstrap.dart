import 'package:tencent_cloud_chat_uikit/config/large_file_config.dart';

import '../services/cos_api.dart';

/// 为 UIKit 注册大文件上传：走猩子Talk 小程序同源 `/im/sys/cos/*` + `X-Access-Token`。
void ensureLargeFileConfig(CosApi cosApi) {
  if (LargeFileConfig.isConfigured()) return;
  LargeFileConfig.setConfig(
    LargeFileUploadConfig(
      relayUploadFile: (filePath, {required fileName, onProgress}) async {
        return cosApi.uploadLargeFile(
          filePath,
          fileName: fileName,
          onProgress: onProgress,
        );
      },
      resolveFileUrl: (fileId) async => await cosApi.resolveFileHttpUrl(fileId) ?? '',
    ),
  );
}
