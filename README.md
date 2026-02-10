# Chat UIKit

## Product Introduction
Build real-time social messaging capabilities with all the features into your applications and websites based on powerful and feature-rich chat APIs, SDKs and UIKit components.

<table style="text-align:center; vertical-align:middle; width:440px">
  <tr>
    <th style="text-align:center;" width="160px">Android App</th>
    <th style="text-align:center;" width="160px">iOS App</th>
  </tr>
  <tr>
    <td><img style="width:160px" src="https://qcloudimg.tencent-cloud.cn/raw/078fbb462abd2253e4732487cad8a66d.png"/></td>
    <td><img style="width:160px" src="https://qcloudimg.tencent-cloud.cn/raw/b1ea5318e1cfce38e4ef6249de7a4106.png"/></td>
   </tr>
</table>

TUIKit is a UI component library based on Tencent Chat SDK. It provides universal UI components to offer features such as conversation, chat, search, relationship chain, group, and audio/video call features.

<img src=https://qcloudimg.tencent-cloud.cn/raw/9c893f1a9c6368c82d44586907d5293d.png width=70% />

## Changelog
## Latest Enhanced Version 8.9.7511 @2026.02.10
### SDK
- Added streaming message capability
- Supports fetching read timestamps for group application lists (C API)
- Supports batch marking group application lists as read (C API)
- Fixed issue where synchronized conversation marker information could be lost during login if local conversation did not exist
- Fixed potential failure to update atAll data in conversation information under multi-device login scenarios
- Fixed abnormal behavior when fetching merged message lists after locally inserting merged messages
- Fixed failure to pull nested merged messages in offline scenarios
- Optimized SDK stability
### TUIKit & Demo
- Added official account capability (iOS & Android)
- Added voice cloning capability (iOS)
- Added text-to-speech capability (iOS)
- Fixed issue where "@ mentions" notification would not display when entering chat interface with more than 2 pinned messages (iOS)
