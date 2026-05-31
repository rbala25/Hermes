import socket
import struct

def make_sofh_sbe(template_id, block_length, body=b''):
    total = 12 + len(body)
    sofh = struct.pack('<HH', total, 0xCAFE)
    sbe  = struct.pack('<HHHH', block_length, template_id, 8, 8)
    return sofh + sbe + body

NEG_RESPONSE = make_sofh_sbe(501, 0)

# EstablishmentAck: 20-byte body, next_seq_no=1 at bpos 16-19
estab_body = bytes(16) + struct.pack('<I', 1)  # 16 zeros then next_seq_no=1
ESTAB_ACK  = make_sofh_sbe(504, 20, estab_body)

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
        print(f"Got {len(data)} bytes, total {len(buf)}: {buf[-len(data):].hex()}")

        if len(buf) == 90:
            print("Got Negotiate, sending NegotiationResponse")
            conn.sendall(NEG_RESPONSE)
        elif len(buf) == 90 + 146:
            print("Got Establish, sending EstablishmentAck")
            conn.sendall(ESTAB_ACK)

    except socket.timeout:
        print("Timed out")
        break
    except Exception as e:
        print("Error", e)
        break

conn.close()
s.close()