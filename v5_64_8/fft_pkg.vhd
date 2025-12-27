library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fft_pkg is
    constant points      : integer := 64;
    constant data_width  : integer := 8;
    type t_Complex_Array is array (0 to points-1) of signed(data_width-1 downto 0);
    type t_Twiddle_Array is array (0 to 31) of signed(data_width-1 downto 0);

    constant TWIDDLE_COS : t_Twiddle_Array := (
        to_signed(127, 8), to_signed(126, 8), to_signed(125, 8), to_signed(122, 8),
        to_signed(118, 8), to_signed(113, 8), to_signed(107, 8), to_signed(100, 8),
        to_signed(92, 8),  to_signed(84, 8),  to_signed(75, 8),  to_signed(65, 8),
        to_signed(55, 8),  to_signed(45, 8),  to_signed(34, 8),  to_signed(23, 8),
        to_signed(12, 8),  to_signed(1, 8),   to_signed(-9, 8),  to_signed(-20, 8),
        to_signed(-31, 8), to_signed(-42, 8), to_signed(-52, 8), to_signed(-62, 8),
        to_signed(-72, 8), to_signed(-81, 8), to_signed(-90, 8), to_signed(-98, 8),
        to_signed(-105,8), to_signed(-111,8), to_signed(-116,8), to_signed(-120,8)
    );
    constant TWIDDLE_SIN : t_Twiddle_Array := (
        to_signed(0, 8),    to_signed(-12, 8),  to_signed(-25, 8),  to_signed(-37, 8),
        to_signed(-49, 8),  to_signed(-60, 8),  to_signed(-71, 8),  to_signed(-81, 8),
        to_signed(-90, 8),  to_signed(-99, 8),  to_signed(-106,8),  to_signed(-113,8),
        to_signed(-118,8),  to_signed(-122,8),  to_signed(-125,8),  to_signed(-127,8),
        to_signed(-127,8),  to_signed(-127,8),  to_signed(-125,8),  to_signed(-123,8),
        to_signed(-119,8),  to_signed(-114,8),  to_signed(-108,8),  to_signed(-101,8),
        to_signed(-93, 8),  to_signed(-85, 8),  to_signed(-76, 8),  to_signed(-66, 8),
        to_signed(-56, 8),  to_signed(-46, 8),  to_signed(-35, 8),  to_signed(-24, 8)
    );
end package;