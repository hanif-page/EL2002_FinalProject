library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity system_integration is
   Port (
       clk_50mhz  : in  STD_LOGIC;
       btn_start  : in  STD_LOGIC;
       btn_rst    : in  STD_LOGIC;
       btn_send   : in  STD_LOGIC;
       uart_rx    : in  STD_LOGIC;
       uart_tx    : out STD_LOGIC;
       led_idle   : out STD_LOGIC;
       led_proc   : out STD_LOGIC;
       led_done   : out STD_LOGIC
   );
end system_integration;

architecture Behavioral of system_integration is

   -- Component Declarations
   component fft_core is
       Port (
           clk, rst, i_start : in STD_LOGIC;
           i_mode : in STD_LOGIC; -- Unused in this system diagram, tied to '1' (FFT mode)
           i_data_re, i_data_im : in STD_LOGIC_VECTOR(15 downto 0);
           o_data_re, o_data_im : out STD_LOGIC_VECTOR(15 downto 0);
           o_done : out STD_LOGIC;
           o_idx : out STD_LOGIC_VECTOR(5 downto 0)
       );
   end component;

   component input_buffer is
       Port (
           clk, rst : in STD_LOGIC;
           i_rx_data : in STD_LOGIC_VECTOR(7 downto 0);
           i_rx_done, i_enable : in STD_LOGIC;
           i_rd_addr : in STD_LOGIC_VECTOR(5 downto 0);
           o_data_re, o_data_im : out STD_LOGIC_VECTOR(15 downto 0)
       );
   end component;

   component output_buffer is
       Port (
           clk, rst, i_wr_en : in STD_LOGIC;
           i_fft_re, i_fft_im : in STD_LOGIC_VECTOR(15 downto 0);
           i_tx_req : in STD_LOGIC;
           o_tx_data : out STD_LOGIC_VECTOR(7 downto 0)
       );
   end component;

   component uart_module is
       Port (
           clk, rst, rx_pin, tx_start : in STD_LOGIC;
           tx_data : in STD_LOGIC_VECTOR(7 downto 0);
           tx_pin, rx_done, tx_done : out STD_LOGIC;
           rx_data : out STD_LOGIC_VECTOR(7 downto 0)
       );
   end component;

   component main_fsm is
       Port (
           clk, rst, i_btn_start, i_btn_rst, i_btn_send, i_fft_done, i_tx_done : in STD_LOGIC;
           led_idle, led_proc, led_done, en_input, fft_start, tx_start, o_tx_next_byte : out STD_LOGIC
       );
   end component;

   -- Internal Signals
   signal rst_int        : std_logic;
   signal fft_start_sig  : std_logic;
   signal fft_done_sig   : std_logic;
   signal fft_idx_sig    : std_logic_vector(5 downto 0);
   signal fft_in_re, fft_in_im   : std_logic_vector(15 downto 0);
   signal fft_out_re, fft_out_im : std_logic_vector(15 downto 0);

   signal rx_data_sig    : std_logic_vector(7 downto 0);
   signal rx_done_sig    : std_logic;
   signal tx_data_sig    : std_logic_vector(7 downto 0);
   signal tx_start_sig   : std_logic;
   signal tx_done_sig    : std_logic;
   signal tx_next_byte_sig : std_logic;

   signal fsm_en_input   : std_logic;
   signal fsm_led_proc   : std_logic;

begin
   rst_int <= btn_rst; -- Active high reset

   -- Instantiations
   u_fft_core : fft_core port map(
       clk => clk_50mhz, rst => rst_int, i_start => fft_start_sig,
       i_mode => '1', -- Hardcoded to FFT mode
       i_data_re => fft_in_re, i_data_im => fft_in_im,
       o_data_re => fft_out_re, o_data_im => fft_out_im,
       o_done => fft_done_sig, o_idx => fft_idx_sig
   );

   u_input_buf : input_buffer port map(
       clk => clk_50mhz, rst => rst_int,
       i_rx_data => rx_data_sig, i_rx_done => rx_done_sig,
       i_enable => fsm_en_input, i_rd_addr => fft_idx_sig,
       o_data_re => fft_in_re, o_data_im => fft_in_im
   );

   u_output_buf : output_buffer port map(
       clk => clk_50mhz, rst => rst_int,
       -- Use FSM "Process" state LED as write enable for output buffer
       i_wr_en => fsm_led_proc,
       i_fft_re => fft_out_re, i_fft_im => fft_out_im,
       i_tx_req => tx_next_byte_sig, o_tx_data => tx_data_sig
   );

   u_uart : uart_module port map(
       clk => clk_50mhz, rst => rst_int, rx_pin => uart_rx,
       tx_start => tx_start_sig, tx_data => tx_data_sig,
       tx_pin => uart_tx, rx_data => rx_data_sig,
       rx_done => rx_done_sig, tx_done => tx_done_sig
   );

   u_fsm : main_fsm port map(
       clk => clk_50mhz, rst => rst_int,
       i_btn_start => btn_start, i_btn_rst => btn_rst, i_btn_send => btn_send,
       i_fft_done => fft_done_sig, i_tx_done => tx_done_sig,
       led_idle => led_idle, led_proc => fsm_led_proc, led_done => led_done,
       en_input => fsm_en_input, fft_start => fft_start_sig,
       tx_start => tx_start_sig, o_tx_next_byte => tx_next_byte_sig
   );

   -- Connect internal signal to output port
   led_proc <= fsm_led_proc;

end Behavioral;

