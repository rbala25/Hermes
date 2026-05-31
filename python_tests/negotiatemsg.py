import socket
import time

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', 10000))
s.listen(1)
print("Listening")
conn, addr = s.accept()
print("Connected from", addr)
conn.settimeout(60)
buf = b''
while True:
    try:
        data = conn.recv(4096)
        if not data:
            print("Connection closed")
            break
        buf += data
        print("Got", len(data), "bytes total", len(buf))
        print(buf.hex())
    except socket.timeout:
        print("Timed out, buf so far:", buf.hex())
        break
    except Exception as e:
        print("Error", e)
        break
conn.close()
s.close()