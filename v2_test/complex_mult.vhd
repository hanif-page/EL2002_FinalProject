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
    signal r_data, r_w : complex_16;
    signal r_re_long, r_im_long : signed(31 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- Pipeline Stage 1: Registration
            r_data <= i_data;
            r_w    <= i_w;
            
            -- Pipeline Stage 2: Multiply (AC - BD) and (AD + BC)
            r_re_long <= (r_data.re * r_w.re) - (r_data.im * r_w.im);
            r_im_long <= (r_data.re * r_w.im) + (r_data.im * r_w.re);
            
            -- Truncate Q15 (bit 30 is the MSB of the result)
            o_res.re <= r_re_long(30 downto 15);
            o_res.im <= r_im_long(30 downto 15);
        end if;
    end process;
end Behavioral;