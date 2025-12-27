library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_FFT_System is
    -- Testbench tidak memiliki port
end tb_FFT_System;

architecture Sim of tb_FFT_System is

    -- 1. Komponen yang akan dites
    component FFT_System_Sim_Ready is
        Generic ( CLKS_PER_BIT : integer := 5208 ); 
        Port (
            clk_50mhz   : in std_logic;
            btn_rst_n   : in std_logic;
            btn_start_n : in std_logic;
            btn_send_n  : in std_logic;
            uart_rx     : in std_logic;
            uart_tx     : out std_logic;
            leds_n      : out std_logic_vector(2 downto 0)
        );
    end component;

    -- 2. Signal Internal untuk menghubungkan testbench ke DUT
    signal tb_clk       : std_logic := '0';
    signal tb_rst_n     : std_logic := '1';
    signal tb_start_n   : std_logic := '1';
    signal tb_send_n    : std_logic := '1';
    signal tb_rx        : std_logic := '1'; -- Idle UART state is High
    signal tb_tx        : std_logic;
    signal tb_leds      : std_logic_vector(2 downto 0);

    -- 3. Konstanta Simulasi
    constant c_CLK_PERIOD : time := 20 ns; -- 50 MHz
    
    -- Kita override baudrate agar simulasi super cepat
    -- Gunakan 10 clock per bit saja untuk simulasi
    constant c_CLKS_PER_BIT_SIM : integer := 10; 
    constant c_BIT_PERIOD : time := c_CLKS_PER_BIT_SIM * c_CLK_PERIOD;

begin

    -- 4. Instantiate DUT (Device Under Test)
    UUT: FFT_System_Sim_Ready
    generic map (
        CLKS_PER_BIT => c_CLKS_PER_BIT_SIM -- Override Baudrate untuk Sim
    )
    port map (
        clk_50mhz   => tb_clk,
        btn_rst_n   => tb_rst_n,
        btn_start_n => tb_start_n,
        btn_send_n  => tb_send_n,
        uart_rx     => tb_rx,
        uart_tx     => tb_tx,
        leds_n      => tb_leds
    );

    -- 5. Clock Generation Process
    clk_process : process
    begin
        tb_clk <= '0';
        wait for c_CLK_PERIOD/2;
        tb_clk <= '1';
        wait for c_CLK_PERIOD/2;
    end process;

    -- 6. Main Stimulus Process
    stim_proc: process
        -- Procedure untuk mengirim 1 byte via UART (Simulasi PC mengirim ke FPGA)
        procedure UART_SEND_BYTE(
            data_in : in std_logic_vector(7 downto 0)
        ) is
        begin
            -- Start Bit (Low)
            tb_rx <= '0';
            wait for c_BIT_PERIOD;
            
            -- Data Bits (LSB First)
            for i in 0 to 7 loop
                tb_rx <= data_in(i);
                wait for c_BIT_PERIOD;
            end loop;
            
            -- Stop Bit (High)
            tb_rx <= '1';
            wait for c_BIT_PERIOD;
            
            -- Jeda antar byte sedikit
            wait for c_BIT_PERIOD; 
        end procedure;

    begin
        -- A. Inisialisasi
        wait for 100 ns;
        
        -- B. Reset System
        tb_rst_n <= '0';
        wait for 200 ns;
        tb_rst_n <= '1';
        wait for 200 ns;

        -- C. Kirim Data Input (PC -> FPGA)
        -- Kita kirim angka 1, 2, 3 ... sampai 128
        report "--- MULAI MENGIRIM DATA UART ---";
        for i in 1 to 128 loop
            UART_SEND_BYTE(std_logic_vector(to_unsigned(i, 8)));
        end loop;
        report "--- SELESAI MENGIRIM DATA ---";

        wait for 500 ns;

        -- D. Tekan Tombol START (S2)
        -- Asumsi: Anda sudah mengecilkan counter debouncer menjadi 5 di VHDL asli
        report "--- TEKAN TOMBOL START ---";
        tb_start_n <= '0';
        wait for 500 ns; -- Tahan cukup lama agar tembus debouncer
        tb_start_n <= '1';

        -- Tunggu proses copy selesai (sangat cepat di simulasi)
        wait for 1 us;

        -- E. Tekan Tombol SEND (S3)
        report "--- TEKAN TOMBOL SEND ---";
        tb_send_n <= '0';
        wait for 500 ns; -- Tahan cukup lama
        tb_send_n <= '1';

        -- F. Observasi Output (FPGA -> PC)
        -- Di Waveform, lihat sinyal 'tb_tx'. 
        -- Harusnya muncul pola toggle yang merepresentasikan data 01, 02, 03...
        
        wait for 200 us; -- Tunggu cukup lama agar semua data keluar
        
        report "--- SIMULASI SELESAI ---";
        wait;
    end process;

end Sim;