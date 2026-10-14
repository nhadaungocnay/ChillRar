#ifndef CUNRAR_H
#define CUNRAR_H

// Exposes the official UnRAR library API (Vendor/unrar/dll.hpp) to Swift.
// dll.hpp expects _UNIX to be defined on non-Windows platforms so that the
// Windows types (HANDLE, LPARAM, UINT, ...) are mapped to plain C types.
#ifndef _UNIX
#define _UNIX
#endif

#include <wchar.h>
#include "../../../Vendor/unrar/dll.hpp"

/// Switch LC_CTYPE to UTF-8. UnRAR converts wide file names with wcstombs()
/// when creating files on Unix, which fails for non-ASCII names in the
/// default "C" locale used by GUI processes.
void cunrar_use_utf8_locale(void);

#endif /* CUNRAR_H */
