library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity tb_sdf_stage is
end tb_sdf_stage;

architecture sim of tb_sdf_stage is
    -- Clock and Reset
    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    
    -- Stage Interface (Testing a Stage with G_DELAY = 4 for quick viewing)
    signal i_mode : std_logic := '0';
    signal i_data : complex_16;
    signal i_w    : complex_16;
    signal o_data : complex_16;

    constant C_DELAY : integer := 4;

begin
    -- 100MHz Clock
    clk <= not clk after 5 ns;

    -- Instantiate the Stage
    UUT: entity work.sdf_stage
        generic map ( G_DELAY => C_DELAY )
        port map (
            clk    => clk,
            rst    => rst,
            i_mode => i_mode,
            i_data => i_data,
            i_w    => i_w,
            o_data => o_data
        );

    process
    begin
        -- Initialization
        rst <= '1';
        i_mode <= '0';
        i_data.re <= (others => '0'); i_data.im <= (others => '0');
        i_w.re <= to_signed(32767, 16); i_w.im <= to_signed(0, 16); -- W^0 (Identity)
        wait for 20 ns;
        rst <= '0';
        wait until rising_edge(clk);

        -- PHASE 1: LOAD THE FIFO (i_mode = '0')
        -- We send 4 samples: 100, 200, 300, 400
        i_mode <= '0';
        for i in 1 to 4 loop
            i_data.re <= to_signed(i * 100, 16);
            wait until rising_edge(clk);
        end loop;

        -- PHASE 2: BUTTERFLY CALCULATION (i_mode = '1')
        -- We send the partners: 10, 20, 30, 40
        -- Expected Outputs (A+B): 110, 220, 330, 440
        i_mode <= '1';
        for i in 1 to 4 loop
            i_data.re <= to_signed(i * 10, 16);
            wait until rising_edge(clk);
        end loop;

        -- PHASE 3: FLUSH ROTATED DIFFERENCES (i_mode = '0')
        -- Expected Outputs (A-B)*W: 90, 180, 270, 360
        i_mode <= '0';
        i_data.re <= to_signed(0, 16); -- Input doesn't matter during flush
        wait for 80 ns;

        assert false report "SDF Stage Simulation Finished" severity note;
        wait;
    end process;
end sim;