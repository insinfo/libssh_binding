#pragma once

//isaque criou MainLibrary.h

//__declspec(dllexport) void hello_world();

int __declspec(dllexport) pscp_main(int argc, char* argv[], void (*callback_stats)(char const* output_stats), char const* override_stderr);