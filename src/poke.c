// lightswitch-toggle: the program behind the keybinding. It tells the
// resident lightswitch to show or hide over its Unix socket, linking nothing
// but libc so a key press costs about a millisecond. When nothing is
// listening it starts the full app, which comes up visible.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *command = argc > 1 ? argv[1] : "toggle";
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    struct sockaddr_un address = {.sun_family = AF_UNIX};
    snprintf(address.sun_path, sizeof address.sun_path, "%s/lightswitch.sock",
             runtime && *runtime ? runtime : "/tmp");

    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd >= 0 && connect(fd, (struct sockaddr *)&address, sizeof address) == 0) {
        char line[32];
        int n = snprintf(line, sizeof line, "%s\n", command);
        int ok = write(fd, line, n) == n;
        close(fd);
        if (ok) return 0;
    }
    execlp("lightswitch", "lightswitch", command, (char *)NULL);
    perror("lightswitch-toggle: couldn't start lightswitch");
    return 1;
}
