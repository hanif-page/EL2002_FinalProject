library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity tb_sdf_stage is
end tb_sdf_stage;

architecture sim of tb_sdf_stage is
    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal i_mode : std_logic := '0';
    signal i_data : complex_16;
    signal i_w    : complex_16;
    signal o_data : complex_16;

    constant DELAY : integer := 4;
begin
    clk <= not clk after 5 ns;

    -- Instantiate the Stage
    UUT: entity work.sdf_stage
        generic map ( G_DELAY => DELAY )
        port map (
            clk => clk, rst => rst,
            i_mode => i_mode, i_data => i_data,
            i_w => i_w, o_data => o_data
        );

    process
    begin
        -- Reset
        rst <= '1';
        i_w.re <= to_signed(32767, 16); i_w.im <= to_signed(0, 16); -- W^0 = 1
        wait for 20 ns;
        rst <= '0';

        -- PHASE 1: Load 4 samples (i_mode = 0)
        -- We send: 100, 200, 300, 400
        i_mode <= '0';
        for i in 1 to 4 loop
            i_data.re <= to_signed(i * 100, 16);
            i_data.im <= (others => '0');
            wait until rising_edge(clk);
        end loop;

        -- PHASE 2: Butterfly 4 samples (i_mode = 1)
        -- We send: 10, 20, 30, 40
        -- These will pair with the 100, 200, 300, 400 in the FIFO
        i_mode <= '1';
        for i in 1 to 4 loop
            i_data.re <= to_signed(i * 10, 16);
            i_data.im <= (others => '0');
            wait until rising_edge(clk);
        end loop;
        
        -- PHASE 3: Back to Mode 0 to flush the Difference results
        i_mode <= '0';
        wait for 100 ns;
        wait;
    end process;
end sim;