library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity framebuffer is
    generic (
        ADDRESSES : integer := 76800 -- 320 x 240
    );
    port (
        wr_clk : in std_logic; -- 100 MHz
        wr_en : in std_logic;
        wr_addr : in std_logic_vector(16 downto 0);
        wr_data : in std_logic_vector(0 downto 0);
        
        r_clk : in std_logic; -- 25.125 MHz
        r_addr : in std_logic_vector(16 downto 0);
        r_data : out std_logic_vector(0 downto 0)
    );
end framebuffer;

architecture rtl of framebuffer is
    type ramtype is array(0 to ADDRESSES - 1) of std_logic_vector(0 downto 0);
    signal mem_ram : ramtype;
begin

    process (wr_clk)
    begin
        if rising_edge(wr_clk) then
            if (wr_en = '1') then
                mem_ram(to_integer(unsigned(wr_addr))) <= wr_data;
            end if;
        end if;
    end process;

    process (r_clk) 
    begin
        if rising_edge(r_clk) then
           r_data <= mem_ram(to_integer(unsigned(r_addr)));
        end if;
    end process;
    
end rtl;
