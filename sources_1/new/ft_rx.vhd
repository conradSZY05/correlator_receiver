library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity ft_rx is
    port (
        clk : in  std_logic; -- 60 MHz CLKOUT from the FT2232H
        reset : in  std_logic;
        -- FT2232H pins (channel A, synchronous 245 FIFO mode)
        rxf_n : in  std_logic; -- low = data waiting
        oe_n : out std_logic;
        rd_n : out std_logic;
        d_in : in  std_logic_vector(7 downto 0);

        -- to the async FIFO (write side, same 60 MHz clock)
        fifo_full : in  std_logic; -- FIFOs prog_full, not full
        data_o : out std_logic_vector(7 downto 0);
        valid_o : out std_logic --  FIFOs wr_en
    );
end ft_rx;

architecture rtl of ft_rx is
    type state_t is (IDLE, OE_ON, READING, PAUSE);
    signal state    : state_t := IDLE;
    signal rst_sync : std_logic_vector(1 downto 0) := "11";
    signal oe_r, rd_r : std_logic := '1';
begin

    oe_n <= oe_r;
    rd_n <= rd_r;

    process (clk)
    begin
        if rising_edge(clk) then
            rst_sync <= rst_sync(0) & reset;   -- bring reset into the 60 MHz domain
            valid_o  <= '0';

            if rst_sync(1) = '1' then
                state <= IDLE;
                oe_r  <= '1';
                rd_r  <= '1';
            else
                case state is

                    when IDLE =>
                        -- data waiting and room for it: take control of the bus
                        if rxf_n = '0' and fifo_full = '0' then
                            oe_r  <= '0';
                            state <= OE_ON;
                        end if;

                    when OE_ON =>
                        -- OE# has been low for one clock, so the bus has turned around
                        if rxf_n = '1' then
                            oe_r  <= '1';
                            state <= IDLE;
                        elsif fifo_full = '0' then
                            rd_r  <= '0';
                            state <= READING;
                        end if;

                    when READING =>
                        -- RD# has been low since the last edge, so this edge consumes a byte
                        if rxf_n = '0' then
                            data_o  <= d_in;
                            valid_o <= '1';
                        end if;

                        if rxf_n = '1' then            -- ran out of data
                            rd_r  <= '1';
                            oe_r  <= '1';
                            state <= IDLE;
                        elsif fifo_full = '1' then     -- FIFO filling up: pause, keep OE# low
                            rd_r  <= '1';
                            state <= PAUSE;
                        end if;

                    when PAUSE =>
                        if rxf_n = '1' then
                            oe_r  <= '1';
                            state <= IDLE;
                        elsif fifo_full = '0' then
                            rd_r  <= '0';
                            state <= READING;
                        end if;

                end case;
            end if;
        end if;
    end process;

end rtl;