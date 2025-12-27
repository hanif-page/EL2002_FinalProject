library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity tb_math_unit is
end tb_math_unit;

architecture sim of tb_math_unit is
    -- Clock and Reset
    signal clk : std_logic := '0';
    
    -- Butterfly Signals
    signal bf_A, bf_B, bf_Sum, bf_Dif : complex_16;
    
    -- Multiplier Signals
    signal mult_data, mult_twiddle, mult_res : complex_16;

begin
    -- Clock Generation (100MHz)
    clk <= not clk after 5 ns;

    -- 1. Instantiate Butterfly
    UUT_BF: entity work.butterfly_dif_scaled
        port map (
            i_A   => bf_A,
            i_B   => bf_B,
            o_Sum => bf_Sum,
            o_Dif => bf_Dif
        );

    -- 2. Instantiate Multiplier
    UUT_MULT: entity work.complex_mult
        port map (
            clk    => clk,
            i_data => mult_data,
            i_w    => mult_twiddle,
            o_res  => mult_res
        );

    -- Stimulus Process
    process
    begin
        -- Initialize inputs to zero to avoid 'U' issues at start
        bf_A.re <= (others => '0'); bf_A.im <= (others => '0');
        bf_B.re <= (others => '0'); bf_B.im <= (others => '0');
        mult_data.re <= (others => '0'); mult_data.im <= (others => '0');
        mult_twiddle.re <= (others => '0'); mult_twiddle.im <= (others => '0');
        
        wait for 20 ns; -- Wait for reset/init period

        -- Apply Test Data
        bf_A.re <= to_signed(10000, 16); bf_A.im <= to_signed(4000, 16);
        bf_B.re <= to_signed(2000, 16);  bf_B.im <= to_signed(1000, 16);
        
        mult_data.re <= to_signed(16384, 16); mult_data.im <= to_signed(0, 16);
        mult_twiddle.re <= to_signed(0, 16);  mult_twiddle.im <= to_signed(-32767, 16);
        
        -- Wait for 3 Rising Edges to clear the 2-cycle pipeline
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        
        -- Add 1ns offset so we aren't reading exactly on the clock edge
        wait for 1 ns;

        report "Butterfly Sum: " & integer'image(to_integer(bf_Sum.re)) & " + " & integer'image(to_integer(bf_Sum.im)) & "j";
        report "Butterfly Dif: " & integer'image(to_integer(bf_Dif.re)) & " + " & integer'image(to_integer(bf_Dif.im)) & "j";
        report "Mult Output (After Pipeline): " & integer'image(to_integer(mult_res.re)) & " + " & integer'image(to_integer(mult_res.im)) & "j";

        wait;
    end process;

end sim;