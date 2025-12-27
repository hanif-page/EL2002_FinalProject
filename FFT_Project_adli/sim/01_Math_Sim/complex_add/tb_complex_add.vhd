library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; -- Penting untuk konversi angka ke biner

entity tb_complex_add is
    -- Entity testbench selalu kosong (tidak punya port)
end tb_complex_add;

architecture behavior of tb_complex_add is

    -- 1. Deklarasi Komponen yang mau dites (DUT: Device Under Test)
    component complex_add
    Port (
        i_a_re   : in  STD_LOGIC_VECTOR(15 downto 0);
        i_a_im   : in  STD_LOGIC_VECTOR(15 downto 0);
        i_b_re   : in  STD_LOGIC_VECTOR(15 downto 0);
        i_b_im   : in  STD_LOGIC_VECTOR(15 downto 0);
        o_sum_re : out STD_LOGIC_VECTOR(15 downto 0);
        o_sum_im : out STD_LOGIC_VECTOR(15 downto 0);
        o_dif_re : out STD_LOGIC_VECTOR(15 downto 0);
        o_dif_im : out STD_LOGIC_VECTOR(15 downto 0)
    );
    end component;

    -- 2. Deklarasi Sinyal Kabel (Penghubung)
    signal t_i_a_re, t_i_a_im : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal t_i_b_re, t_i_b_im : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal t_o_sum_re, t_o_sum_im : STD_LOGIC_VECTOR(15 downto 0);
    signal t_o_dif_re, t_o_dif_im : STD_LOGIC_VECTOR(15 downto 0);

    -- Periode jeda antar tes
    constant T_DELAY : time := 20 ns;

begin

    -- 3. Instansiasi (Pasang Kabel)
    uut: complex_add port map (
        i_a_re   => t_i_a_re,
        i_a_im   => t_i_a_im,
        i_b_re   => t_i_b_re,
        i_b_im   => t_i_b_im,
        o_sum_re => t_o_sum_re,
        o_sum_im => t_o_sum_im,
        o_dif_re => t_o_dif_re,
        o_dif_im => t_o_dif_im
    );

    -- 4. Proses Stimulus (Skenario Tes)
    stim_proc: process
    begin
        -- Tunggu sebentar agar stabil
        wait for 50 ns;

        ------------------------------------------------------------
        -- KASUS 1: Penjumlahan Positif Sederhana
        -- A = 10 + j5
        -- B = 20 + j1
        -- Ekspektasi Sum = 30 + j6
        -- Ekspektasi Dif = -10 + j4
        ------------------------------------------------------------
        -- to_signed(angka, 16 bit) akan otomatis mengubah angka desimal jadi biner
        t_i_a_re <= std_logic_vector(to_signed(10, 16));
        t_i_a_im <= std_logic_vector(to_signed(5, 16));
        t_i_b_re <= std_logic_vector(to_signed(20, 16));
        t_i_b_im <= std_logic_vector(to_signed(1, 16));
        wait for T_DELAY;

        ------------------------------------------------------------
        -- KASUS 2: Angka Negatif
        -- A = 100 - j50
        -- B = -20 + j30
        -- Ekspektasi Sum = 80 - j20
        -- Ekspektasi Dif = 120 - j80
        ------------------------------------------------------------
        t_i_a_re <= std_logic_vector(to_signed(100, 16));
        t_i_a_im <= std_logic_vector(to_signed(-50, 16));
        t_i_b_re <= std_logic_vector(to_signed(-20, 16));
        t_i_b_im <= std_logic_vector(to_signed(30, 16));
        wait for T_DELAY;

        ------------------------------------------------------------
        -- KASUS 3: Cek Nol
        -- A = 1234 + j0
        -- B = 0    + j0
        ------------------------------------------------------------
        t_i_a_re <= std_logic_vector(to_signed(1234, 16));
        t_i_a_im <= std_logic_vector(to_signed(0, 16));
        t_i_b_re <= std_logic_vector(to_signed(0, 16));
        t_i_b_im <= std_logic_vector(to_signed(0, 16));
        wait for T_DELAY;

        -- Selesai
        wait;
    end process;

end behavior;