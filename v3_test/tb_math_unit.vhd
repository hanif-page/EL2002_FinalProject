library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity tb_fft_math is
end tb_fft_math;

architecture sim of tb_fft_math is
    signal clk : std_logic := '0';
    
    -- Butterfly Signals
    signal bf_iA, bf_iB : complex_16;
    signal bf_oSum, bf_oDif : complex_16;
    
    -- Multiplier Signals
    signal mult_iData : complex_16;
    signal mult_iW    : complex_16;
    signal mult_oRes  : complex_16;

begin
    clk <= not clk after 5 ns;

    -- Instantiate Unscaled Butterfly
    U_BF : entity work.butterfly_dif
        port map (
            i_A   => bf_iA,
            i_B   => bf_iB,
            o_Sum => bf_oSum,
            o_Dif => bf_oDif
        );

    -- Instantiate Rounding Multiplier
    U_MULT : entity work.complex_mult
        port map (
            clk    => clk,
            i_data => mult_iData,
            i_w    => mult_iW,
            o_res  => mult_oRes
        );

    process
    begin
        -- Reset / Initialization
        bf_iA.re <= to_signed(0, 16); bf_iA.im <= to_signed(0, 16);
        bf_iB.re <= to_signed(0, 16); bf_iB.im <= to_signed(0, 16);
        mult_iData.re <= to_signed(0, 16); mult_iData.im <= to_signed(0, 16);
        mult_iW.re <= to_signed(32767, 16); mult_iW.im <= to_signed(0, 16);
        wait for 20 ns;

        -- TEST 1: Butterfly Unscaled
        bf_iA.re <= to_signed(100, 16); 
        bf_iB.re <= to_signed(10, 16);
        wait for 5 ns; -- Combinational delay
        report "BF Result: Sum=" & integer'image(to_integer(bf_oSum.re)) & 
               " Diff=" & integer'image(to_integer(bf_oDif.re));

        -- TEST 2: Multiplier Rounding
        -- Input 90 rotated by approx 45 degrees (W^8)
        mult_iData.re <= to_signed(90, 16);
        mult_iW.re    <= to_signed(23170, 16); -- 0.7071 * 32768
        mult_iW.im    <= to_signed(-23170, 16);
        
        -- Wait for 2 clock cycles (Multiplier Latency)
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns; -- Small offset to let signal settle
        
        report "Mult Result: Re=" & integer'image(to_integer(mult_oRes.re)) & 
               " Im=" & integer'image(to_integer(mult_oRes.im));
        
        wait for 100 ns;
        report "Math Verification Complete.";
        wait;
    end process;

end sim;