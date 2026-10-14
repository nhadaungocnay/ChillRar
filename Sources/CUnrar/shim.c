#include "CUnrar.h"
#include <locale.h>

void cunrar_use_utf8_locale(void) {
    // "UTF-8" is a valid LC_CTYPE locale name on macOS.
    if (setlocale(LC_CTYPE, "UTF-8") == NULL) {
        setlocale(LC_CTYPE, "en_US.UTF-8");
    }
}
