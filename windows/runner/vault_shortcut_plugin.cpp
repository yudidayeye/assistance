#include "vault_shortcut_plugin.h"

#include <objbase.h>
#include <shlobj.h>

#include <algorithm>
#include <cstdint>
#include <cwchar>
#include <filesystem>
#include <fstream>
#include <memory>
#include <string>
#include <vector>
#include <utility>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

namespace {

constexpr char kChannelName[] = "my_assistant/vault_shortcut";
constexpr wchar_t kShortcutExtension[] = L".lnk";

std::unique_ptr<flutter::PluginRegistrarWindows> g_registrar;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();

  const int length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(), static_cast<int>(utf8.size()),
      nullptr, 0);
  if (length <= 0) return std::wstring();

  std::wstring utf16(length, L'\0');
  if (::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                            static_cast<int>(utf8.size()), utf16.data(),
                            length) <= 0) {
    return std::wstring();
  }
  return utf16;
}

std::wstring GetDesktopPath() {
  PWSTR desktop_path = nullptr;
  const HRESULT result = ::SHGetKnownFolderPath(
      FOLDERID_Desktop, KF_FLAG_DEFAULT, nullptr, &desktop_path);
  if (FAILED(result) || desktop_path == nullptr) return std::wstring();

  std::wstring path(desktop_path);
  ::CoTaskMemFree(desktop_path);
  return path;
}

std::wstring GetExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  DWORD length = 0;
  do {
    length = ::GetModuleFileNameW(nullptr, path.data(),
                                  static_cast<DWORD>(path.size()));
    if (length == 0) return std::wstring();
    if (length < path.size() - 1) {
      path.resize(length);
      return path;
    }
    path.resize(path.size() * 2);
  } while (path.size() <= 32768);

  return std::wstring();
}

std::wstring SanitizeFileName(std::wstring value) {
  std::replace_if(value.begin(), value.end(), [](wchar_t character) {
    return character < 32 ||
           std::wcschr(L"<>:\"/\\|?*", character) != nullptr;
  }, L'_');

  while (!value.empty() && (value.back() == L'.' || value.back() == L' ')) {
    value.pop_back();
  }
  if (value.empty()) return L"未命名分类";
  return value.substr(0, 120);
}

std::string ErrorMessage(HRESULT result) {
  return "创建桌面快捷方式失败（Windows 错误码：" +
         std::to_string(static_cast<unsigned long>(result)) + "）";
}

std::filesystem::path GetShortcutIconDirectory() {
  PWSTR local_app_data = nullptr;
  const HRESULT result = ::SHGetKnownFolderPath(
      FOLDERID_LocalAppData, KF_FLAG_DEFAULT, nullptr, &local_app_data);
  if (FAILED(result) || local_app_data == nullptr) return {};

  std::filesystem::path directory(local_app_data);
  ::CoTaskMemFree(local_app_data);
  directory /= L"理解";
  directory /= L"shortcut-icons";

  std::error_code error;
  std::filesystem::create_directories(directory, error);
  if (error) return {};
  return directory;
}

