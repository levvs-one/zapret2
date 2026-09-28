#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kSingleInstanceMutex[] = L"Global\\Prosvet.SingleInstance";
constexpr wchar_t kWindowProperty[] = L"Prosvet.SingleInstance.Window";

BOOL CALLBACK FindProsvetWindow(HWND window, LPARAM result_ptr) {
  if (::GetPropW(window, kWindowProperty) == nullptr) {
    return TRUE;
  }
  *reinterpret_cast<HWND*>(result_ptr) = window;
  return FALSE;
}

void BringExistingWindowToFront() {
  HWND existing = nullptr;
  // The mutex is created before the first Flutter window. A near-simultaneous
  // second launch can therefore win this lookup by a few milliseconds.
  for (int attempt = 0; attempt < 20 && existing == nullptr; ++attempt) {
    ::EnumWindows(FindProsvetWindow, reinterpret_cast<LPARAM>(&existing));
    if (existing == nullptr) {
      ::Sleep(50);
    }
  }
  if (existing == nullptr) {
    ::MessageBoxW(
        nullptr,
        L"Просвет уже запущен в другом сеансе Windows.",
        L"Просвет",
        MB_OK | MB_ICONINFORMATION);
    return;
  }
  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  } else {
    ::ShowWindow(existing, SW_SHOW);
  }
  ::SetForegroundWindow(existing);
}

// Keep this handle open for the lifetime of the process. Assigning Prosvet to a
// kill-on-close job makes child processes (notably winws2.exe) die if the GUI
// is terminated without getting a chance to run its normal shutdown path.
HANDLE AttachKillOnCloseJob(DWORD* error) {
  HANDLE job = ::CreateJobObjectW(nullptr, nullptr);
  if (job == nullptr) {
    *error = ::GetLastError();
    return nullptr;
  }

  JOBOBJECT_EXTENDED_LIMIT_INFORMATION info{};
  info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!::SetInformationJobObject(job, JobObjectExtendedLimitInformation, &info,
                                 sizeof(info)) ||
      !::AssignProcessToJobObject(job, ::GetCurrentProcess())) {
    *error = ::GetLastError();
    ::CloseHandle(job);
    return nullptr;
  }
  *error = ERROR_SUCCESS;
  return job;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE single_instance =
      ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (single_instance == nullptr) {
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    BringExistingWindowToFront();
    ::CloseHandle(single_instance);
    return EXIT_SUCCESS;
  }

  // Intentionally not closed: Windows closes process handles on exit, which
  // triggers JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE after an abnormal termination.
  DWORD job_error = ERROR_SUCCESS;
  HANDLE process_job = AttachKillOnCloseJob(&job_error);
  if (process_job == nullptr) {
    wchar_t message[256];
    ::swprintf_s(
        message,
        L"Не удалось включить безопасное управление дочерними процессами "
        L"(ошибка Windows %lu). Просвет не будет запущен.",
        job_error);
    ::MessageBoxW(nullptr, message, L"Просвет", MB_OK | MB_ICONERROR);
    ::ReleaseMutex(single_instance);
    ::CloseHandle(single_instance);
    return EXIT_FAILURE;
  }
  (void)process_job;

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Prosvet", origin, size)) {
    ::CoUninitialize();
    ::ReleaseMutex(single_instance);
    ::CloseHandle(single_instance);
    return EXIT_FAILURE;
  }
  // The Dart side can change the visible title at runtime. A window property is
  // a stable cross-process identity for the second-launch path.
  ::SetPropW(window.GetHandle(), kWindowProperty,
             reinterpret_cast<HANDLE>(1));
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::ReleaseMutex(single_instance);
  ::CloseHandle(single_instance);
  return EXIT_SUCCESS;
}
