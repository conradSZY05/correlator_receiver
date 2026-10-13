library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;


entity coordinate_translator is 
    generic ( -- 53.381410824758305, -2.1617052169511735
        HOST_LAT : integer := 6996808; -- lat scaled by 2^17
        HOST_LON : integer := 283339;
        H_PIXELS : integer := 640; -- horizontal screen pixel width
        V_PIXELS : integer := 480 -- vertical screen pixel height
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        start : in std_logic;
        lat : in signed(27 downto 0);
        lon : in signed(27 downto 0);

        
        done : out std_logic;
        x, y : out std_logic_vector(9 downto 0) -- x and y pixel coordinates in relation to host
    );
end coordinate_translator;

architecture rtl of coordinate_translator is

begin

    process (clk)
        variable lat_diff : signed(27 downto 0) := (others => '0');
        variable lon_diff : signed(27 downto 0) := (others => '0');
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                done <= '0';
                x <= (others => '0');
                y <= (others => '0');
            elsif (start = '1') then 
                -- assume that lat and lon both have valid values when start pulses
                -- the vga controller has 640x480 available pixels
                -- we take the absloute host lat and lon coordinates, and use that as the origin (centre of the screen)
                -- with the centre of the screen being the host, all we have to do is subtract the absolute difference from the input lat and lon
                -- centre is (320,240), latitude is x longitude is y
                lat_diff := abs(lat) - to_signed(V_PIXELS/2, 28);
                lon_diff := abs(lon) - to_signed(H_PIXELS/2, 28);

                x <= std_logic_vector(lat - lat_diff);
                y <= std_logic_vector(lon - lon_diff);
            end if;
        end if;
    end process;

end rtl;