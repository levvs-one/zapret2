#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <wchar.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kSingleInstanceMutex[] = L"Global\\Prosvet.SingleInstance";
constexpr wchar_t kReadyEvent[] = L"Global\\Prosvet.SingleInstance.Ready";
constexpr wchar_t kWindowProperty[] = L"Prosvet.SingleInstance.Window";

BOOL CALLBACK FindProsvetWindow(HWND window, LPARAM result_ptr) {
  if (::GetPropW(window, kWindowProperty) == nullptr) {
    return TRUE;
  }
  *reinterpret_cast<HWND*>(result_ptr) = window;
  return FALSE;
}

bool BringExistingWindowToFront() {
  HWND existing = nullptr;
  ::EnumWindows(FindProsvetWindow, reinterpret_cast<LPARAM>(&existing));
  if (existing == nullptr) {
    return false;
  }
  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  } else {
    ::ShowWindow(existing, SW_SHOW);
  }
  ::SetForegroundWindow(existing);
  return true;
}

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
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  const bool background =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--background") != command_line_arguments.end();

  HANDLE ready_event = ::CreateEventW(nullptr, TRUE, FALSE, kReadyEvent);
  if (ready_event == nullptr) {
    return EXIT_FAILURE;
  }

  HANDLE single_instance = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (single_instance == nullptr) {
    ::CloseHandle(ready_event);
    return EXIT_FAILURE;
  }

  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    if (background) {
      ::CloseHandle(single_instance);
      ::CloseHandle(ready_event);
      return EXIT_SUCCESS;
    }

    HANDLE startup_signals[] = {ready_event, single_instance};
    const DWORD startup =
        ::WaitForMultipleObjects(2, startup_signals, FALSE, 10000);
    if (startup == WAIT_OBJECT_0 && BringExistingWindowToFront()) {
      ::CloseHandle(single_instance);
      ::CloseHandle(ready_event);
      return EXIT_SUCCESS;
    }

    const bool replaced_primary =
        startup == WAIT_OBJECT_0 + 1 || startup == WAIT_ABANDONED_0 + 1;
    if (!replaced_primary) {
      ::MessageBoxW(nullptr,
                    L"Просвет уже запускается, но окно пока недоступно.",
                    L"Просвет", MB_OK | MB_ICONINFORMATION);
      ::CloseHandle(single_instance);
      ::CloseHandle(ready_event);
      return EXIT_FAILURE;
    }
    ::ResetEvent(ready_event);
  }

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
    ::CloseHandle(ready_event);
    return EXIT_FAILURE;
  }
  (void)process_job;

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(480, 760);
  if (!window.Create(L"Просвет", origin, size)) {
    ::CoUninitialize();
    ::ReleaseMutex(single_instance);
    ::CloseHandle(single_instance);
    ::CloseHandle(ready_event);
    return EXIT_FAILURE;
  }

  ::SetPropW(window.GetHandle(), kWindowProperty, reinterpret_cast<HANDLE>(1));
  ::SetEvent(ready_event);
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::ReleaseMutex(single_instance);
  ::CloseHandle(single_instance);
  ::CloseHandle(ready_event);
  return EXIT_SUCCESS;
}
