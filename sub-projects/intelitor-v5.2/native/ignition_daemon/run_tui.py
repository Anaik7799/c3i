import pty
import os
import time

pid, fd = pty.fork()
if pid == 0:
    os.execvp("cargo", ["cargo", "run", "--bin", "ignition", "ops-test"])
else:
    time.sleep(6) # Wait for startup
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
