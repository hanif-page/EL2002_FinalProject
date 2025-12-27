import numpy as np
import matplotlib.pyplot as plt

def signal_analyzer():
    print("--- FFT Signal Analyzer ---")
    print("Menerima input format NumPy, misal: np.sin(10 * t)")
    
    # 1. Konfigurasi Sampling
    fs = 100.0        # Sampling freq 100 Hz (Cukup, karena sinyal max Anda < 2 Hz)
    duration = 50.0   # Durasi 50 detik (PENTING: agar resolusi frekuensi tajam)
    
    N = int(fs * duration)
    t = np.linspace(0.0, duration, N, endpoint=False)

    # 2. Input Persamaan
    # Default string sesuai request Anda untuk kemudahan copy-paste
    default_eq = "np.sin(10 * t) * 0.5 * np.sin(2 * t) + 3* np.sin(5 * t) + np.sin(3 * t) + 0.05 * np.sin(8 * t) + 0.2 * np.sin(12 * t) + 10 * np.sin(t)"
    
    print(f"\nDefault persamaan (tekan Enter untuk menggunakan ini):\n{default_eq}\n")
    user_input = input("Masukkan persamaan f(t): ")
    
    if not user_input.strip():
        equation = default_eq
    else:
        equation = user_input

    # 3. Parsing & Evaluasi
    safe_dict = {
        "np": np,    # Kunci utama: mengizinkan penggunaan "np."
        "sin": np.sin,
        "cos": np.cos,
        "pi": np.pi,
        "t": t
    }

    try:
        y = eval(equation, {"__builtins__": None}, safe_dict)
        
        # Handle jika hasil evaluasi adalah angka konstan
        if isinstance(y, (int, float)):
            y = np.full_like(t, y)

        # 4. Proses FFT
        yf = np.fft.fft(y)
        xf = np.fft.fftfreq(N, 1/fs)
        
        # Ambil sisi positif spektrum (One-sided)
        half_N = N // 2
        xf_plot = xf[:half_N]
        magnitude = 2.0/N * np.abs(yf[:half_N])
        magnitude[0] = magnitude[0] / 2 # Koreksi komponen DC

        # 5. Deteksi Puncak (Opsional - untuk verifikasi data)
        print("\n--- Deteksi Puncak Frekuensi (Dominan) ---")
        indices = np.where(magnitude > 0.1)[0] # Threshold amplitudo 0.1
        for i in indices:
            freq_hz = xf_plot[i]
            rad_s = freq_hz * 2 * np.pi
            amp = magnitude[i]
            # Print hanya jika frekuensi positif
            if freq_hz > 0:
                print(f"Freq: {freq_hz:.3f} Hz (~{rad_s:.1f} rad/s) | Magnitudo: {amp:.3f}")

        # 6. Plotting
        plt.figure(figsize=(12, 8))

        # Plot 1: Time Domain
        plt.subplot(2, 1, 1)
        # Kita hanya plot 5 detik pertama agar bentuk gelombang terlihat detail
        limit_samples = int(5 * fs) 
        plt.plot(t[:limit_samples], y[:limit_samples], linewidth=1.5)
        plt.title('Domain Waktu (5 detik pertama)')
        plt.xlabel('Waktu (s)')
        plt.ylabel('Amplitudo')
        plt.grid(True, which='both', linestyle='--', alpha=0.7)

        # Plot 2: Frequency Domain
        plt.subplot(2, 1, 2)
        plt.plot(xf_plot, magnitude, color='red', linewidth=1.5)
        plt.title('Domain Frekuensi (Spektrum Magnituda)')
        plt.xlabel('Frekuensi (Hz)')
        plt.ylabel('Magnituda')
        
        # ZOOM PENTING: Karena input dalam rad/s, frekuensi Hz-nya kecil.
        # Max rad/s input Anda adalah 12 rad/s ≈ 1.9 Hz.
        # Kita set limit grafik 0 sampai 2.5 Hz agar terlihat jelas.
        plt.xlim(0, 2.5) 
        
        # Tambahkan grid minor untuk pembacaan lebih teliti
        plt.minorticks_on()
        plt.grid(True, which='major', linestyle='-', linewidth=0.8)
        plt.grid(True, which='minor', linestyle=':', linewidth=0.5)

        plt.tight_layout()
        plt.show()

    except Exception as e:
        print(f"Error pada persamaan: {e}")

if __name__ == "__main__":
    signal_analyzer()