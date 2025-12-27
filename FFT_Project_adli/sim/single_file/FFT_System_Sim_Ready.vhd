library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =============================================================================
-- 1. DEBOUNCER MODULE (Tetap Dipakai)
-- =============================================================================
entity Debounce is
    Port (
        clk    : in  std_logic;
        btn_in : in  std_logic;
        btn_out: out std_logic
    );
end Debounce;

architecture Behavioral of Debounce is
    signal count : integer range 0 to 250000 := 0;
    signal state : std_logic := '0';
    signal sync_0, sync_1 : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            sync_1 <= sync_0;
            sync_0 <= btn_in;
            if (sync_1 /= state) then
                if count < 5 then count <= count + 1;
                else count <= 0; state <= sync_1; end if;
            else
                count <= 0;
            end if;
        end if;
    end process;
    btn_out <= state;
end Behavioral;

-- =============================================================================
-- 2. UART MODULE (TIDAK BERUBAH)
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_Module is
    Generic ( CLKS_PER_BIT : integer ); 
    Port (
        clk, rst : in std_logic;
        rx_pin : in std_logic;
        tx_pin : out std_logic;
        rx_data : out std_logic_vector(7 downto 0);
        rx_done : out std_logic;
        tx_data : in std_logic_vector(7 downto 0);
        tx_start : in std_logic;
        tx_busy : out std_logic
    );
end UART_Module;

architecture Behavioral of UART_Module is
    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal rx_state : state_t := IDLE;
    signal tx_state : state_t := IDLE;
    signal rx_clk_cnt, tx_clk_cnt : integer := 0;
    signal rx_bit_idx, tx_bit_idx : integer range 0 to 7 := 0;
    signal rx_byte_reg, tx_byte_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal r_tx_pin : std_logic := '1';
begin
    tx_pin <= r_tx_pin;

    -- RX Process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_state <= IDLE; rx_clk_cnt <= 0; rx_bit_idx <= 0; rx_done <= '0';
            else
                rx_done <= '0';
                case rx_state is
                    when IDLE =>
                        rx_clk_cnt <= 0; rx_bit_idx <= 0;
                        if rx_pin = '0' then rx_state <= START_BIT; end if;
                    when START_BIT =>
                        if rx_clk_cnt = (CLKS_PER_BIT-1)/2 then
                            if rx_pin = '0' then rx_clk_cnt <= 0; rx_state <= DATA_BITS;
                            else rx_state <= IDLE; end if;
                        else rx_clk_cnt <= rx_clk_cnt + 1; end if;
                    when DATA_BITS =>
                        if rx_clk_cnt < CLKS_PER_BIT-1 then rx_clk_cnt <= rx_clk_cnt + 1;
                        else
                            rx_clk_cnt <= 0; rx_byte_reg(rx_bit_idx) <= rx_pin;
                            if rx_bit_idx < 7 then rx_bit_idx <= rx_bit_idx + 1;
                            else rx_state <= STOP_BIT; end if;
                        end if;
                    when STOP_BIT =>
                        if rx_clk_cnt < CLKS_PER_BIT-1 then rx_clk_cnt <= rx_clk_cnt + 1;
                        else rx_state <= IDLE; rx_done <= '1'; rx_data <= rx_byte_reg; end if;
                end case;
            end if;
        end if;
    end process;

    -- TX Process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx_state <= IDLE; tx_busy <= '0'; r_tx_pin <= '1';
            else
                if tx_state = IDLE then
                    tx_busy <= '0'; r_tx_pin <= '1';
                    if tx_start = '1' then
                        tx_state <= START_BIT; tx_byte_reg <= tx_data;
                        tx_busy <= '1'; r_tx_pin <= '0'; tx_clk_cnt <= 0;
                    end if;
                else
                    if tx_clk_cnt < CLKS_PER_BIT-1 then tx_clk_cnt <= tx_clk_cnt + 1;
                    else
                        tx_clk_cnt <= 0;
                        case tx_state is
                            when START_BIT => tx_state <= DATA_BITS; tx_bit_idx <= 0;
                            when DATA_BITS =>
                                r_tx_pin <= tx_byte_reg(tx_bit_idx);
                                if tx_bit_idx < 7 then tx_bit_idx <= tx_bit_idx + 1;
                                else tx_state <= STOP_BIT; end if;
                            when STOP_BIT => r_tx_pin <= '1'; tx_state <= IDLE;
                            when others => tx_state <= IDLE;
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;

