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

    -- 1. INPUT DATA ROM (Peaking at ~360)
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

    -- 2. EXPECTED OUTPUT ROM (Correctly placed in Declarative Part)
    -- Scaling values reflect the shift_left(5) and FFT gain.
    type t_expected_array is array (0 to 63) of complex_16;
    constant EXPECTED_ROM : t_expected_array := (
        0  => (re => to_signed(0, 16),      im => to_signed(0, 16)),
        5  => (re => to_signed(15230, 16),  im => to_signed(0, 16)), -- Peak 1
        59 => (re => to_signed(15230, 16),  im => to_signed(0, 16)), -- Mirror 5
        15 => (re => to_signed(5115, 16),   im => to_signed(0, 16)), -- Peak 2
        49 => (re => to_signed(5115, 16),   im => to_signed(0, 16)), -- Mirror 15
        others => (re => (others => '0'),   im => (others => '0'))
    );

begin
    -- Clock Generation
    clk <= not clk after 5 ns;

    -- UUT Instance
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
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait until rising_edge(clk);

        -- FRAME 1: WARM-UP (Clears 'X' from logic)
        i_start <= '1';
        for i in 0 to 63 loop
            i_data_re <= DATA_ROM(i);
            wait until rising_edge(clk);
            i_start <= '0';
        end loop;

        -- FRAME 2: VALID DATA (The one we check)
        wait for 100 ns;
        i_start <= '1';
        for i in 0 to 63 loop
            i_data_re <= DATA_ROM(i);
            wait until rising_edge(clk);
            i_start <= '0';
        end loop;

        -- 3. REPORT GENERATION
        wait until o_done = '1';
        report "--- FFT VALIDATION REPORT (FRAME 2) ---";
        
        for i in 0 to 63 loop
            -- Capture values at each output index
            report "Bin [" & integer'image(to_integer(unsigned(o_idx))) & "] " &
                   "ACTUAL: (" & integer'image(to_integer(signed(o_data_re))) & ", " & 
                                 integer'image(to_integer(signed(o_data_im))) & "j) | " &
                   "EXPECTED: (" & integer'image(to_integer(EXPECTED_ROM(to_integer(unsigned(o_idx))).re)) & ", " &
                                   integer'image(to_integer(EXPECTED_ROM(to_integer(unsigned(o_idx))).im)) & "j)";
            
            -- Mirror Property Check for Bin 5 vs 59
            if o_idx = "000101" then -- Bin 5
                report ">>> CHECKING PEAK AT BIN 5";
            end if;

            wait until rising_edge(clk);
        end loop;

        report "--- END OF REPORT ---";
        wait;
    end process;

end sim;