library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity tb_fft_system is
end tb_fft_system;

architecture sim of tb_fft_system is
    -- Clock and Reset
    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal i_start : std_logic := '0';

    -- Data signals
    signal i_data_re, i_data_im : std_logic_vector(15 downto 0) := (others => '0');
    signal o_data_re, o_data_im : std_logic_vector(15 downto 0);
    signal o_idx   : std_logic_vector(5 downto 0);
    signal o_done  : std_logic;

    -- Input Data ROM (Your provided 64-point sequence)
    type t_data_array is array (0 to 63) of std_logic_vector(15 downto 0);
    constant DATA_ROM : t_data_array := (
        x"0000", x"0134", x"0158", x"0104", x"0132", x"0164", x"0092", x"FF2E",
        x"FE96", x"FEE2", x"FEF2", x"FE9B", x"FEF7", x"004B", x"0153", x"0146",
        x"0100", x"0146", x"0153", x"004B", x"FEF7", x"FE9B", x"FEF2", x"FEE2",
        x"FE96", x"FF2E", x"0092", x"0164", x"0132", x"0104", x"0158", x"0134",
        x"0000", x"FECC", x"FEA8", x"FEFC", x"FECE", x"FE9C", x"FF6E", x"00D2",
        x"016A", x"011E", x"010E", x"0165", x"0109", x"FFB5", x"FEAD", x"FEBA",
        x"FF00", x"FEBA", x"FEAD", x"FFB5", x"0109", x"0165", x"010E", x"011E",
        x"016A", x"00D2", x"FF6E", x"FE9C", x"FECE", x"FEFC", x"FEA8", x"FECC"
    );

begin
    -- 100MHz Clock
    clk <= not clk after 5 ns;

    -- Instantiate the Full Core
    UUT: entity work.fft_core
        port map (
            clk => clk, rst => rst, i_start => i_start,
            i_data_re => i_data_re, i_data_im => i_data_im,
            o_data_re => o_data_re, o_data_im => o_data_im,
            o_idx => o_idx, o_done => o_done
        );

    -- Stimulus Process
    process
    begin
        -- Reset sequence
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait until rising_edge(clk);

        -- Start the FFT
        i_start <= '1';
        
        -- Feed 64 samples from DATA_ROM
        for i in 0 to 63 loop
            i_data_re <= DATA_ROM(i);
            i_data_im <= x"0000"; -- Purely real input
            wait until rising_edge(clk);
            i_start <= '0'; -- i_start only needs to pulse for the first sample
        end loop;

        -- Keep clocking to let the pipeline empty
        wait until o_done = '1';
        wait for 100 ns;
        
        report "Simulation Finished. Check waveform for Mirror Property.";
        wait;
    end process;
end sim;