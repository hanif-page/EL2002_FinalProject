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
INPUT_BIN = os.path.join(PARENT_DIR, "input_64x8.bin")
OUTPUT_BIN = os.path.join(PARENT_DIR, "output_64x8.bin")

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
    print(f"[-] Scale Factor   : {SCALE:.4f} (Raw Int -> Real Unit)")
    print(f"[-] Resolusi Freq  : {SAMPLING_RATE/POINTS:.2f} Hz/bin")
    print("-" * 60)

    # 2. LOAD INPUT & RESTORE KE SATUAN ASLI
    raw_input_int = []
    if not os.path.exists(INPUT_BIN): return
    with open(INPUT_BIN, "rb") as f:
        content = f.read()
        for i in range(len(content)):
            # 'b' = signed char (1 byte)
            val = struct.unpack('b', content[i:i+1])[0]
            raw_input_int.append(val)
            
    # KONVERSI: Integer FPGA -> Nilai Asli (misal: Volt)
    input_signal_real = np.array(raw_input_int) / SCALE

    # 2.5 HITUNG TRUE ANALOG SPECTRUM (High Resolution) -- [BARU]
    # Oversampling untuk simulasi sinyal analog
    OVERSAMPLE = 32
    POINTS_HIGH = POINTS * OVERSAMPLE
    SAMPLING_RATE_HIGH = POINTS_HIGH / DURATION
    
    t_high = np.linspace(T_START, T_END, POINTS_HIGH, endpoint=False)
    context_high = {"np": np, "t": t_high}
    y_high = eval(FUNC_STR, context_high)
    
    # FFT High Res
    fft_high_complex = np.fft.fft(y_high)
    fft_high_mag = np.abs(fft_high_complex) / (POINTS_HIGH / 2)
    fft_high_mag[0] = fft_high_mag[0] / 2
    
    # Axis Frekuensi High Res
    freq_axis_high = np.arange(POINTS_HIGH) * (SAMPLING_RATE_HIGH / POINTS_HIGH)

    # 3. HITUNG FFT IDEAL DISKRET (NUMPY 64 Point)
    fft_ideal_complex = np.fft.fft(input_signal_real)
    fft_ideal_mag = np.abs(fft_ideal_complex) / (POINTS / 2)
    fft_ideal_mag[0] = fft_ideal_mag[0] / 2 

    # 4. LOAD OUTPUT FPGA & RESTORE KE SATUAN ASLI
    if not os.path.exists(OUTPUT_BIN):
        print(f"[!] File output tidak ditemukan: {OUTPUT_BIN}")
        return

    fpga_raw_int = []
    with open(OUTPUT_BIN, "rb") as f:
        content = f.read()
        for i in range(len(content)):
            if len(fpga_raw_int) < POINTS:
                val = struct.unpack('b', content[i:i+1])[0]
                fpga_raw_int.append(val)
    
    fpga_raw_int = np.array(fpga_raw_int)

    # KONVERSI: Output FPGA -> Nilai Asli
    # 1. Dikali 2 (Kompensasi atenuasi FPGA)
    # 2. Dibagi SCALE (Kompensasi fixed-point)
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
    
    # [BARU] Plot True Analog di background
    ax1.plot(t_high, y_high, color='orange', alpha=0.4, linewidth=1, label='True Analog Signal')
    
    # Plot Discrete Input
    ax1.step(t_axis, input_signal_real, where='mid', color='purple', label='Discrete Input (FPGA)')
    ax1.plot(t_axis, input_signal_real, 'C4o', alpha=0.3, markersize=4) 
    
    ax1.set_title(f"Domain Waktu: Input Sinyal", fontsize=12, loc='left')
    ax1.text(0.02, 0.85, f"Input: ${FUNC_STR}$", transform=ax1.transAxes, fontsize=12, 
             bbox=dict(facecolor='white', alpha=0.8, edgecolor='none'))
    ax1.set_ylabel("Amplitudo (Unit Asli)")
    ax1.set_xlabel("Waktu (detik)")
    ax1.legend(loc='upper right')
    ax1.grid(True, linestyle='--', alpha=0.6)
    
    # Set limit Y otomatis
    y_max = np.max(np.abs(input_signal_real))
    if y_max == 0: y_max = 1
    ax1.set_ylim(-y_max*1.2, y_max*1.2)

    # PLOT 2: Frequency Domain (Dengan True Analog)
    ax2 = fig.add_subplot(gs[1])
    
    # [BARU] Plot True Analog Spectrum
    ax2.plot(freq_axis_high, fft_high_mag, color='#ff7f0e', alpha=0.6, linewidth=2, label="True Analog Spectrum")
    
    # Plot Ideal Discrete
    ax2.stem(FREQ_AXIS, fft_ideal_mag, linefmt='b--', markerfmt='bo', basefmt=' ', label="Ideal Discrete (Python)")
    
    # Plot Aktual FPGA
    freq_offset = (SAMPLING_RATE/POINTS) * 0.15
    markerline2, stemlines2, baseline2 = ax2.stem(FREQ_AXIS + freq_offset, fpga_mag_real, linefmt='r-', markerfmt='rx', basefmt=' ', label="Aktual (FPGA)")
    plt.setp(stemlines2, 'linewidth', 2)
    
    ax2.set_title("Domain Frekuensi: Perbandingan Analog vs Diskrit vs FPGA", fontsize=12, loc='left')
    ax2.set_ylabel("Magnituda (Unit Asli)")
    ax2.set_xlabel("Frekuensi (Hz)")
    
    # Batasi view X-Axis
    ax2.set_xlim(-1, SAMPLING_RATE * 1.1) # -3 will shifting the start of the point to the right
    
    ax2.legend()
    ax2.grid(True, which='both', alpha=0.7)

    # PLOT 3: Error (Real Units)
    ax3 = fig.add_subplot(gs[2])
    ax3.bar(FREQ_AXIS, error, width=(SAMPLING_RATE/POINTS)*0.8, color='#d62728', alpha=0.7, edgecolor='black')
    ax3.set_title("Analisis Galat Absolut", fontsize=12, loc='left')
    ax3.set_ylabel("Selisih (Unit Asli)")
    ax3.set_xlabel("Frekuensi (Hz)")
    ax3.grid(True, axis='y')
    
    stats_text = f"Mean Error: {avg_error:.4f}\nSNR: {snr:.1f} dB"
    ax3.text(0.98, 0.85, stats_text, transform=ax3.transAxes, ha='right', va='top', 
             bbox=dict(boxstyle='round', facecolor='white'))

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    run_verify()