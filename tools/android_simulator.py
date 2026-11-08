#!/usr/bin/env python3
import socket
import json
import sys
import threading
import time

PORT = 8080
clients = []
client_locks = {}  # per-client write locks

def client_handler(conn, addr):
    print(f"\n[Simulator] Connected to Mac app at {addr}")
    lock = threading.Lock()
    client_locks[conn] = lock
    clients.append(conn)
    try:
        buffer = ""
        while True:
            data = conn.recv(1024)
            if not data:
                break
            buffer += data.decode("utf-8", errors="replace")
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                    if msg.get("type") == "ping":
                        pong = json.dumps({"type": "pong"}) + "\n"
                        with lock:
                            conn.sendall(pong.encode("utf-8"))
                except json.JSONDecodeError:
                    pass
    except Exception as e:
        pass
    finally:
        print(f"\n[Simulator] Disconnected from Mac app at {addr}")
        try:
            clients.remove(conn)
        except ValueError:
            pass
        client_locks.pop(conn, None)
        conn.close()

def send_to_all(data_dict):
    payload = (json.dumps(data_dict) + "\n").encode("utf-8")
    if not clients:
        print("[Simulator] Warning: No Mac app connected. Event queued/discarded.")
        return
    for client in list(clients):
        try:
            lock = client_locks.get(client)
            if lock:
                with lock:
                    client.sendall(payload)
            else:
                client.sendall(payload)
            print(f"[Simulator] Sent: {data_dict}")
        except Exception as e:
            print(f"[Simulator] Failed to send to a client: {e}")
            try:
                clients.remove(client)
            except ValueError:
                pass

def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(("127.0.0.1", PORT))
    except Exception as e:
        print(f"[Simulator] Error binding to port {PORT}: {e}")
        sys.exit(1)
        
    server.listen(5)
    print(f"[Simulator] TCP Server listening on 127.0.0.1:{PORT}")
    
    while True:
        try:
            conn, addr = server.accept()
            t = threading.Thread(target=client_handler, args=(conn, addr), daemon=True)
            t.start()
        except KeyboardInterrupt:
            break
        except Exception:
            pass

def main():
    # Start server in a background thread
    t = threading.Thread(target=start_server, daemon=True)
    t.start()
    
    time.sleep(0.5) # Give the server thread a moment to bind
    
    print("\n=== OmniFlow Android Simulator ===")
    print("Commands:")
    print("  battery <percentage> <charging: y/n>  - Send battery level")
    print("  notify <app_name> <title> <body>     - Send a notification")
    print("  exit                                 - Quit simulator")
    print("===================================\n")
    
    while True:
        try:
            cmd_line = input("sim> ").strip()
            if not cmd_line:
                continue
            
            parts = cmd_line.split(maxsplit=3)
            cmd = parts[0].lower()
            
            if cmd == "exit":
                print("Exiting simulator.")
                break
                
            elif cmd == "battery":
                if len(parts) < 3:
                    print("Usage: battery <percentage> <charging: y/n>")
                    continue
                try:
                    pct = int(parts[1])
                    charging = parts[2].lower() in ("y", "yes", "true", "1")
                    send_to_all({
                        "type": "telemetry",
                        "battery": pct,
                        "charging": charging
                    })
                except ValueError:
                    print("Invalid battery percentage.")
                    
            elif cmd == "notify":
                # Re-parse notification to handle spaces correctly
                # notify <app_name> <title> <body>
                # Format: notify "WhatsApp" "John Doe" "Hey there!"
                import shlex
                try:
                    args = shlex.split(cmd_line)
                except ValueError as e:
                    print(f"Error parsing notification arguments: {e}")
                    continue
                
                if len(args) < 4:
                    print("Usage: notify <app_name> <title> <body>  (use quotes for spaces)")
                    continue
                    
                app = args[1]
                title = args[2]
                body = args[3]
                
                send_to_all({
                    "type": "notification",
                    "app": app,
                    "title": title,
                    "body": body
                })
            else:
                print(f"Unknown command: {cmd}")
        except (KeyboardInterrupt, EOFError):
            print("\nExiting simulator.")
            break

if __name__ == "__main__":
    main()
