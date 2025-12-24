library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main_fsm is
   Port (
       clk           : in  STD_LOGIC;
       rst           : in  STD_LOGIC;
       i_btn_start   : in  STD_LOGIC;
       i_btn_rst     : in  STD_LOGIC;
       i_btn_send    : in  STD_LOGIC;
       i_fft_done    : in  STD_LOGIC;
       i_tx_done     : in  STD_LOGIC;
       led_idle      : out STD_LOGIC;
       led_proc      : out STD_LOGIC;
       led_done      : out STD_LOGIC;
       en_input      : out STD_LOGIC;
       fft_start     : out STD_LOGIC;
       tx_start      : out STD_LOGIC;
       -- ADDED PORT for functional system to control output buffer
       o_tx_next_byte: out STD_LOGIC
   );
end main_fsm;

architecture Behavioral of main_fsm is
   -- States broken down to handle pulse generation and waiting
   type state_type is (S_IDLE, S_PROCESS_START, S_PROCESS_WAIT, S_DONE, S_SEND_CMD, S_SEND_WAIT);
   signal state : state_type := S_IDLE;
   signal send_cnt : unsigned(8 downto 0) := (others => '0'); -- 64 points * 4 bytes = 256 bytes

begin
   process(clk)
   begin
       if rising_edge(clk) then
           if rst = '1' or i_btn_rst = '1' then
               state <= S_IDLE;
               send_cnt <= (others => '0');
               led_idle <= '0'; led_proc <= '0'; led_done <= '0';
               en_input <= '0'; fft_start <= '0'; tx_start <= '0'; o_tx_next_byte <= '0';
           else
               -- Default control signals to '0' for pulse generation
               fft_start <= '0'; tx_start <= '0'; o_tx_next_byte <= '0';
               -- Default LEDs/enables based on state (Moore outputs)
               led_idle <= '0'; led_proc <= '0'; led_done <= '0'; en_input <= '0';
              
               case state is
                   when S_IDLE =>
                       led_idle <= '1'; en_input <= '1';
                       if i_btn_start = '1' then state <= S_PROCESS_START; end if;

                   when S_PROCESS_START =>
                       led_proc <= '1'; fft_start <= '1'; -- Generate pulse
                       state <= S_PROCESS_WAIT;

                   when S_PROCESS_WAIT =>
                       led_proc <= '1';
                       if i_fft_done = '1' then state <= S_DONE; end if;

                   when S_DONE =>
                       led_done <= '1';
                       if i_btn_send = '1' then
                           send_cnt <= (others => '0');
                           state <= S_SEND_CMD;
                       end if;

                   when S_SEND_CMD =>
                       led_done <= '1'; tx_start <= '1'; -- Pulse UART to send current byte
                       state <= S_SEND_WAIT;

                   when S_SEND_WAIT =>
                       led_done <= '1';
                       if i_tx_done = '1' then
                           if send_cnt = 255 then
                               state <= S_DONE;
                           else
                               send_cnt <= send_cnt + 1;
                               o_tx_next_byte <= '1'; -- Pulse buffer to prepare NEXT byte
                               state <= S_SEND_CMD;
                           end if;
                       end if;
               end case;
           end if;
       end if;
   end process;
end Behavioral;