-- =============================================================================
-- 3. MAIN FSM (Manual Send dengan Wait Release)
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Main_FSM is
    Port (
        clk, rst : in std_logic;
        btn_start, btn_send : in std_logic;
        fft_done, tx_done : in std_logic;
        led_idle, led_proc, led_done : out std_logic;
        we_input, fft_start, tx_start_trigger : out std_logic
    );
end Main_FSM;

architecture Behavioral of Main_FSM is
    type state_t is (S_IDLE, S_PROCESS, S_DONE, S_SENDING, S_WAIT_RELEASE);
    signal current_state : state_t := S_IDLE;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then current_state <= S_IDLE;
            else
                case current_state is
                    when S_IDLE =>
                        if btn_start = '1' then current_state <= S_PROCESS; end if;
                    when S_PROCESS =>
                        if fft_done = '1' then current_state <= S_DONE; end if;
                    when S_DONE =>
                        if btn_send = '1' then current_state <= S_SENDING; end if;
                    when S_SENDING =>
                        if tx_done = '1' then current_state <= S_WAIT_RELEASE; end if;
                    when S_WAIT_RELEASE =>
                        if btn_send = '0' then current_state <= S_DONE; end if;
                end case;
            end if;
        end if;
    end process;

    led_idle <= '1' when current_state = S_IDLE else '0';
    led_proc <= '1' when current_state = S_PROCESS else '0';
    led_done <= '1' when (current_state = S_DONE or current_state = S_SENDING or current_state = S_WAIT_RELEASE) else '0';
    
    we_input <= '1' when current_state = S_IDLE else '0';
    fft_start <= '1' when current_state = S_PROCESS else '0';
    tx_start_trigger <= '1' when current_state = S_SENDING else '0';
end Behavioral;

-- =============================================================================
-- 4. TOP LEVEL (TUNING 5400 + DELAY 10ms)
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FFT_System_Sim_Ready is
    -- PERUBAHAN PENTING 1: Ganti 5208 ke 5400 untuk memperbaiki Left Shift Error (01 jadi 02)
    Generic ( CLKS_PER_BIT : integer := 5240 ); 
    Port (
        clk_50mhz : in std_logic;
        btn_rst_n   : in std_logic;
        btn_start_n : in std_logic;
        btn_send_n  : in std_logic;
        uart_rx   : in std_logic;
        uart_tx   : out std_logic;
        leds_n    : out std_logic_vector(2 downto 0)
    );
end FFT_System_Sim_Ready;

architecture Behavioral of FFT_System_Sim_Ready is
    signal rst_active, start_raw, send_raw : std_logic;
    signal start_clean, send_clean : std_logic;
    signal led_status_internal : std_logic_vector(2 downto 0);

    signal we_input, fft_start, fsm_tx_trigger : std_logic;
    signal fft_done_sig, tx_all_done_sig : std_logic := '0';
    signal rx_byte, tx_byte : std_logic_vector(7 downto 0);
    signal rx_done_sig, tx_start_sig, tx_busy_sig : std_logic;
    
    type ram_t is array (0 to 63) of std_logic_vector(15 downto 0);
    signal input_ram : ram_t := (others => (others => '0'));
    signal output_ram : ram_t := (others => (others => '0'));
    
    signal rx_byte_sel : std_logic := '0'; 
    signal rx_temp_high : std_logic_vector(7 downto 0);
    signal rx_addr, tx_addr : integer range 0 to 63 := 0;
    signal tx_byte_sel : std_logic := '0';
    signal proc_cnt : integer range 0 to 70 := 0;
    
    signal tx_has_finished : std_logic := '0';
    
    -- PERUBAHAN PENTING 2: Counter diperbesar untuk delay 10ms (500.000 clock)
    signal tx_wait_cnt : integer range 0 to 500000 := 0; 

