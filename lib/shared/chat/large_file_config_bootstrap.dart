import 'package:tencent_cloud_chat_uikit/config/large_file_config.dart';

import '../services/im_api.dart';

/// 为 UIKit 大文件 / 图片上传注册预签名 COS 配置（与 App [ChatCubit.init] 一致）。
void ensureLargeFileConfig(ImApi imApi) {
  if (LargeFileConfig.isConfigured()) return;
  LargeFileConfig.setConfig(
    LargeFileUploadConfig(
      getPresignedUpload: (fileName) async {
        final upload = await imApi.generatePresignedUpload(fileName);
        return PresignedUploadCredential(uploadUrl: upload.uploadUrl, fileId: upload.fileId);
      },
      resolveFileUrl: (fileId) async => await imApi.resolveFileUrl(fileId) ?? '',
    ),
  );
}
