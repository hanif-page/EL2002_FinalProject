import numpy as np
import matplotlib.pyplot as plt
import struct
import json
import os

# ================= KONFIGURASI 64x8 =================
POINTS = 64
BIT_DEPTH = 8
MAX_VAL = 127 # Signed 8-bit
TARGET_HEADROOM = 120.0 # Target nilai integer maksimum (agar aman dari overflow)

# INPUT USER
# FUNC_STR = "np.sin(10 * t) * np.sin(2 * t)"

# LIMITASI 1
# FUNC_STR = "np.sin(10 * t) + 0.5 * np.sin(2 * t) + 3 * np.sin(5 * t) + np.sin(3 * t) + 0.05 * np.sin(8 * t) + 0.2 * np.sin(12 * t) + 10 * np.sin(t)" 
# LIMITASI 2
FUNC_STR = "(1 + 0.8 * np.sin(2 * np.pi * 4.5 * t)) * np.sin(2 * np.pi * 29 * t)"

START_TIME = 0.0
# END_TIME = 2 * np.pi

# FUNC_STR = "(1 + 0.8 * np.sin(2*np.pi*4.5*t)) * np.sin(2*np.pi*29*t)"
END_TIME = 1 # only for above FUNC_STR

# PATH HANDLING
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../../../"))
BIN_FILENAME = os.path.join(PARENT_DIR, "input_64x8.bin")
TXT_FILENAME = os.path.join(CURRENT_DIR, "input_debug.txt")
META_FILENAME = os.path.join(CURRENT_DIR, "meta_data.json")

def int_to_binary_string(val, bits):
    s = bin(val & int("1"*bits, 2))[2:]
    return ("{0:0>%s}" % (bits)).format(s)

def run():
    print(f"--- GENERATOR 64x8 (AUTO-NORMALIZED) ---")
    
    # 1. Generate Sinyal Float
    t_ideal = np.linspace(START_TIME, END_TIME, 1000)
    context = {"np": np, "t": t_ideal}
    y_ideal = eval(FUNC_STR, context)

    t_samples = np.linspace(START_TIME, END_TIME, POINTS, endpoint=False)
    context_samples = {"np": np, "t": t_samples}
    y_samples_float = eval(FUNC_STR, context_samples)
    
    # [FIX] AUTO-SCALING LOGIC
    # Cari nilai maksimum absolut dari sinyal input
    max_amp = np.max(np.abs(y_samples_float))
    
    # Hitung scale factor dinamis:
    # Kita ingin 'max_amp' dipetakan menjadi 'TARGET_HEADROOM' (120)
    if max_amp > 0:
        final_scale = TARGET_HEADROOM / max_amp
    else:
        final_scale = TARGET_HEADROOM # Default jika sinyal 0
    
    print(f"[-] Max Input Amp: {max_amp:.4f}")
    print(f"[-] Applied Scale: {final_scale:.4f}")

    # Terapkan scaling dinamis
    y_samples_int = (y_samples_float * final_scale).astype(int)
    y_samples_int = np.clip(y_samples_int, -128, 127) # Range 8-bit safety clip

    # 2. Simpan File BIN - Signed Char ('b')
    with open(BIN_FILENAME, "wb") as f:
        for val in y_samples_int:
            f.write(struct.pack('b', val))

    # 3. Simpan File TXT
    with open(TXT_FILENAME, "w") as f:
        for val in y_samples_int:
            f.write(int_to_binary_string(val, BIT_DEPTH) + "\n")

    # 4. Metadata
    meta = {
        "func": FUNC_STR,
        "points": POINTS,
        "bits": BIT_DEPTH,
        "scale": final_scale, # Simpan scale yang SUDAH dihitung dinamis
        "t_start": START_TIME,
        "t_end": END_TIME
    }
    with open(META_FILENAME, "w") as f:
        json.dump(meta, f)

    print(f"[OK] Bin saved: {BIN_FILENAME}")
    
    # 5. Plotting (Visualisasi Int untuk memastikan tidak kotak)
    plt.figure(figsize=(10, 5))
    plt.plot(t_ideal, y_ideal, label=f'Ideal (Max: {max_amp:.2f})')
    # Kita plot y_samples_float agar terlihat sampling point aslinya
    plt.step(t_samples, y_samples_float, where='mid', label='Sampel Float', color='orange')
    plt.title(f"Input Generation 64x8\n{FUNC_STR}")
    plt.grid(True); plt.legend(); plt.show()

if __name__ == "__main__":
    run()