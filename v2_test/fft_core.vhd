library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fft_pkg.all;

entity fft_core is
    Port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        i_start   : in  std_logic;
        i_data_re : in  std_logic_vector(15 downto 0);
        i_data_im : in  std_logic_vector(15 downto 0);
        o_data_re : out std_logic_vector(15 downto 0);
        o_data_im : out std_logic_vector(15 downto 0);
        o_idx     : out std_logic_vector(5 downto 0);
        o_done    : out std_logic
    );
end fft_core;

architecture Behavioral of fft_core is

    -- Internal signal array to chain the 6 stages together
    signal stage_data : complex_array(0 to 6);
    
    -- Control Signals
    signal r_cnt      : unsigned(5 downto 0) := (others => '1'); -- Starts at 63 so first tick is 0
    signal r_active   : std_logic := '0';
    signal s_mode     : std_logic_vector(1 to 6);
    signal s_w        : complex_array(1 to 6);

    -- 24-cycle Metadata Pipeline to match hardware latency
    type t_idx_pipe is array (0 to 24) of unsigned(5 downto 0);
    signal r_idx_pipe  : t_idx_pipe := (others => (others => '0'));
    signal r_done_pipe : std_logic_vector(0 to 24) := (others => '0'); 

begin

    -- 1. Master Control Counter and Frame Sync
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_cnt <= (others => '1');
                r_active <= '0';
                r_idx_pipe <= (others => (others => '0'));
                r_done_pipe <= (others => '0');
            else
                -- Start counting on i_start pulse
                if i_start = '1' then
                    r_active <= '1';
                end if;

                if r_active = '1' then
                    r_cnt <= r_cnt + 1;
                    
                    -- Metadata Shift Register (Syncs o_idx/o_done with data)
                    r_idx_pipe(0) <= r_cnt;
                    r_idx_pipe(1 to 24) <= r_idx_pipe(0 to 23);
                    
                    -- Generate o_done pulse when the 64th sample of a frame is processed
                    if r_cnt = 63 then
                        r_done_pipe(0) <= '1';
                    else
                        r_done_pipe(0) <= '0';
                    end if;
                    r_done_pipe(1 to 24) <= r_done_pipe(0 to 23);
                end if;
            end if;
        end if;
    end process;

    -- 2. Stage Modes (Timing Gates for DIF FFT)
    s_mode(1) <= r_cnt(5); -- Stays '0' for 32, '1' for 32
    s_mode(2) <= r_cnt(4); -- Stays '0' for 16, '1' for 16...
    s_mode(3) <= r_cnt(3);
    s_mode(4) <= r_cnt(2);
    s_mode(5) <= r_cnt(1);
    s_mode(6) <= r_cnt(0);

    -- 3. Hard-Coded Twiddle Stride Mapping (DIF Algorithm)
    -- Rotation is only applied when s_mode = '1' (Butterfly Calc Phase)
    
    -- STAGE 1: Stride 1 (Indices 0 to 31)
    s_w(1).re <= C_ROM_RE(to_integer(unsigned'("0" & r_cnt(4 downto 0)))) when s_mode(1)='1' else to_signed(32767,16);
    s_w(1).im <= C_ROM_IM(to_integer(unsigned'("0" & r_cnt(4 downto 0)))) when s_mode(1)='1' else to_signed(0,16);
    
    -- STAGE 2: Stride 2 (0, 2, 4... 62)
    s_w(2).re <= C_ROM_RE(to_integer(unsigned'(r_cnt(3 downto 0) & "0"))) when s_mode(2)='1' else to_signed(32767,16);
    s_w(2).im <= C_ROM_IM(to_integer(unsigned'(r_cnt(3 downto 0) & "0"))) when s_mode(2)='1' else to_signed(0,16);
    
    -- STAGE 3: Stride 4 (0, 4, 8... 60)
    s_w(3).re <= C_ROM_RE(to_integer(unsigned'(r_cnt(2 downto 0) & "00"))) when s_mode(3)='1' else to_signed(32767,16);
    s_w(3).im <= C_ROM_IM(to_integer(unsigned'(r_cnt(2 downto 0) & "00"))) when s_mode(3)='1' else to_signed(0,16);
    
    -- STAGE 4: Stride 8
    s_w(4).re <= C_ROM_RE(to_integer(unsigned'(r_cnt(1 downto 0) & "000"))) when s_mode(4)='1' else to_signed(32767,16);
    s_w(4).im <= C_ROM_IM(to_integer(unsigned'(r_cnt(1 downto 0) & "000"))) when s_mode(4)='1' else to_signed(0,16);
    
    -- STAGE 5: Stride 16
    s_w(5).re <= C_ROM_RE(to_integer(unsigned'(r_cnt(0 downto 0) & "0000"))) when s_mode(5)='1' else to_signed(32767,16);
    s_w(5).im <= C_ROM_IM(to_integer(unsigned'(r_cnt(0 downto 0) & "0000"))) when s_mode(5)='1' else to_signed(0,16);
    
    -- STAGE 6: Always W^0 (Stride 32 is always 0)
    s_w(6).re <= to_signed(32767, 16);
    s_w(6).im <= to_signed(0, 16);

    -- 4. Connecting the Chain
    stage_data(0).re <= signed(i_data_re);
    stage_data(0).im <= signed(i_data_im);

    gen_chain: for i in 1 to 6 generate
        stage_inst: entity work.sdf_stage
            generic map ( G_DELAY => 2**(6-i) )
            port map (
                clk    => clk,
                rst    => rst,
                i_mode => s_mode(i),
                i_data => stage_data(i-1),
                i_w    => s_w(i),
                o_data => stage_data(i)
            );
    end generate;

    -- 5. Final Aligned and Bit-Reversed Outputs
    o_data_re <= std_logic_vector(stage_data(6).re);
    o_data_im <= std_logic_vector(stage_data(6).im);
    
    -- Bit-reversal mapping for 6-bit index
    -- Explicit Bit-Reversal Assignment to avoid concatenation ambiguity
    o_idx(5) <= r_idx_pipe(24)(0);
    o_idx(4) <= r_idx_pipe(24)(1);
    o_idx(3) <= r_idx_pipe(24)(2);
    o_idx(2) <= r_idx_pipe(24)(3);
    o_idx(1) <= r_idx_pipe(24)(4);
    o_idx(0) <= r_idx_pipe(24)(5);
    
    o_done <= r_done_pipe(24);

end Behavioral;