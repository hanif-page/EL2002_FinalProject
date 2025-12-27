library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity complex_mult is
    Port (
        clk      : in  std_logic;
        i_data   : in  complex_16;
        i_w      : in  complex_16;
        o_res    : out complex_16
    );
end complex_mult;

architecture Behavioral of complex_mult is
    -- Internal 32-bit signals to hold the full product before rounding
    signal r_re_long, r_im_long : signed(31 downto 0) := (others => '0');
begin
    process(clk)
        variable v_round_re, v_round_im : signed(31 downto 0);
    begin
        if rising_edge(clk) then
            -- 1. Standard complex multiplication: (a+bi)(c+di) = (ac-bd) + (ad+bc)i
            r_re_long <= (i_data.re * i_w.re) - (i_data.im * i_w.im);
            r_im_long <= (i_data.re * i_w.im) + (i_data.im * i_w.re);
            
            -- 2. Apply Rounding Offset (16384 represents 0.5 in Q15 format)
            -- This minimizes quantization noise and preserves mirror symmetry.
            v_round_re := r_re_long + to_signed(16384, 32);
            v_round_im := r_im_long + to_signed(16384, 32);
            
            -- 3. Truncate back to 16 bits (Shift right by 15)
            o_res.re <= v_round_re(30 downto 15);
            o_res.im <= v_round_im(30 downto 15);
        end if;
    end process;
end Behavioral;