library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package fft_pkg is

    -- Record to group Real and Imaginary components for cleaner routing
    type complex_16 is record
        re : signed(15 downto 0);
        im : signed(15 downto 0);
    end record;

    -- Array type for holding the 64 twiddle factors
    type complex_array is array (natural range <>) of complex_16;
    
    type rom_array is array (0 to 63) of signed(15 downto 0);

    -- 64-Point Real Part (Cosine)
    -- Formula: 32767 * cos(2 * pi * k / 64)
    constant C_ROM_RE : rom_array := (
        to_signed(32767, 16),  to_signed(32609, 16),  to_signed(32137, 16),  to_signed(31356, 16),
        to_signed(30272, 16),  to_signed(28897, 16),  to_signed(27244, 16),  to_signed(25329, 16),
        to_signed(23170, 16),  to_signed(20787, 16),  to_signed(18204, 16),  to_signed(15446, 16),
        to_signed(12539, 16),  to_signed(9511, 16),   to_signed(6392, 16),   to_signed(3211, 16),
        to_signed(0, 16),      to_signed(-3211, 16),  to_signed(-6392, 16),  to_signed(-9511, 16),
        to_signed(-12539, 16), to_signed(-15446, 16), to_signed(-18204, 16), to_signed(-20787, 16),
        to_signed(-23170, 16), to_signed(-25329, 16), to_signed(-27244, 16), to_signed(-28897, 16),
        to_signed(-30272, 16), to_signed(-31356, 16), to_signed(-32137, 16), to_signed(-32609, 16),
        to_signed(-32767, 16), to_signed(-32609, 16), to_signed(-32137, 16), to_signed(-31356, 16),
        to_signed(-30272, 16), to_signed(-28897, 16), to_signed(-27244, 16), to_signed(-25329, 16),
        to_signed(-23170, 16), to_signed(20787, 16),  to_signed(-18204, 16), to_signed(-15446, 16),
        to_signed(-12539, 16), to_signed(-9511, 16),  to_signed(-6392, 16),  to_signed(-3211, 16),
        to_signed(0, 16),      to_signed(3211, 16),   to_signed(6392, 16),   to_signed(9511, 16),
        to_signed(12539, 16),  to_signed(15446, 16),  to_signed(18204, 16),  to_signed(20787, 16),
        to_signed(23170, 16),  to_signed(25329, 16),  to_signed(27244, 16),  to_signed(28897, 16),
        to_signed(30272, 16),  to_signed(31356, 16),  to_signed(32137, 16),  to_signed(32609, 16)
    );

    -- 64-Point Imaginary Part (Sine, Negated for Forward FFT)
    -- Formula: -32767 * sin(2 * pi * k / 64)
    constant C_ROM_IM : rom_array := (
        to_signed(0, 16),      to_signed(-3211, 16),  to_signed(-6392, 16),  to_signed(-9511, 16),
        to_signed(-12539, 16), to_signed(-15446, 16), to_signed(-18204, 16), to_signed(-20787, 16),
        to_signed(-23170, 16), to_signed(-25329, 16), to_signed(-27244, 16), to_signed(-28897, 16),
        to_signed(-30272, 16), to_signed(-31356, 16), to_signed(-32137, 16), to_signed(-32609, 16),
        to_signed(-32767, 16), to_signed(-32609, 16), to_signed(-32137, 16), to_signed(-31356, 16),
        to_signed(-30272, 16), to_signed(-28897, 16), to_signed(-27244, 16), to_signed(-25329, 16),
        to_signed(-23170, 16), to_signed(-20787, 16), to_signed(-18204, 16), to_signed(-15446, 16),
        to_signed(-12539, 16), to_signed(-9511, 16),  to_signed(-6392, 16),  to_signed(-3211, 16),
        to_signed(0, 16),      to_signed(3211, 16),   to_signed(6392, 16),   to_signed(9511, 16),
        to_signed(12539, 16),  to_signed(15446, 16),  to_signed(18204, 16),  to_signed(20787, 16),
        to_signed(23170, 16),  to_signed(25329, 16),  to_signed(27244, 16),  to_signed(28897, 16),
        to_signed(30272, 16),  to_signed(31356, 16),  to_signed(32137, 16),  to_signed(32609, 16),
        to_signed(32767, 16),  to_signed(32609, 16),  to_signed(32137, 16),  to_signed(31356, 16),
        to_signed(30272, 16),  to_signed(28897, 16),  to_signed(27244, 16),  to_signed(25329, 16),
        to_signed(23170, 16),  to_signed(20787, 16),  to_signed(18204, 16),  to_signed(15446, 16),
        to_signed(12539, 16),  to_signed(9511, 16),   to_signed(6392, 16),   to_signed(3211, 16)
    );

end package;