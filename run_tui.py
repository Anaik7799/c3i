import pty
import os
import time

pid, fd = pty.fork()
if pid == 0:
    os.chdir("sub-projects/c3i/native/ignition_daemon")
    os.execvp("./target/debug/ignition", ["ignition", "ops-test"])
else:
    time.sleep(5) # Wait for startup and phase A
    os.write(fd, b's') # Send 'start'
    time.sleep(2)
    os.write(fd, b'x') # Send 'stop'
    time.sleep(2)
    os.write(fd, b'q') # Quit
    
    try:
        while True:
            os.read(fd, 4096)
    except OSError:
        pass
