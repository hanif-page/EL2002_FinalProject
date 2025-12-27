-- library IEEE;
-- use IEEE.STD_LOGIC_1164.ALL;
-- use IEEE.NUMERIC_STD.ALL;

-- entity sdf_stage is
--    Generic (
--        G_DELAY : integer := 32 -- Delay length (N/2 for the stage)
--    );
--    Port (
--        clk       : in  STD_LOGIC;
--        rst       : in  STD_LOGIC;
--        i_mode    : in  STD_LOGIC; -- 0: Load FIFO, 1: Butterfly Calc
--        i_data_re : in  STD_LOGIC_VECTOR(15 downto 0);
--        i_data_im : in  STD_LOGIC_VECTOR(15 downto 0);
--        i_w_re    : in  STD_LOGIC_VECTOR(15 downto 0);
--        i_w_im    : in  STD_LOGIC_VECTOR(15 downto 0);
--        o_data_re : out STD_LOGIC_VECTOR(15 downto 0);
--        o_data_im : out STD_LOGIC_VECTOR(15 downto 0)
--    );
-- end sdf_stage;

-- architecture Behavioral of sdf_stage is

--    -- COMPONENT DECLARATIONS
--    component complex_add
--        Port (
--            i_a_re, i_a_im : in STD_LOGIC_VECTOR(15 downto 0);
--            i_b_re, i_b_im : in STD_LOGIC_VECTOR(15 downto 0);
--            o_sum_re, o_sum_im : out STD_LOGIC_VECTOR(15 downto 0);
--            o_dif_re, o_dif_im : out STD_LOGIC_VECTOR(15 downto 0)
--        );
--    end component;

--    component complex_mult
--        Port (
--            clk : in STD_LOGIC;
--            i_data_re, i_data_im : in STD_LOGIC_VECTOR(15 downto 0);
--            i_w_re, i_w_im : in STD_LOGIC_VECTOR(15 downto 0);
--            o_res_re, o_res_im : out STD_LOGIC_VECTOR(15 downto 0)
--        );
--    end component;

--    -- SIGNALS
--    -- FIFO
--    type fifo_type is array (0 to G_DELAY-1) of std_logic_vector(15 downto 0);
--    signal fifo_re : fifo_type;
--    signal fifo_im : fifo_type;
--    signal s_fifo_out_re, s_fifo_out_im : std_logic_vector(15 downto 0);

--    -- Adder/Butterfly Signals
--    signal s_bf_sum_re, s_bf_sum_im : std_logic_vector(15 downto 0);
--    signal s_bf_dif_re, s_bf_dif_im : std_logic_vector(15 downto 0);

--    -- Multiplier Inputs
--    signal s_mult_in_re, s_mult_in_im : std_logic_vector(15 downto 0);

-- begin

--    -- 1. INSTANTIATE COMPLEX ADDER (Butterfly)
--    -- Input A = FIFO Output (Delayed data)
--    -- Input B = Current Input
--    inst_add: complex_add
--    port map (
--        i_a_re => s_fifo_out_re,
--        i_a_im => s_fifo_out_im,
--        i_b_re => i_data_re,
--        i_b_im => i_data_im,
--        o_sum_re => s_bf_sum_re,
--        o_sum_im => s_bf_sum_im,
--        o_dif_re => s_bf_dif_re,
--        o_dif_im => s_bf_dif_im
--    );

--    -- 2. INSTANTIATE COMPLEX MULTIPLIER
--    inst_mult: complex_mult
--    port map (
--        clk => clk,
--        i_data_re => s_mult_in_re,
--        i_data_im => s_mult_in_im,
--        i_w_re => i_w_re,
--        i_w_im => i_w_im,
--        o_res_re => o_data_re,
--        o_res_im => o_data_im
--    );

--    -- 3. FIFO LOGIC (Shift Register)
--    s_fifo_out_re <= fifo_re(0);
--    s_fifo_out_im <= fifo_im(0);

--    process(clk)
--    begin
--        if rising_edge(clk) then
--            if rst = '1' then
--                fifo_re <= (others => (others => '0'));
--                fifo_im <= (others => (others => '0'));
--            else
--                -- Shift elements
--                fifo_re(0 to G_DELAY-2) <= fifo_re(1 to G_DELAY-1);
--                fifo_im(0 to G_DELAY-2) <= fifo_im(1 to G_DELAY-1);
              
--                -- Feed FIFO
--                if i_mode = '0' then
--                    -- Load Mode: Store input
--                    fifo_re(G_DELAY-1) <= i_data_re;
--                    fifo_im(G_DELAY-1) <= i_data_im;
--                else
--                    -- Calc Mode: Store Difference (Butterfly Bottom)
--                    fifo_re(G_DELAY-1) <= s_bf_dif_re;
--                    fifo_im(G_DELAY-1) <= s_bf_dif_im;
--                end if;
--            end if;
--        end if;
--    end process;

--    -- 4. MULTIPLIER INPUT MUX
--    process(i_mode, s_fifo_out_re, s_fifo_out_im, s_bf_sum_re, s_bf_sum_im)
--    begin
--        if i_mode = '0' then
--            -- Pass FIFO output directly (effectively bypassing butterfly for the first half)
--            -- Note: In i_mode=0, Twiddle input (i_w) should ideally be 1.0
--            s_mult_in_re <= s_fifo_out_re;
--            s_mult_in_im <= s_fifo_out_im;
--        else
--            -- Process Sum (Butterfly Top)
--            s_mult_in_re <= s_bf_sum_re;
--            s_mult_in_im <= s_bf_sum_im;
--        end if;
--    end process;

-- end Behavioral;

