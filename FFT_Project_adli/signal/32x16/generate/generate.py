import numpy as np
import matplotlib.pyplot as plt
import struct
import json
import os

# ================= KONFIGURASI 32x16 =================
POINTS = 32
BIT_DEPTH = 16
MAX_VAL = 32767 # Signed 16-bit max
TARGET_HEADROOM = 32000.0 # Target nilai integer maksimum (agar aman dari overflow)

# INPUT USER
# FUNC_STR = "np.sin(10 * t) + 0.5 * np.sin(2 * t) + 3* np.sin(5 * t) + np.sin(3 * t) + 0.05 * np.sin(8 * t) + 0.2 * np.sin(12 * t) + 10 * np.sin(t)" # ga aman, output bisa 2 kmungkinan walau input sama, bagus and rusak
# FUNC_STR = "np.sin(8 * t) + np.sin(16 * t)" # aman
# FUNC_STR = "np.sin(3.5 * t)" # ga aman, output bisa 2 kmungkinan walau input sama, bagus and rusak
# FUNC_STR = "np.cos(4 * t)" # ga aman, output bisa 2 kmungkinan walau input sama, bagus and rusak
START_TIME = 0.0
# END_TIME = 2 * np.pi

FUNC_STR = "(1 + 0.8 * np.sin(2*np.pi*4.5*t)) * np.sin(2*np.pi*29*t)" # ga aman, output bisa 2 kmungkinan walau input sama, bagus and rusak
END_TIME = 1 # only for above FUNC_STR

# PATH HANDLING
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../../../"))
BIN_FILENAME = os.path.join(PARENT_DIR, "input_32x16.bin")
TXT_FILENAME = os.path.join(CURRENT_DIR, "input_debug.txt")
META_FILENAME = os.path.join(CURRENT_DIR, "meta_data.json")

def int_to_binary_string(val, bits):
    """Mengubah int ke string biner (Two's complement)"""
    s = bin(val & int("1"*bits, 2))[2:]
    return ("{0:0>%s}" % (bits)).format(s)

def run():
    print(f"--- GENERATOR 32x16 (AUTO-NORMALIZED) ---")
    
    # 1. Generate Sinyal Float
    t_ideal = np.linspace(START_TIME, END_TIME, 1000)
    context = {"np": np, "t": t_ideal}
    y_ideal = eval(FUNC_STR, context)

    # 2. Generate Sinyal Sampel
    t_samples = np.linspace(START_TIME, END_TIME, POINTS, endpoint=False)
    context_samples = {"np": np, "t": t_samples}
    y_samples_float = eval(FUNC_STR, context_samples)
    
    # [FIX] AUTO-SCALING LOGIC (16-BIT)
    # Cari nilai maksimum absolut dari sinyal input
    max_amp = np.max(np.abs(y_samples_float))
    
    # Hitung scale factor dinamis:
    # Kita ingin 'max_amp' dipetakan menjadi 'TARGET_HEADROOM' (32000)
    if max_amp > 0:
        final_scale = TARGET_HEADROOM / max_amp
    else:
        final_scale = TARGET_HEADROOM # Default jika sinyal 0
        
    print(f"[-] Max Input Amp: {max_amp:.4f}")
    print(f"[-] Applied Scale: {final_scale:.4f}")

    # Terapkan scaling dinamis
    y_samples_int = (y_samples_float * final_scale).astype(int)
    y_samples_int = np.clip(y_samples_int, -32768, 32767) # Safety clip 16-bit

    # 3. Simpan File BIN (Untuk FPGA) - Little Endian Short (<h)
    with open(BIN_FILENAME, "wb") as f:
        for val in y_samples_int:
            f.write(struct.pack('<h', val))

    # 4. Simpan File TXT (Debug Biner)
    with open(TXT_FILENAME, "w") as f:
        for val in y_samples_int:
            f.write(int_to_binary_string(val, BIT_DEPTH) + "\n")

    # 5. Simpan Metadata untuk Verify.py
    meta = {
        "func": FUNC_STR,
        "points": POINTS,
        "bits": BIT_DEPTH,
        "scale": final_scale, # Simpan scale dinamis
        "t_start": START_TIME,
        "t_end": END_TIME
    }
    with open(META_FILENAME, "w") as f:
        json.dump(meta, f)

    print(f"[OK] Bin file saved to: {BIN_FILENAME}")
    
    # 6. Plotting
    plt.figure(figsize=(10, 5))
    plt.plot(t_ideal, y_ideal, label=f'Ideal (Max: {max_amp:.2f})')
    plt.step(t_samples, y_samples_float, where='mid', label='Sampel Float', color='red', linewidth=2)
    plt.plot(t_samples, y_samples_float, 'ro')
    plt.title(f"Input Generation 32x16\n{FUNC_STR}")
    plt.xlabel("Waktu")
    plt.ylabel("Amplitudo")
    plt.legend()
    plt.grid(True)
    plt.show()

if __name__ == "__main__":
    run()