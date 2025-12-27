library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_complex_mult is
    -- Kosong
end tb_complex_mult;

architecture behavior of tb_complex_mult is

    component complex_mult
    Port (
        clk       : in  STD_LOGIC;
        i_data_re : in  STD_LOGIC_VECTOR(15 downto 0);
        i_data_im : in  STD_LOGIC_VECTOR(15 downto 0);
        i_w_re    : in  STD_LOGIC_VECTOR(15 downto 0);
        i_w_im    : in  STD_LOGIC_VECTOR(15 downto 0);
        o_res_re  : out STD_LOGIC_VECTOR(15 downto 0);
        o_res_im  : out STD_LOGIC_VECTOR(15 downto 0)
    );
    end component;

    signal clk : std_logic := '0';
    signal i_data_re, i_data_im : std_logic_vector(15 downto 0) := (others => '0');
    signal i_w_re, i_w_im       : std_logic_vector(15 downto 0) := (others => '0');
    signal o_res_re, o_res_im   : std_logic_vector(15 downto 0);

    constant clk_period : time := 10 ns;

begin

    uut: complex_mult PORT MAP (
        clk => clk,
        i_data_re => i_data_re, i_data_im => i_data_im,
        i_w_re => i_w_re, i_w_im => i_w_im,
        o_res_re => o_res_re, o_res_im => o_res_im
    );

    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
    begin
        wait for 20 ns;

        -- ==========================================================
        -- FORMAT Q7.8 (Scaling = 256)
        -- ==========================================================

        -- KASUS 1: Perkalian Bilangan Bulat x Pecahan
        -- Data = 10.0 + j0   -> (10 * 256) = 2560
        -- W    = 0.5  + j0   -> (0.5 * 256) = 128
        -- Ekspektasi: 5.0    -> (5 * 256)   = 1280
        -------------------------------------------------------------
        i_data_re <= std_logic_vector(to_signed(2560, 16)); -- 10.0
        i_data_im <= std_logic_vector(to_signed(0, 16));
        
        i_w_re    <= std_logic_vector(to_signed(128, 16));  -- 0.5
        i_w_im    <= std_logic_vector(to_signed(0, 16));
        
        wait for clk_period * 5;

        -- KASUS 2: Perkalian Negatif
        -- Data = -20.0 + j0  -> (-20 * 256) = -5120
        -- W    = 0.5   + j0  -> 128
        -- Ekspektasi: -10.0  -> (-10 * 256) = -2560
        -------------------------------------------------------------
        i_data_re <= std_logic_vector(to_signed(-5120, 16));
        i_data_im <= std_logic_vector(to_signed(0, 16));
        
        i_w_re    <= std_logic_vector(to_signed(128, 16));
        i_w_im    <= std_logic_vector(to_signed(0, 16));
        
        wait for clk_period * 5;

        wait;
    end process;

end behavior;