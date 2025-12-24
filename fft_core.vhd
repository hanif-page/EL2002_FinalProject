library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- MANDATORY ENTITY DECLARATION [cite: 22]
entity fft_core is
    Port (
        clk       : in  STD_LOGIC;
        rst       : in  STD_LOGIC;
        i_start   : in  STD_LOGIC;
        i_data_re : in  STD_LOGIC_VECTOR(15 downto 0);
        i_data_im : in  STD_LOGIC_VECTOR(15 downto 0);
        o_data_re : out STD_LOGIC_VECTOR(15 downto 0);
        o_data_im : out STD_LOGIC_VECTOR(15 downto 0);
        o_idx     : out STD_LOGIC_VECTOR(5 downto 0);
        o_done    : out STD_LOGIC
    );
end fft_core;

-- Inside fft_core.vhd
architecture Behavioral of fft_core is

    component sdf_stage is
        Generic ( G_DELAY : integer );
        Port (
            clk       : in  STD_LOGIC; -- Separate these
            rst       : in  STD_LOGIC; -- Separate these
            i_mode    : in  STD_LOGIC;
            i_data_re : in  STD_LOGIC_VECTOR(15 downto 0);
            i_data_im : in  STD_LOGIC_VECTOR(15 downto 0);
            i_w_re    : in  STD_LOGIC_VECTOR(15 downto 0);
            i_w_im    : in  STD_LOGIC_VECTOR(15 downto 0);
            o_data_re : out STD_LOGIC_VECTOR(15 downto 0);
            o_data_im : out STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;
    -- ...

    component twiddle_rom is
        Port (
            clk : in STD_LOGIC;
            i_addr : in STD_LOGIC_VECTOR(5 downto 0);
            o_w_re, o_w_im : out STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;

    constant ONE_RE : std_logic_vector(15 downto 0) := x"7FFF";
    constant ONE_IM : std_logic_vector(15 downto 0) := x"0000";

    type t_arr_16 is array (0 to 6) of std_logic_vector(15 downto 0);
    signal stage_re, stage_im : t_arr_16;
  
    type t_arr_tw is array (1 to 5) of std_logic_vector(15 downto 0);
    signal w_re, w_im : t_arr_tw;
  
    signal r_cnt : unsigned(5 downto 0) := (others => '0');
    signal r_active : std_logic := '0';
    signal s_stg_ctrl : std_logic_vector(1 to 6);

    -- NEW: Intermediate signals to fix "not globally static" error
    signal addr1, addr2, addr3, addr4, addr5 : std_logic_vector(5 downto 0);

begin
    -- Simple Global Counter for Control
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_cnt <= (others => '0');
                r_active <= '0';
                o_done <= '0';
            else
                if i_start = '1' then
                    r_active <= '1';
                end if;
              
                if r_active = '1' then
                    r_cnt <= r_cnt + 1;
                    if r_cnt = "111111" then o_done <= '1'; else o_done <= '0'; end if;
                end if;
            end if;
        end if;
    end process;
    o_idx <= std_logic_vector(r_cnt);

    stage_re(0) <= i_data_re;
    stage_im(0) <= i_data_im;

    s_stg_ctrl(1) <= r_cnt(5);
    s_stg_ctrl(2) <= r_cnt(4);
    s_stg_ctrl(3) <= r_cnt(3);
    s_stg_ctrl(4) <= r_cnt(2);
    s_stg_ctrl(5) <= r_cnt(1);
    s_stg_ctrl(6) <= r_cnt(0);

    -- NEW: Drive the intermediate address signals
    addr1 <= std_logic_vector(r_cnt(4 downto 0)) & '0';
    addr2 <= std_logic_vector(r_cnt(3 downto 0)) & "00";
    addr3 <= std_logic_vector(r_cnt(2 downto 0)) & "000";
    addr4 <= std_logic_vector(r_cnt(1 downto 0)) & "0000";
    addr5 <= std_logic_vector(r_cnt(0 downto 0)) & "00000";

    -- Stage 1 (Delay 32)
    rom1: twiddle_rom port map(clk, addr1, w_re(1), w_im(1));
    stg1: sdf_stage generic map(32) port map(clk, rst, s_stg_ctrl(1), stage_re(0), stage_im(0), w_re(1), w_im(1), stage_re(1), stage_im(1));

    -- Stage 2 (Delay 16)
    rom2: twiddle_rom port map(clk, addr2, w_re(2), w_im(2));
    stg2: sdf_stage generic map(16) port map(clk, rst, s_stg_ctrl(2), stage_re(1), stage_im(1), w_re(2), w_im(2), stage_re(2), stage_im(2));

    -- Stage 3 (Delay 8)
    rom3: twiddle_rom port map(clk, addr3, w_re(3), w_im(3));
    stg3: sdf_stage generic map(8) port map(clk, rst, s_stg_ctrl(3), stage_re(2), stage_im(2), w_re(3), w_im(3), stage_re(3), stage_im(3));

    -- Stage 4 (Delay 4)
    rom4: twiddle_rom port map(clk, addr4, w_re(4), w_im(4));
    stg4: sdf_stage generic map(4) port map(clk, rst, s_stg_ctrl(4), stage_re(3), stage_im(3), w_re(4), w_im(4), stage_re(4), stage_im(4));

    -- Stage 5 (Delay 2)
    rom5: twiddle_rom port map(clk, addr5, w_re(5), w_im(5));
    stg5: sdf_stage generic map(2) port map(clk, rst, s_stg_ctrl(5), stage_re(4), stage_im(4), w_re(5), w_im(5), stage_re(5), stage_im(5));

    -- Stage 6 (Delay 1)
    stg6: sdf_stage generic map(1) port map(clk, rst, s_stg_ctrl(6), stage_re(5), stage_im(5), ONE_RE, ONE_IM, stage_re(6), stage_im(6));

    o_data_re <= stage_re(6);
    o_data_im <= stage_im(6);

end Behavioral;