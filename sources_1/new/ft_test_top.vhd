library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ft_test_top is
    port (
        reset     : in  std_logic;
        ft_data   : in  std_logic_vector(7 downto 0);
        ft_rxf    : in  std_logic;
        ft_rd     : out std_logic;
        ft_oe     : out std_logic;
        ft_clkout : in  std_logic;
        led       : out std_logic_vector(7 downto 0)
    );
end ft_test_top;

architecture rtl of ft_test_top is
    signal data_o   : std_logic_vector(7 downto 0);
    signal valid_o  : std_logic;
    signal expected : unsigned(7 downto 0) := (others => '0');
    signal have_first, err, seen : std_logic := '0';
    signal count    : unsigned(31 downto 0) := (others => '0');
    signal oe_s, rd_s : std_logic;
signal clk_cnt : unsigned(25 downto 0) := (others => '0');
begin

    rx : entity work.ft_rx(rtl)
        port map (
            clk       => ft_clkout,
            reset     => reset,
            rxf_n     => ft_rxf,
            oe_n      => ft_oe,
            rd_n      => ft_rd,
            d_in      => ft_data,
            fifo_full => '0',
            data_o    => data_o,
            valid_o   => valid_o
        );

    process (ft_clkout)
    begin
        if rising_edge(ft_clkout) then
            if reset = '1' then
                have_first <= '0'; err <= '0'; seen <= '0'; count <= (others => '0');
            elsif valid_o = '1' then
                seen     <= '1';
                count    <= count + 1;
                expected <= unsigned(data_o) + 1;
                have_first <= '1';
                if have_first = '1' and unsigned(data_o) /= expected then
                    err <= '1';             -- latches on the first wrong byte
                end if;
            end if;
        end if;
    end process;

    led(0) <= seen; -- any byte ever received
    led(1) <= err; -- sequence error (should stay off)
    led(2) <= count(24); -- blinks while data flows
    led(3) <= not ft_rxf; -- chip has data waiting
    ft_oe <= oe_s;
    ft_rd <= rd_s;
    
    process (ft_clkout)
    begin
        if rising_edge(ft_clkout) then
            clk_cnt <= clk_cnt + 1;
        end if;
    end process;
    
    led(4) <= clk_cnt(25);-- blinks about every second if CLKOUT is arriving
    led(5) <= not oe_s; -- on when the FPGA asserts OE#
    led(6) <= not rd_s; -- on when the FPGA asserts RD#

end rtl;