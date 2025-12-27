library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package fft_pkg is

    -- 1. Complex Number Record (16-bit Signed)
    type complex_16 is record
        re : signed(15 downto 0);
        im : signed(15 downto 0);
    end record;

    -- 2. Flexible Array for Stage Interconnects
    -- This allows the fft_core to chain any number of stages
    type complex_array is array (natural range <>) of complex_16;

    -- 3. Raw Signed Array for Twiddle ROM Storage
    -- This prevents the "No feasible entries for TO_SIGNED" error
    type rom_array is array (0 to 63) of signed(15 downto 0);

    -- 4. Twiddle Factor ROM (Q15 Format: 1.0 = 32767)
    -- These provide the high-precision rotation needed to reach "Nearly 0" noise
    constant C_ROM_RE : rom_array := (
        to_signed(32767, 16), to_signed(32609, 16), to_signed(32137, 16), to_signed(31356, 16),
        to_signed(30272, 16), to_signed(28897, 16), to_signed(27244, 16), to_signed(25329, 16),
        to_signed(23169, 16), to_signed(20787, 16), to_signed(18204, 16), to_signed(15446, 16),
        to_signed(12539, 16), to_signed(9501, 16),  to_signed(6353, 16),  to_signed(3123, 16),
        to_signed(0, 16),     to_signed(-3123, 16), to_signed(-6353, 16), to_signed(-9501, 16),
        to_signed(-12539, 16),to_signed(-15446, 16),to_signed(-18204, 16),to_signed(-20787, 16),
        to_signed(-23169, 16),to_signed(-25329, 16),to_signed(-27244, 16),to_signed(-28897, 16),
        to_signed(-30272, 16),to_signed(-31356, 16),to_signed(-32137, 16),to_signed(-32609, 16),
        to_signed(-32767, 16),to_signed(-32609, 16),to_signed(-32137, 16),to_signed(-31356, 16),
        to_signed(-30272, 16),to_signed(-28897, 16),to_signed(-27244, 16),to_signed(-25329, 16),
        to_signed(-23169, 16),to_signed(-20787, 16),to_signed( -18204, 16),to_signed(-15446, 16),
        to_signed(-12539, 16),to_signed(-9501, 16), to_signed(-6353, 16), to_signed(-3123, 16),
        to_signed(0, 16),     to_signed(3123, 16),  to_signed(6353, 16),  to_signed(9501, 16),
        to_signed(12539, 16), to_signed(15446, 16), to_signed(18204, 16), to_signed(20787, 16),
        to_signed(23169, 16), to_signed(25329, 16), to_signed(27244, 16), to_signed(28897, 16),
        to_signed(30272, 16), to_signed(31356, 16), to_signed(32137, 16), to_signed(32609, 16)
    );

    constant C_ROM_IM : rom_array := (
        to_signed(0, 16),     to_signed(-3211, 16), to_signed(-6392, 16), to_signed(-9511, 16),
        to_signed(-12539, 16),to_signed(-15446, 16),to_signed(-18204, 16),to_signed(-20787, 16),
        to_signed(-23169, 16),to_signed(-25329, 16),to_signed(-27244, 16),to_signed(-28897, 16),
        to_signed(-30272, 16),to_signed(-31356, 16),to_signed(-32137, 16),to_signed(-32609, 16),
        to_signed(-32767, 16),to_signed(-32609, 16),to_signed(-32137, 16),to_signed(-31356, 16),
        to_signed(-30272, 16),to_signed(-28897, 16),to_signed(-27244, 16),to_signed(-25329, 16),
        to_signed(-23169, 16),to_signed(-20787, 16),to_signed(-18204, 16),to_signed(-15446, 16),
        to_signed(-12539, 16),to_signed(-9501, 16), to_signed(-6353, 16), to_signed(-3123, 16),
        to_signed(0, 16),     to_signed(3123, 16),  to_signed(6353, 16),  to_signed(9501, 16),
        to_signed(12539, 16), to_signed(15446, 16), to_signed(18204, 16), to_signed(20787, 16),
        to_signed(23169, 16), to_signed(25329, 16), to_signed(27244, 16), to_signed(28897, 16),
        to_signed(30272, 16), to_signed(31356, 16), to_signed(32137, 16), to_signed(32609, 16),
        to_signed(32767, 16), to_signed(32609, 16), to_signed(32137, 16), to_signed(31356, 16),
        to_signed(30272, 16), to_signed(28897, 16), to_signed(27244, 16), to_signed(25329, 16),
        to_signed(23169, 16), to_signed(20787, 16), to_signed(18204, 16), to_signed(15446, 16),
        to_signed(12539, 16), to_signed(9501, 16),  to_signed(6353, 16),  to_signed(3123, 16)
    );

end package;