begin
    rst_active <= not btn_rst_n;
    start_raw  <= not btn_start_n;
    send_raw   <= not btn_send_n;
    leds_n     <= not led_status_internal;

    U_Debounce_Start: entity work.Debounce port map(clk_50mhz, start_raw, start_clean);
    U_Debounce_Send: entity work.Debounce port map(clk_50mhz, send_raw, send_clean);

    U_FSM: entity work.Main_FSM port map (
        clk => clk_50mhz, rst => rst_active, 
        btn_start => start_clean, btn_send => send_clean,
        fft_done => fft_done_sig, tx_done => tx_all_done_sig,
        led_idle => led_status_internal(0), led_proc => led_status_internal(1), led_done => led_status_internal(2),
        we_input => we_input, fft_start => fft_start, tx_start_trigger => fsm_tx_trigger
    );

    U_UART: entity work.UART_Module 
    generic map ( CLKS_PER_BIT => CLKS_PER_BIT )
    port map (
        clk => clk_50mhz, rst => rst_active,
        rx_pin => uart_rx, tx_pin => uart_tx,
        rx_data => rx_byte, rx_done => rx_done_sig,
        tx_data => tx_byte, tx_start => tx_start_sig, tx_busy => tx_busy_sig
    );

    process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if rst_active = '1' then
                rx_addr <= 0; rx_byte_sel <= '0';
                tx_addr <= 0; tx_byte_sel <= '0';
                proc_cnt <= 0;
                fft_done_sig <= '0'; tx_all_done_sig <= '0';
                tx_start_sig <= '0';
                tx_has_finished <= '0';
                tx_wait_cnt <= 0;
            else
                -- 1. RX LOGIC
                if we_input = '0' then rx_addr <= 0; rx_byte_sel <= '0'; end if;
                if we_input = '1' and rx_done_sig = '1' then
                    if rx_byte_sel = '0' then
                        rx_temp_high <= rx_byte; rx_byte_sel <= '1';
                    else
                        input_ram(rx_addr) <= rx_temp_high & rx_byte; rx_byte_sel <= '0';
                        if rx_addr < 63 then rx_addr <= rx_addr + 1; else rx_addr <= 0; end if; 
                    end if;
                end if;

                -- 2. PROCESS LOGIC
                if fft_start = '1' then
                    tx_all_done_sig <= '0'; tx_has_finished <= '0';
                    if proc_cnt < 64 then
                        output_ram(proc_cnt) <= input_ram(proc_cnt);
                        proc_cnt <= proc_cnt + 1;
                        fft_done_sig <= '0';
                    else
                        fft_done_sig <= '1';
                    end if;
                else
                    proc_cnt <= 0; fft_done_sig <= '0';
                end if;

                -- 3. TX LOGIC (DENGAN HEAVY DELAY 10ms)
                tx_start_sig <= '0'; 
                
                if fsm_tx_trigger = '1' then
                    if tx_has_finished = '0' then
                        if tx_busy_sig = '0' and tx_start_sig = '0' then
                            
                            -- Logic Delay: Tunggu 10ms sebelum kirim byte berikutnya
                            if tx_wait_cnt < 10 then -- PERUBAHAN PENTING 3: Delay 10ms
                                tx_wait_cnt <= tx_wait_cnt + 1;
                            else
                                -- Kirim Byte
                                tx_start_sig <= '1'; 
                                tx_wait_cnt <= 0; 

                                if tx_byte_sel = '0' then
                                    tx_byte <= output_ram(tx_addr)(15 downto 8); 
                                    tx_byte_sel <= '1';
                                else
                                    tx_byte <= output_ram(tx_addr)(7 downto 0); 
                                    tx_byte_sel <= '0';
                                    if tx_addr < 63 then tx_addr <= tx_addr + 1;
                                    else 
                                        tx_all_done_sig <= '1'; tx_has_finished <= '1'; tx_addr <= 0; 
                                    end if;
                                end if;
                            end if;
                        end if;
                    end if;
                else
                   tx_addr <= 0; tx_byte_sel <= '0'; tx_all_done_sig <= '0'; tx_wait_cnt <= 0;
                end if;
            end if;
        end if;
    end process;
end Behavioral;