library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_magnitude_calc is
end tb_magnitude_calc;

architecture behavior of tb_magnitude_calc is

    component magnitude_calc
    Port (
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;
        i_valid : in  STD_LOGIC;
        i_re    : in  STD_LOGIC_VECTOR(15 downto 0);
        i_im    : in  STD_LOGIC_VECTOR(15 downto 0);
        o_valid : out STD_LOGIC;
        o_mag   : out STD_LOGIC_VECTOR(15 downto 0)
    );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_valid : std_logic := '0';
    signal i_re, i_im : std_logic_vector(15 downto 0) := (others => '0');
    signal o_valid : std_logic;
    signal o_mag   : std_logic_vector(15 downto 0);

    constant clk_period : time := 10 ns;

begin

    uut: magnitude_calc PORT MAP (
        clk => clk, rst => rst,
        i_valid => i_valid,
        i_re => i_re, i_im => i_im,
        o_valid => o_valid, o_mag => o_mag
    );

    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
    begin
        -- Reset
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for clk_period;

        -- ========================================================
        -- FORMAT Q7.8 (Scale = 256)
        -- ========================================================

        -- KASUS 1: Pure Real Positive
        -- In: 10.0 + j0 (2560 + j0)
        -- Exp: 10.0 (2560)
        -- Calc: Max(2560) + 0.375*0 = 2560
        -----------------------------------------------------------
        i_valid <= '1';
        i_re <= std_logic_vector(to_signed(2560, 16));
        i_im <= std_logic_vector(to_signed(0, 16));
        wait for clk_period;

        -- KASUS 2: Pure Imag Negative (Tes ABS)
        -- In: 0 - j20.0 (0 - j5120)
        -- Exp: 20.0 (5120)
        -- Calc: Max(5120) + 0 = 5120
        -----------------------------------------------------------
        i_re <= std_logic_vector(to_signed(0, 16));
        i_im <= std_logic_vector(to_signed(-5120, 16));
        wait for clk_period;

        -- KASUS 3: Segitiga Pythagoras (3-4-5)
        -- In: 3.0 + j4.0 (768 + j1024)
        -- Ideal: 5.0 (1280)
        -- Approx: Max + 0.375*Min
        --         1024 + (768 * 0.375) 
        --         1024 + 288 = 1312 (5.125)
        -- Error: (5.125 - 5.0) / 5.0 = 2.5% (Sangat Bagus!)
        -----------------------------------------------------------
        i_re <= std_logic_vector(to_signed(768, 16));  -- 3.0
        i_im <= std_logic_vector(to_signed(1024, 16)); -- 4.0
        wait for clk_period;

        -- KASUS 4: Diagonal 45 Derajat
        -- In: 10.0 + j10.0 (2560 + j2560)
        -- Ideal: sqrt(200) = 14.14 (3620)
        -- Approx: 2560 + 0.375*2560 
        --         2560 + 960 = 3520 (13.75)
        -- Error: ~2.7%
        -----------------------------------------------------------
        i_re <= std_logic_vector(to_signed(2560, 16));
        i_im <= std_logic_vector(to_signed(2560, 16));
        wait for clk_period;

        i_valid <= '0';
        wait;
    end process;

end behavior;

