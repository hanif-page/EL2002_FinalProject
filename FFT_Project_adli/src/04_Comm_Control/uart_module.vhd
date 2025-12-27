library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_module is
   Generic (
       CLK_FREQ  : integer := 50000000;
       BAUD_RATE : integer := 9600
   );
   Port (
       clk       : in  STD_LOGIC;
       rst       : in  STD_LOGIC;
       rx_pin    : in  STD_LOGIC;
       tx_start  : in  STD_LOGIC;
       tx_data   : in  STD_LOGIC_VECTOR(7 downto 0);
       tx_pin    : out STD_LOGIC;
       rx_data   : out STD_LOGIC_VECTOR(7 downto 0);
       rx_done   : out STD_LOGIC;
       tx_done   : out STD_LOGIC
   );
end uart_module;

architecture Behavioral of uart_module is
   constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;

   -- TX Signals
   type tx_state_type is (TX_IDLE, TX_START_BIT, TX_DATA_BITS, TX_STOP_BIT);
   signal tx_state : tx_state_type := TX_IDLE;
   signal tx_timer : integer range 0 to BIT_PERIOD;
   signal tx_bit_cnt : integer range 0 to 7;
   signal tx_shift_reg : std_logic_vector(7 downto 0);

   -- RX Signals
   type rx_state_type is (RX_IDLE, RX_START_BIT, RX_DATA_BITS, RX_STOP_BIT);
   signal rx_state : rx_state_type := RX_IDLE;
   signal rx_timer : integer range 0 to BIT_PERIOD;
   signal rx_bit_cnt : integer range 0 to 7;
   signal rx_shift_reg : std_logic_vector(7 downto 0);
   signal rx_pin_sync : std_logic_vector(1 downto 0);

begin
   -- UART Transmitter
   process(clk)
   begin
       if rising_edge(clk) then
           if rst = '1' then
               tx_state <= TX_IDLE; tx_pin <= '1'; tx_done <= '0'; tx_timer <= 0;
           else
               tx_done <= '0';
               case tx_state is
                   when TX_IDLE =>
                       tx_pin <= '1';
                       if tx_start = '1' then
                           tx_shift_reg <= tx_data; tx_state <= TX_START_BIT; tx_timer <= 0;
                       end if;
                   when TX_START_BIT =>
                       tx_pin <= '0';
                       if tx_timer = BIT_PERIOD-1 then
                           tx_state <= TX_DATA_BITS; tx_bit_cnt <= 0; tx_timer <= 0;
                       else tx_timer <= tx_timer + 1; end if;
                   when TX_DATA_BITS =>
                       tx_pin <= tx_shift_reg(tx_bit_cnt);
                       if tx_timer = BIT_PERIOD-1 then
                           tx_timer <= 0;
                           if tx_bit_cnt = 7 then tx_state <= TX_STOP_BIT; else tx_bit_cnt <= tx_bit_cnt + 1; end if;
                       else tx_timer <= tx_timer + 1; end if;
                   when TX_STOP_BIT =>
                       tx_pin <= '1';
                       if tx_timer = BIT_PERIOD-1 then
                           tx_state <= TX_IDLE; tx_done <= '1';
                       else tx_timer <= tx_timer + 1; end if;
               end case;
           end if;
       end if;
   end process;

   -- UART Receiver
   process(clk) begin if rising_edge(clk) then rx_pin_sync <= rx_pin_sync(0) & rx_pin; end if; end process;
   process(clk)
   begin
       if rising_edge(clk) then
           if rst = '1' then
               rx_state <= RX_IDLE; rx_done <= '0'; rx_timer <= 0;
           else
               rx_done <= '0';
               case rx_state is
                   when RX_IDLE =>
                       if rx_pin_sync(1) = '0' then rx_state <= RX_START_BIT; rx_timer <= 0; end if;
                   when RX_START_BIT =>
                       if tx_timer = BIT_PERIOD/2-1 then
                            if rx_pin_sync(1) = '0' then rx_state <= RX_DATA_BITS; rx_bit_cnt <= 0; rx_timer <= 0;
                            else rx_state <= RX_IDLE; end if;
                       else rx_timer <= rx_timer + 1; end if;
                   when RX_DATA_BITS =>
                       if rx_timer = BIT_PERIOD-1 then
                           rx_timer <= 0; rx_shift_reg(rx_bit_cnt) <= rx_pin_sync(1);
                           if rx_bit_cnt = 7 then rx_state <= RX_STOP_BIT; else rx_bit_cnt <= rx_bit_cnt + 1; end if;
                       else rx_timer <= rx_timer + 1; end if;
                   when RX_STOP_BIT =>
                       if rx_timer = BIT_PERIOD-1 then
                           rx_state <= RX_IDLE; rx_done <= '1'; rx_data <= rx_shift_reg;
                       else rx_timer <= rx_timer + 1; end if;
               end case;
           end if;
       end if;
   end process;
end Behavioral;

