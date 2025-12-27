library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity butterfly_dif_scaled is
    Port (
        i_A   : in  complex_16; -- From FIFO
        i_B   : in  complex_16; -- Direct Input
        o_Sum : out complex_16; -- (A + B) / 2
        o_Dif : out complex_16  -- (A - B) / 2
    );
end butterfly_dif_scaled;

architecture Behavioral of butterfly_dif_scaled is
begin
    -- Divide by 2 (shift_right) at every stage prevents overflow
    o_Sum.re <= shift_right(i_A.re + i_B.re, 1);
    o_Sum.im <= shift_right(i_A.im + i_B.im, 1);
    
    o_Dif.re <= shift_right(i_A.re - i_B.re, 1);
    o_Dif.im <= shift_right(i_A.im - i_B.im, 1);
end Behavioral;