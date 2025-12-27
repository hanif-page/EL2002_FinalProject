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
    signal stage_data : complex_array(0 to 6);
    signal r_cnt      : unsigned(5 downto 0) := (others => '0');
    signal r_active   : std_logic := '0';
    signal s_mode     : std_logic_vector(1 to 6);
    signal s_w        : complex_array(1 to 6);

    -- Metadata Pipeline: 22 cycles accounts for 6 butterfly stages + 2-cycle mult delays
    type t_idx_pipe is array (0 to 22) of unsigned(5 downto 0);
    signal r_idx_pipe  : t_idx_pipe := (others => (others => '0'));
    signal r_done_pipe : std_logic_vector(0 to 22) := (others => '0'); 

begin

    -- 1. Control & Metadata Alignment
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_cnt <= (others => '0');
                r_active <= '0';
                r_idx_pipe <= (others => (others => '0'));
                r_done_pipe <= (others => '0');
            else
                -- Trigger processing on i_start
                if i_start = '1' then 
                    r_active <= '1'; 
                end if;
                
                if r_active = '1' then
                    r_cnt <= r_cnt + 1;
                    
                    -- Metadata (Index and Done) follows the data path
                    r_idx_pipe(0) <= r_cnt;
                    r_idx_pipe(1 to 22) <= r_idx_pipe(0 to 21);
                    
                    if r_cnt = 63 then 
                        r_done_pipe(0) <= '1';
                    else 
                        r_done_pipe(0) <= '0'; 
                    end if;
                    r_done_pipe(1 to 22) <= r_done_pipe(0 to 21);
                end if;
            end if;
        end if;
    end process;

    -- 2. Twiddle Selection & Gating Logic
    -- In DIF, twiddle rotation happens ONLY during the second half of each stage period
    
    -- Stage 1: Delay=32. Mode high when r_cnt(5) is '1'.
    s_mode(1) <= r_cnt(5);
    s_w(1).re <= C_ROM_RE(to_integer(unsigned'("0" & r_cnt(4 downto 0)))) when r_cnt(5)='1' else to_signed(32767,16);
    s_w(1).im <= C_ROM_IM(to_integer(unsigned'("0" & r_cnt(4 downto 0)))) when r_cnt(5)='1' else to_signed(0,16);

    -- Stage 2: Delay=16. Mode high when r_cnt(4) is '1'.
    s_mode(2) <= r_cnt(4);
    s_w(2).re <= C_ROM_RE(to_integer(unsigned'(r_cnt(3 downto 0) & "0"))) when r_cnt(4)='1' else to_signed(32767,16);
    s_w(2).im <= C_ROM_IM(to_integer(unsigned'(r_cnt(3 downto 0) & "0"))) when r_cnt(4)='1' else to_signed(0,16);

    -- Stage 3: Delay=8. Mode high when r_cnt(3) is '1'.
    s_mode(3) <= r_cnt(3);
    s_w(3).re <= C_ROM_RE(to_integer(unsigned'(r_cnt(2 downto 0) & "00"))) when r_cnt(3)='1' else to_signed(32767,16);
    s_w(3).im <= C_ROM_IM(to_integer(unsigned'(r_cnt(2 downto 0) & "00"))) when r_cnt(3)='1' else to_signed(0,16);

    -- Stage 4: Delay=4. Mode high when r_cnt(2) is '1'.
    s_mode(4) <= r_cnt(2);
    s_w(4).re <= C_ROM_RE(to_integer(unsigned'(r_cnt(1 downto 0) & "000"))) when r_cnt(2)='1' else to_signed(32767,16);
    s_w(4).im <= C_ROM_IM(to_integer(unsigned'(r_cnt(1 downto 0) & "000"))) when r_cnt(2)='1' else to_signed(0,16);

    -- Stage 5: Delay=2. Mode high when r_cnt(1) is '1'.
    s_mode(5) <= r_cnt(1);
    s_w(5).re <= C_ROM_RE(to_integer(unsigned'(r_cnt(0) & "0000"))) when r_cnt(1)='1' else to_signed(32767,16);
    s_w(5).im <= C_ROM_IM(to_integer(unsigned'(r_cnt(0) & "0000"))) when r_cnt(1)='1' else to_signed(0,16);

    -- Stage 6: Delay=1. Last stage usually has no twiddle, so we use W^0 (1.0).
    s_mode(6) <= r_cnt(0);
    s_w(6).re <= to_signed(32767, 16);
    s_w(6).im <= to_signed(0, 16);

    -- 3. Input Normalization
    -- Using shift_left(4) provides 16x gain, keeping signals clean but avoiding overflow.
    stage_data(0).re <= shift_left(signed(i_data_re), 4);
    stage_data(0).im <= (others => '0');

    -- 4. Pipelined Chain Implementation
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

    -- 5. Final Outputs (Bit-Reversed)
    -- Bit-reversal maps the natural output order to frequency order.
    o_data_re <= std_logic_vector(stage_data(6).re);
    o_data_im <= std_logic_vector(stage_data(6).im);
    
    o_idx(5) <= r_idx_pipe(22)(0);
    o_idx(4) <= r_idx_pipe(22)(1);
    o_idx(3) <= r_idx_pipe(22)(2);
    o_idx(2) <= r_idx_pipe(22)(3);
    o_idx(1) <= r_idx_pipe(22)(4);
    o_idx(0) <= r_idx_pipe(22)(5);
    
    o_done <= r_done_pipe(22);

end Behavioral;