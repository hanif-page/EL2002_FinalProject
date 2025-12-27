library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity butterfly_dif is
    Port (
        i_A   : in  complex_16;
        i_B   : in  complex_16;
        o_Sum : out complex_16;
        o_Dif : out complex_16
    );
end butterfly_dif;

architecture Behavioral of butterfly_dif is
begin
    -- Perform A+B and A-B without dividing by 2.
    -- This preserves the Least Significant Bits (LSBs) across stages.
    o_Sum.re <= i_A.re + i_B.re;
    o_Sum.im <= i_A.im + i_B.im;
    
    o_Dif.re <= i_A.re - i_B.re;
    o_Dif.im <= i_A.im - i_B.im;
end Behavioral;