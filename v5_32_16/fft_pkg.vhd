library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fft_pkg is
    constant points      : integer := 32;
    constant data_width  : integer := 16;
    
    type t_Complex_Array is array (0 to points-1) of signed(data_width-1 downto 0);
    type t_Twiddle_Array is array (0 to 15) of signed(data_width-1 downto 0);

    -- Refactor: High-Precision Twiddle Factors [cite: 479-480]
    constant TWIDDLE_COS : t_Twiddle_Array := (
        to_signed(32767, 16), to_signed(32137, 16), to_signed(30272, 16), to_signed(27244, 16),
        to_signed(23169, 16), to_signed(18204, 16), to_signed(12539, 16), to_signed(6392, 16),
        to_signed(0, 16),     to_signed(-6393, 16), to_signed(-12540,16), to_signed(-18205,16),
        to_signed(-23170,16), to_signed(-27245,16), to_signed(-30273,16), to_signed(-32138,16)
    );

    constant TWIDDLE_SIN : t_Twiddle_Array := (
        to_signed(0, 16),     to_signed(-6393, 16), to_signed(-12540,16), to_signed(-18205,16),
        to_signed(-23170,16), to_signed(-27245,16), to_signed(-30273,16), to_signed(-32138,16),
        to_signed(-32767,16), to_signed(-32138,16), to_signed(-30273,16), to_signed(-27245,16),
        to_signed(-23170,16), to_signed(-18205,16), to_signed(-12540,16), to_signed(-6393, 16)
    );
end package;