library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity flight_table is
    generic (
        TABLE_SIZE : integer := 64
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        
        write : in std_logic; 
        
        icao : in std_logic_vector(23 downto 0);
        callsign_w : in string(1 to 8);
        lat_w, lon_w : in std_logic_vector(16 downto 0);
        alt_w : in std_logic_vector(12 downto 0);
        speed_w : in unsigned(9 downto 0);
        heading_w : in unsigned(9 downto 0);
        callsign_r : out string(1 to 8);
        lat_r, lon_r : out std_logic_vector(16 downto 0);
        alt_r : out std_logic_vector(12 downto 0);
        speed_r : out unsigned(9 downto 0);
        heading_r : out unsigned(9 downto 0)
        
    );
end flight_table;

architecture rtl of flight_table is

    function is_empty (data: std_logic_vector) return boolean is
    begin
        for i in data'range loop
            if (data(i) /= '0') then
                return false;
            end if;
        end loop;
        return true;
    end function;

    type flight_record is record
        valid : std_logic;
        icao : std_logic_vector(23 downto 0); --key
        callsign : string(1 to 8);
        lat, lon : std_logic_vector(16 downto 0);
        alt : std_logic_vector(12 downto 0);
        speed : unsigned(9 downto 0);
        heading : unsigned(9 downto 0);
    end record; 
    
    type tracker_table_t is array (0 to TABLE_SIZE-1) of flight_record;
    signal tracker_table : tracker_table_t := (others =>
                                                        (valid => '0',
                                                         icao => (others => '0'),
                                                         callsign => (others => ' '),
                                                         lat => (others => '0'),
                                                         lon => (others => '0'),
                                                         alt => (others => '0'),
                                                         speed => (others => '0'),
                                                         heading => (others => '0')));
    
begin

    process (clk)
        variable icao_found : boolean;
    begin
        if rising_edge(clk) then
            if reset = '1' then
    
                tracker_table <= (others =>
                    (valid => '0',
                     icao => (others => '0'),
                     callsign => (others => ' '),
                     lat => (others => '0'),
                     lon => (others => '0'),
                     alt => (others => '0'),
                     speed => (others => '0'),
                     heading => (others => '0')));
    
            elsif write = '1' then
    
                -- Assume this is a new aircraft
                icao_found := false;
    
                -- First look for an existing aircraft
                for i in 0 to TABLE_SIZE-1 loop
    
                    if tracker_table(i).valid = '1' and
                       tracker_table(i).icao = icao then
    
                        icao_found := true;
    
                        -- Update this aircraft
                        if callsign_w /= "        " then
                            tracker_table(i).callsign <= callsign_w;
                        end if;
    
                        if not is_empty(lat_w) then
                            tracker_table(i).lat <= lat_w;
                        end if;
    
                        if not is_empty(lon_w) then
                            tracker_table(i).lon <= lon_w;
                        end if;
    
                        if not is_empty(alt_w) then
                            tracker_table(i).alt <= alt_w;
                        end if;
    
                        if not is_empty(std_logic_vector(speed_w)) then
                            tracker_table(i).speed <= speed_w;
                        end if;
    
                        if not is_empty(std_logic_vector(heading_w)) then
                            tracker_table(i).heading <= heading_w;
                        end if;
    
                        exit;
                    end if;
    
                end loop;
    
    
                -- If it wasn't already in the table,
                -- find ONE empty slot
                if not icao_found then
    
                    for i in 0 to TABLE_SIZE-1 loop
    
                        if tracker_table(i).valid = '0' then
    
                            tracker_table(i).valid <= '1';
                            tracker_table(i).icao <= icao;
                            tracker_table(i).callsign <= callsign_w;
                            tracker_table(i).lat <= lat_w;
                            tracker_table(i).lon <= lon_w;
                            tracker_table(i).alt <= alt_w;
                            tracker_table(i).speed <= speed_w;
                            tracker_table(i).heading <= heading_w;
    
                            exit;
                        end if;
    
                    end loop;
    
                end if;
    
            end if;
        end if;
    end process;


end rtl;
