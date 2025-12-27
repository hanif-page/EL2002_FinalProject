library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Simple_TX_Test is
    generic (
        g_CLKS_PER_BIT : integer := 5208  -- 50MHz / 115200 = ~434
    );
    port (
        i_Clk       : in  std_logic; -- Clock 50MHz
        i_UART_RX   : in  std_logic; -- Pin RX FPGA (Terhubung ke TX USB-TTL)
        o_UART_TX   : out std_logic  -- Pin TX FPGA (Terhubung ke RX USB-TTL)
    );
end Simple_TX_Test;

architecture RTL of Simple_TX_Test is

    type t_SM_Main is (s_Idle, s_RX_Start_Bit, s_RX_Data_Bits,
                       s_RX_Stop_Bit, s_TX_Start_Bit, s_TX_Data_Bits,
                       s_TX_Stop_Bit, s_Cleanup);
    signal r_SM_Main : t_SM_Main := s_Idle;

    signal r_Clk_Count : integer range 0 to g_CLKS_PER_BIT-1 := 0;
    signal r_Bit_Index : integer range 0 to 7 := 0;
    signal r_RX_Byte   : std_logic_vector(7 downto 0) := (others => '0');
    signal r_RX_Data   : std_logic := '1';
    signal r_RX_Data_R : std_logic := '1';

begin

    -- Process utama untuk State Machine UART (Receive & Transmit Echo)
    p_UART_ECHO : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            
            -- Sinkronisasi sinyal RX untuk menghindari metastability
            r_RX_Data_R <= i_UART_RX;
            r_RX_Data   <= r_RX_Data_R;

            case r_SM_Main is

                -- State: Menunggu Start Bit (Falling Edge pada RX)
                when s_Idle =>
                    o_UART_TX <= '1'; -- Default TX Line High (Idle)
                    r_Clk_Count <= 0;
                    r_Bit_Index <= 0;

                    if r_RX_Data = '0' then       -- Start bit terdeteksi
                        r_SM_Main <= s_RX_Start_Bit;
                    else
                        r_SM_Main <= s_Idle;
                    end if;

                -- State: Cek validitas Start Bit (tengah bit)
                when s_RX_Start_Bit =>
                    if r_Clk_Count = (g_CLKS_PER_BIT-1)/2 then
                        if r_RX_Data = '0' then
                            r_Clk_Count <= 0;
                            r_SM_Main   <= s_RX_Data_Bits;
                        else
                            r_SM_Main   <= s_Idle; -- False alarm
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_RX_Start_Bit;
                    end if;

                -- State: Baca 8 Bit Data
                when s_RX_Data_Bits =>
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_RX_Data_Bits;
                    else
                        r_Clk_Count <= 0;
                        r_RX_Byte(r_Bit_Index) <= r_RX_Data; -- Simpan bit
                        
                        if r_Bit_Index < 7 then
                            r_Bit_Index <= r_Bit_Index + 1;
                            r_SM_Main   <= s_RX_Data_Bits;
                        else
                            r_Bit_Index <= 0;
                            r_SM_Main   <= s_RX_Stop_Bit;
                        end if;
                    end if;

                -- State: Tunggu Stop Bit RX selesai, lalu Siap TX
                when s_RX_Stop_Bit =>
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_RX_Stop_Bit;
                    else
                        r_Clk_Count <= 0;
                        r_SM_Main   <= s_TX_Start_Bit; -- Langsung kirim balik (Echo)
                    end if;

                -- State: Kirim Start Bit (Logic 0)
                when s_TX_Start_Bit =>
                    o_UART_TX <= '0';
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_TX_Start_Bit;
                    else
                        r_Clk_Count <= 0;
                        r_SM_Main   <= s_TX_Data_Bits;
                    end if;

                -- State: Kirim 8 Bit Data (yang tadi diterima)
                when s_TX_Data_Bits =>
                    o_UART_TX <= r_RX_Byte(r_Bit_Index);
                    
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_TX_Data_Bits;
                    else
                        r_Clk_Count <= 0;
                        if r_Bit_Index < 7 then
                            r_Bit_Index <= r_Bit_Index + 1;
                            r_SM_Main   <= s_TX_Data_Bits;
                        else
                            r_Bit_Index <= 0;
                            r_SM_Main   <= s_TX_Stop_Bit;
                        end if;
                    end if;

                -- State: Kirim Stop Bit (Logic 1)
                when s_TX_Stop_Bit =>
                    o_UART_TX <= '1';
                    if r_Clk_Count < g_CLKS_PER_BIT-1 then
                        r_Clk_Count <= r_Clk_Count + 1;
                        r_SM_Main   <= s_TX_Stop_Bit;
                    else
                        r_Clk_Count <= 0;
                        r_SM_Main   <= s_Cleanup;
                    end if;

                -- State: Cleanup / Reset
                when s_Cleanup =>
                    r_SM_Main <= s_Idle;

                when others =>
                    r_SM_Main <= s_Idle;

            end case;
        end if;
    end process p_UART_ECHO;

end RTL;