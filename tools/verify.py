#!/usr/bin/env python3
import subprocess
import time
import socket
import json
import sys

def main():
    print("[Test] Starting verification run...")

    # 1. Start the simulator server directly in python or as a background subprocess
    # We will start it as a subprocess to keep clean separation
    sim_proc = subprocess.Popen(
        [sys.executable, "tools/android_simulator.py"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    # Give simulator a moment to bind to 8080
    time.sleep(1)
    
    # 2. Start macOS application
    mac_proc = subprocess.Popen(
        ["./macOS/.build/debug/OmniFlowMac"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    # Give connection a moment to establish
    time.sleep(2.5)
    
    # 3. Send test updates via simulator stdin
    print("[Test] Sending simulated battery level: 88% (charging)")
    sim_proc.stdin.write("battery 88 y\n")
    sim_proc.stdin.flush()
    time.sleep(1)
    
    print("[Test] Sending simulated notification: WhatsApp | John Doe | 'See you soon!'")
    sim_proc.stdin.write('notify "WhatsApp" "John Doe" "See you soon!"\n')
    sim_proc.stdin.flush()
    time.sleep(1.5)
    
    # 4. Shut down processes
    sim_proc.stdin.write("exit\n")
    sim_proc.stdin.flush()
    sim_proc.terminate()
    mac_proc.terminate()
    
    mac_out, _ = mac_proc.communicate(timeout=2)
    sim_out, _ = sim_proc.communicate(timeout=2)
    
    print("\n--- macOS App Stdout Logs ---")
    print(mac_out)
    print("-----------------------------\n")
    
    # 5. Assertions
    has_connected = "Successfully connected!" in mac_out
    has_telemetry = "Telemetry update: battery=88%" in mac_out
    has_notification = "Received Notification: John Doe - See you soon! (App: WhatsApp)" in mac_out
    
    if has_connected and has_telemetry and has_notification:
        print("[SUCCESS] All continuity pipeline assertions passed successfully!")
        sys.exit(0)
    else:
        print("[FAILURE] Some pipeline events were not captured in macOS logs:")
        print(f" - Connected: {has_connected}")
        print(f" - Telemetry: {has_telemetry}")
        print(f" - Notification: {has_notification}")
        sys.exit(1)

if __name__ == "__main__":
    main()
