import numpy as np
import matplotlib.pyplot as plt
import struct
import json
import os

# ================= PENGATURAN TAMPILAN =================
plt.rcParams['mathtext.fontset'] = 'cm'
plt.rcParams['font.family'] = 'serif'

# PATH HANDLING
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
GENERATE_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../generate"))
PARENT_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../../../"))

META_FILENAME = os.path.join(GENERATE_DIR, "meta_data.json")
INPUT_BIN = os.path.join(PARENT_DIR, "input_32x16.bin")
OUTPUT_BIN = os.path.join(PARENT_DIR, "output_32x16.bin")

def print_header(title):
    print("="*60)
    print(f"{title:^60}")
    print("="*60)

def run_verify():
    # 1. LOAD METADATA
    if not os.path.exists(META_FILENAME):
        print("Error: Metadata tidak ditemukan. Jalankan generate.py dulu.")
        return
    
    with open(META_FILENAME, "r") as f:
        meta = json.load(f)
    
    POINTS = meta["points"]
    FUNC_STR = meta["func"]
    T_START = meta["t_start"]
    T_END = meta["t_end"]
    SCALE = meta["scale"] # Faktor skala dinamis dari generate.py
    BITS = meta["bits"]

    # Hitung Axis Frekuensi
    DURATION = T_END - T_START
    SAMPLING_RATE = POINTS / DURATION if DURATION > 0 else 1
    FREQ_AXIS = np.arange(POINTS) * (SAMPLING_RATE / POINTS)

    print_header(f"VERIFIKASI FFT {POINTS} POINT ({BITS}-BIT) [LINEAR UNIT]")
    print(f"[-] Fungsi Input   : {FUNC_STR}")
    print(f"[-] Scale Factor   : {SCALE:.4f}")
    print(f"[-] Resolusi Freq  : {SAMPLING_RATE/POINTS:.2f} Hz/bin")
    print("-" * 60)

    # 2. LOAD INPUT & RESTORE KE SATUAN ASLI
    raw_input_int = []
    if not os.path.exists(INPUT_BIN): return
    with open(INPUT_BIN, "rb") as f:
        content = f.read()
        # Perbedaan dengan 8-bit: Baca 2 byte (<h) per langkah
        for i in range(0, len(content), 2):
            val = struct.unpack('<h', content[i:i+2])[0]
            raw_input_int.append(val)
            
    # KONVERSI: Integer FPGA -> Nilai Asli (misal: Volt)
    input_signal_real = np.array(raw_input_int) / SCALE

    # 3. HITUNG FFT IDEAL (NUMPY)
    # Numpy FFT outputnya belum ternormalisasi amplitudo (A * N/2)
    fft_ideal_complex = np.fft.fft(input_signal_real)
    
    # Normalisasi agar sesuai amplitudo fisik: Bagi dengan (N/2)
    fft_ideal_mag = np.abs(fft_ideal_complex) / (POINTS / 2)
    
    # Koreksi komponen DC (Index 0)
    fft_ideal_mag[0] = fft_ideal_mag[0] / 2 

    # 4. LOAD OUTPUT FPGA & RESTORE KE SATUAN ASLI
    if not os.path.exists(OUTPUT_BIN):
        print(f"[!] File output tidak ditemukan: {OUTPUT_BIN}")
        return

    fpga_raw_int = []
    with open(OUTPUT_BIN, "rb") as f:
        content = f.read()
        for i in range(0, len(content), 2):
            if len(fpga_raw_int) < POINTS:
                val = struct.unpack('<h', content[i:i+2])[0]
                fpga_raw_int.append(val)
    
    fpga_raw_int = np.array(fpga_raw_int)

    # KONVERSI: Output FPGA -> Nilai Asli
    # Rumus sama: (Raw * 2) / SCALE
    fpga_mag_real = (fpga_raw_int * 2) / SCALE

    # 5. ANALISIS ERROR (Dalam Satuan Asli)
    error = np.abs(fft_ideal_mag - fpga_mag_real)
    max_error = np.max(error)
    avg_error = np.mean(error)
    
    # SNR Calculation
    signal_power = np.sum(fft_ideal_mag**2)
    noise_power = np.sum(error**2)
    snr = 10 * np.log10(signal_power / noise_power) if noise_power > 0 else 999

    print(f"STATISTIK PERFORMA:")
    print(f"[-] Max Galat      : {max_error:.5f} Unit")
    print(f"[-] Rata-rata Galat: {avg_error:.5f} Unit")
    print(f"[-] SNR (Estimasi) : {snr:.2f} dB")

    # ================= VISUALISASI =================
    fig = plt.figure(figsize=(12, 10))
    fig.suptitle(f"Analisis Spektral Linear ({BITS}-bit)", fontsize=16, fontweight='bold')

    gs = fig.add_gridspec(3, 1, height_ratios=[1, 2, 1], hspace=0.4)

    # PLOT 1: Time Domain (Real Units)
    ax1 = fig.add_subplot(gs[0])
    t_axis = np.linspace(T_START, T_END, POINTS, endpoint=False)
    ax1.step(t_axis, input_signal_real, where='mid', color='#1f77b4', label='Input Discrete')
    ax1.plot(t_axis, input_signal_real, 'bo', alpha=0.3, markersize=4) 
    
    ax1.set_title(f"Domain Waktu: Input Sinyal", fontsize=12, loc='left')
    ax1.text(0.02, 0.85, f"Input: ${FUNC_STR}$", transform=ax1.transAxes, fontsize=14, 
             bbox=dict(facecolor='white', alpha=0.8, edgecolor='none'))
    ax1.set_ylabel("Amplitudo (Unit Asli)")
    ax1.set_xlabel("Waktu (detik)")
    ax1.grid(True, linestyle='--', alpha=0.6)
    
    # Set limit Y otomatis
    y_max = np.max(np.abs(input_signal_real))
    if y_max == 0: y_max = 1
    ax1.set_ylim(-y_max*1.2, y_max*1.2)

    # PLOT 2: Frequency Domain (Real Units)
    ax2 = fig.add_subplot(gs[1])
    ax2.stem(FREQ_AXIS, fft_ideal_mag, linefmt='b--', markerfmt='bo', basefmt=' ', label="Ideal (Python)")
    
    # Geser sedikit agar terlihat jika bertumpuk
    freq_offset = (SAMPLING_RATE/POINTS) * 0.15
    markerline2, stemlines2, baseline2 = ax2.stem(FREQ_AXIS + freq_offset, fpga_mag_real, linefmt='g-', markerfmt='gx', basefmt=' ', label="Aktual (FPGA)")
    plt.setp(stemlines2, 'linewidth', 2)
    
    ax2.set_title("Domain Frekuensi: Magnituda Mutlak", fontsize=12, loc='left')
    ax2.set_ylabel("Magnituda (Unit Asli)")
    ax2.set_xlabel("Frekuensi (Hz)")
    ax2.legend()
    ax2.grid(True, which='both', alpha=0.7)

    # PLOT 3: Error (Real Units)
    ax3 = fig.add_subplot(gs[2])
    ax3.bar(FREQ_AXIS, error, width=(SAMPLING_RATE/POINTS)*0.8, color='orange', alpha=0.8, edgecolor='black')
    ax3.set_title("Analisis Galat Absolut", fontsize=12, loc='left')
    ax3.set_ylabel("Selisih (Unit Asli)")
    ax3.set_xlabel("Frekuensi (Hz)")
    ax3.grid(True, axis='y')
    
    stats_text = f"Mean Error: {avg_error:.4f}\nSNR: {snr:.1f} dB"
    ax3.text(0.98, 0.85, stats_text, transform=ax3.transAxes, ha='right', va='top', 
             bbox=dict(boxstyle='round', facecolor='white'))

    plt.show()

if __name__ == "__main__":
    run_verify()