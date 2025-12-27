library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity output_buffer is
   Port (
       clk         : in  STD_LOGIC;
       rst         : in  STD_LOGIC; -- Added reset
       i_wr_en     : in  STD_LOGIC; -- Enables writing FFT results to RAM
       i_fft_re    : in  STD_LOGIC_VECTOR(15 downto 0); -- Corrected to 16-bit
       i_fft_im    : in  STD_LOGIC_VECTOR(15 downto 0); -- Corrected to 16-bit
       i_tx_req    : in  STD_LOGIC; -- Pulse to advance to the next byte for TX
       o_tx_data   : out STD_LOGIC_VECTOR(7 downto 0)
   );
end output_buffer;

architecture Behavioral of output_buffer is
   type ram_type is array (0 to 63) of std_logic_vector(31 downto 0);
   signal ram : ram_type := (others => (others => '0'));

   signal wr_addr_cnt : unsigned(5 downto 0) := (others => '0');
   signal rd_addr_cnt : unsigned(5 downto 0) := (others => '0');
   signal byte_cnt    : unsigned(1 downto 0) := (others => '0');
   signal current_word : std_logic_vector(31 downto 0) := (others => '0');

begin

   -- Write Process: Stores FFT data
   process(clk)
   begin
       if rising_edge(clk) then
           if rst = '1' then
               wr_addr_cnt <= (others => '0');
           elsif i_wr_en = '1' then
               ram(to_integer(wr_addr_cnt)) <= i_fft_im & i_fft_re;
               wr_addr_cnt <= wr_addr_cnt + 1;
           end if;
       end if;
   end process;

   -- Read/TX Process: Unpacks 32-bit word into 4 bytes
   -- Assumes order: Re_Low, Re_High, Im_Low, Im_High
   process(clk)
   begin
       if rising_edge(clk) then
           if rst = '1' then
               rd_addr_cnt <= (others => '0');
               byte_cnt <= (others => '0');
               current_word <= (others => '0');
               o_tx_data <= (others => '0');
           elsif i_tx_req = '1' then
               -- Load new word at the start of a 4-byte sequence
               if byte_cnt = "00" then
                   current_word <= ram(to_integer(rd_addr_cnt));
               end if;

               -- Mux the correct byte to output
               case byte_cnt is
                   when "00" => o_tx_data <= current_word(7 downto 0);
                   when "01" => o_tx_data <= current_word(15 downto 8);
                   when "10" => o_tx_data <= current_word(23 downto 16);
                   when "11" => o_tx_data <= current_word(31 downto 24);
                   when others => null;
               end case;

               -- Advance counters
               if byte_cnt = "11" then
                   rd_addr_cnt <= rd_addr_cnt + 1;
                   byte_cnt <= "00";
               else
                   byte_cnt <= byte_cnt + 1;
               end if;
           end if;
       end if;
   end process;

end Behavioral;