library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_module is
    Generic (
        CLK_FREQ  : integer := 50000000;
        BAUD_RATE : integer := 9600
    );
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        rx_pin   : in  STD_LOGIC;
        tx_start : in  STD_LOGIC;
        tx_data  : in  STD_LOGIC_VECTOR(7 downto 0);
        tx_pin   : out STD_LOGIC;
        rx_data  : out STD_LOGIC_VECTOR(7 downto 0);
        rx_done  : out STD_LOGIC;
        tx_done  : out STD_LOGIC
    );
end uart_module;

architecture Behavioral of uart_module is
    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE; -- [cite: 1099]

    -- State Definitions [cite: 1101, 1111]
    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal tx_state, rx_state : state_type := IDLE;

    -- Timers with +1 range buffer to prevent "out of range" errors [cite: 1104, 1114]
    signal tx_timer : integer range 0 to BIT_PERIOD + 1 := 0;
    signal rx_timer : integer range 0 to BIT_PERIOD + 1 := 0;
    
    signal tx_bit_cnt, rx_bit_cnt : integer range 0 to 7 := 0;
    signal tx_shift_reg, rx_shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_pin_sync : std_logic_vector(1 downto 0) := "11"; -- [cite: 1121]

begin

    -- Synchronize rx_pin to clk domain [cite: 1161]
    process(clk)
    begin
        if rising_edge(clk) then
            rx_pin_sync <= rx_pin_sync(0) & rx_pin;
        end if;
    end process;

    -- UART Receiver Logic
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_state <= IDLE;
                rx_done  <= '0';
                rx_timer <= 0;
                rx_data  <= (others => '0'); -- [cite: 1167-1168]
            else
                rx_done <= '0'; -- Default pulse state [cite: 1171]
                
                case rx_state is
                    when IDLE =>
                        rx_timer <= 0;
                        rx_bit_cnt <= 0;
                        if rx_pin_sync(1) = '0' then -- Detection of Start Bit
                            rx_state <= START_BIT;
                        end if;

                    when START_BIT =>
                        -- Sample at middle of BIT_PERIOD [cite: 1177]
                        if rx_timer = (BIT_PERIOD/2) - 1 then
                            if rx_pin_sync(1) = '0' then
                                rx_state <= DATA_BITS;
                                rx_timer <= 0;
                            else
                                rx_state <= IDLE; -- False start
                            end if;
                        else
                            rx_timer <= rx_timer + 1;
                        end if;

                    when DATA_BITS =>
                        if rx_timer = BIT_PERIOD - 1 then
                            rx_timer <= 0;
                            rx_shift_reg(rx_bit_cnt) <= rx_pin_sync(1); -- [cite: 1184]
                            if rx_bit_cnt = 7 then
                                rx_state <= STOP_BIT;
                            else
                                rx_bit_cnt <= rx_bit_cnt + 1;
                            end if;
                        else
                            rx_timer <= rx_timer + 1;
                        end if;

                    when STOP_BIT =>
                        if rx_timer = BIT_PERIOD - 1 then
                            rx_data  <= rx_shift_reg; -- Output the full byte 
                            rx_done  <= '1';          -- Signal byte completion
                            rx_state <= IDLE;        -- Return to IDLE for next byte
                            rx_timer <= 0;           -- Explicit reset for High/Low Byte sequence
                        else
                            rx_timer <= rx_timer + 1;
                        end if;

                    when others =>
                        rx_state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    -- UART Transmitter Logic (Included for system completeness) [cite: 1123-1159]
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tx_state <= IDLE;
                tx_pin   <= '1';
                tx_done  <= '0';
            else
                tx_done <= '0';
                case tx_state is
                    when IDLE =>
                        tx_pin <= '1';
                        if tx_start = '1' then
                            tx_shift_reg <= tx_data;
                            tx_state <= START_BIT;
                            tx_timer <= 0;
                        end if;

                    when START_BIT =>
                        tx_pin <= '0';
                        if tx_timer = BIT_PERIOD - 1 then
                            tx_state <= DATA_BITS;
                            tx_timer <= 0;
                            tx_bit_cnt <= 0;
                        else
                            tx_timer <= tx_timer + 1;
                        end if;

                    when DATA_BITS =>
                        tx_pin <= tx_shift_reg(tx_bit_cnt);
                        if tx_timer = BIT_PERIOD - 1 then
                            tx_timer <= 0;
                            if tx_bit_cnt = 7 then
                                tx_state <= STOP_BIT;
                            else
                                tx_bit_cnt <= tx_bit_cnt + 1;
                            end if;
                        else
                            tx_timer <= tx_timer + 1;
                        end if;

                    when STOP_BIT =>
                        tx_pin <= '1';
                        if tx_timer = BIT_PERIOD - 1 then
                            tx_done  <= '1';
                            tx_state <= IDLE;
                        else
                            tx_timer <= tx_timer + 1;
                        end if;
                    when others => tx_state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;