library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity input_buffer is
   Port (
       clk         : in  STD_LOGIC;
       rst         : in  STD_LOGIC;
       i_rx_data   : in  STD_LOGIC_VECTOR(7 downto 0);
       i_rx_done   : in  STD_LOGIC;
       i_enable    : in  STD_LOGIC; -- Active high during IDLE state to allow writing
       i_rd_addr   : in  STD_LOGIC_VECTOR(5 downto 0); -- Address from FFT core
       o_data_re   : out STD_LOGIC_VECTOR(15 downto 0);
       o_data_im   : out STD_LOGIC_VECTOR(15 downto 0)
   );
end input_buffer;

architecture Behavioral of input_buffer is
   -- 64-depth RAM, 32-bit wide to store 16-bit Re + 16-bit Im
   type ram_type is array (0 to 63) of std_logic_vector(31 downto 0);
   signal ram : ram_type := (others => (others => '0'));

   signal wr_addr_cnt : unsigned(5 downto 0) := (others => '0');
   signal byte_cnt    : unsigned(1 downto 0) := (others => '0');
   signal temp_reg    : std_logic_vector(31 downto 0) := (others => '0');

begin

   -- Write Process: Packs 4 bytes into one 32-bit complex word
   -- Assumes order: Re_Low, Re_High, Im_Low, Im_High
   process(clk)
   begin
       if rising_edge(clk) then
           if rst = '1' then
               wr_addr_cnt <= (others => '0');
               byte_cnt <= (others => '0');
               temp_reg <= (others => '0');
           elsif i_enable = '1' and i_rx_done = '1' then
               case byte_cnt is
                   when "00" => temp_reg(7 downto 0)   <= i_rx_data;
                   when "01" => temp_reg(15 downto 8)  <= i_rx_data;
                   when "10" => temp_reg(23 downto 16) <= i_rx_data;
                   when "11" => temp_reg(31 downto 24) <= i_rx_data;
                   when others => null;
               end case;

               if byte_cnt = "11" then
                   ram(to_integer(wr_addr_cnt)) <= i_rx_data & temp_reg(23 downto 0);
                   wr_addr_cnt <= wr_addr_cnt + 1;
                   byte_cnt <= "00";
               else
                   byte_cnt <= byte_cnt + 1;
               end if;
           end if;
       end if;
   end process;

   -- Read Process: Asynchronous read for FFT access
   o_data_re <= ram(to_integer(unsigned(i_rd_addr)))(15 downto 0);
   o_data_im <= ram(to_integer(unsigned(i_rd_addr)))(31 downto 16);

end Behavioral;