// ICO 文件允许直接嵌入 PNG 数据。这样可以保留 Flutter 渲染出的分类图标，
// 同时无需引入额外的图片编解码库。
bool WritePngIco(const std::filesystem::path& icon_path,
                 const std::vector<uint8_t>& png_data) {
  if (png_data.empty() || png_data.size() > UINT32_MAX) return false;

  std::ofstream output(icon_path, std::ios::binary | std::ios::trunc);
  if (!output) return false;

  const auto write16 = [&output](uint16_t value) {
    const char bytes[2] = {static_cast<char>(value & 0xFF),
                           static_cast<char>((value >> 8) & 0xFF)};
    output.write(bytes, sizeof(bytes));
  };
  const auto write32 = [&output](uint32_t value) {
    const char bytes[4] = {static_cast<char>(value & 0xFF),
                           static_cast<char>((value >> 8) & 0xFF),
                           static_cast<char>((value >> 16) & 0xFF),
                           static_cast<char>((value >> 24) & 0xFF)};
    output.write(bytes, sizeof(bytes));
  };

  // ICONDIR
  write16(0);  // reserved
  write16(1);  // icon type
  write16(1);  // image count
  // ICONDIRENTRY，0 表示 256 像素，PNG 数据从偏移 22 开始。
  output.put(static_cast<char>(0));
  output.put(static_cast<char>(0));
  output.put(static_cast<char>(0));
  output.put(static_cast<char>(0));
  write16(1);  // color planes
  write16(32); // bits per pixel
  write32(static_cast<uint32_t>(png_data.size()));
  write32(22);
  output.write(reinterpret_cast<const char*>(png_data.data()),
               static_cast<std::streamsize>(png_data.size()));
  return output.good();
}
bool CreateDesktopShortcut(int category_id, const std::string& category_name,
                           const std::vector<uint8_t>& icon_data,
                           std::string* shortcut_path, std::string* error) {
  const std::wstring desktop_path = GetDesktopPath();
  const std::wstring executable_path = GetExecutablePath();
  const std::wstring category_name_utf16 = Utf16FromUtf8(category_name);
  if (desktop_path.empty() || executable_path.empty() ||
      (!category_name.empty() && category_name_utf16.empty())) {
    *error = "无法确定桌面或应用程序路径";
    return false;
  }

  const std::wstring shortcut_name =
      L"理解 - " + SanitizeFileName(category_name_utf16) + kShortcutExtension;
  const std::filesystem::path link_path =
      std::filesystem::path(desktop_path) / shortcut_name;
  const std::filesystem::path icon_directory = GetShortcutIconDirectory();
  if (icon_directory.empty()) {
    *error = "无法确定快捷方式图标保存路径";
    return false;
  }
  const std::filesystem::path icon_path =
      icon_directory / (L"vault-category-" + std::to_wstring(category_id) +
                        L".ico");
  if (!WritePngIco(icon_path, icon_data)) {
    *error = "无法生成分类快捷方式图标";
    return false;
  }

  const std::wstring arguments = L"--vault-category=" +
                                 std::to_wstring(category_id);

  IShellLinkW* shell_link = nullptr;
  HRESULT result = ::CoCreateInstance(CLSID_ShellLink, nullptr,
                                      CLSCTX_INPROC_SERVER,
                                      IID_PPV_ARGS(&shell_link));
  if (FAILED(result)) {
    *error = ErrorMessage(result);
    return false;
  }

  result = shell_link->SetPath(executable_path.c_str());
  if (SUCCEEDED(result)) result = shell_link->SetArguments(arguments.c_str());
  if (SUCCEEDED(result)) {
    result = shell_link->SetIconLocation(icon_path.c_str(), 0);
  }
  if (SUCCEEDED(result)) {
    result = shell_link->SetDescription(
        (L"打开密码保险箱分类：" + category_name_utf16).c_str());
  }
  if (SUCCEEDED(result)) {
    result = shell_link->SetWorkingDirectory(
        std::filesystem::path(executable_path).parent_path().c_str());
  }

  IPersistFile* persist_file = nullptr;
  if (SUCCEEDED(result)) {
    result = shell_link->QueryInterface(IID_PPV_ARGS(&persist_file));
  }
  if (SUCCEEDED(result)) {
    result = persist_file->Save(link_path.c_str(), TRUE);
  }

  if (persist_file != nullptr) persist_file->Release();
  shell_link->Release();

  if (FAILED(result)) {
    *error = ErrorMessage(result);
    return false;
  }

  *shortcut_path = link_path.u8string();
  return true;
}

}  // namespace

void RegisterVaultShortcutPlugin(flutter::PluginRegistry* registry) {
  g_registrar = std::make_unique<flutter::PluginRegistrarWindows>(
      registry->GetRegistrarForPlugin("VaultShortcutPlugin"));
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      g_registrar->messenger(), kChannelName,
      &flutter::StandardMethodCodec::GetInstance());

  g_channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() != "createDesktopShortcut") {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("invalid_arguments", "创建快捷方式所需参数无效");
          return;
        }

        const auto category_id_it = arguments->find(
            flutter::EncodableValue("categoryId"));
        const auto category_name_it = arguments->find(
            flutter::EncodableValue("categoryName"));
        const auto icon_data_it = arguments->find(
            flutter::EncodableValue("iconBytes"));
        if (category_id_it == arguments->end() ||
            category_name_it == arguments->end() ||
            icon_data_it == arguments->end()) {
          result->Error("invalid_arguments", "缺少创建快捷方式所需参数");
          return;
        }

        int category_id = 0;
        if (const auto* value =
                std::get_if<int32_t>(&category_id_it->second)) {
          category_id = *value;
        } else if (const auto* int64_value =
                       std::get_if<int64_t>(&category_id_it->second)) {
          category_id = static_cast<int>(*int64_value);
        }
        const auto* category_name =
            std::get_if<std::string>(&category_name_it->second);
        const auto* icon_data =
            std::get_if<std::vector<uint8_t>>(&icon_data_it->second);
        if (category_id <= 0 || category_name == nullptr || icon_data == nullptr) {
          result->Error("invalid_arguments", "创建快捷方式所需参数无效");
          return;
        }

        std::string shortcut_path;
        std::string error;
        if (!CreateDesktopShortcut(category_id, *category_name, *icon_data,
                                   &shortcut_path, &error)) {
          result->Error("create_failed", error);
          return;
        }
        result->Success(flutter::EncodableValue(shortcut_path));
      });
}
