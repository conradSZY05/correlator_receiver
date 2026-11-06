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
        x_w : in std_logic_vector(8 downto 0); -- storing the local coordinates saved having to translate lat and lon on each framebuffer swap for each entry (up to 64)
        y_w : in std_logic_vector(7 downto 0);
        lat_w, lon_w : in signed(27 downto 0);
        alt_w : in unsigned(16 downto 0);
        speed_w : in unsigned(9 downto 0);
        heading_w : in unsigned(9 downto 0);
        callsign_r : out string(1 to 8);
        x_r : out std_logic_vector(8 downto 0);
        y_r : out std_logic_vector(7 downto 0);
        lat_r, lon_r : out signed(27 downto 0);
        alt_r : out unsigned(16 downto 0);
        speed_r : out unsigned(9 downto 0);
        heading_r : out unsigned(9 downto 0);
        
        rd_idx   : in unsigned(5 downto 0); -- renderer looks at each entry one by one, so thisll just cycle all 64 entries
        rd_valid : out std_logic -- is the current entry valid
        
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
        x : std_logic_vector(8 downto 0);
        y : std_logic_vector(7 downto 0);
        lat, lon : signed(27 downto 0);
        alt : unsigned(16 downto 0);
        speed : unsigned(9 downto 0);
        heading : unsigned(9 downto 0);
    end record; 
    
    type tracker_table_t is array (0 to TABLE_SIZE-1) of flight_record;
    signal tracker_table : tracker_table_t := (others =>
                                                        (valid => '0',
                                                         icao => (others => '0'),
                                                         callsign => (others => ' '),
                                                         x => (others => '0'),
                                                         y => (others => '0'),
                                                         lat => (others => '0'),
                                                         lon => (others => '0'),
                                                         alt => (others => '0'),
                                                         speed => (others => '0'),
                                                         heading => (others => '0')));
    
begin

    process (clk)
    begin
        if rising_edge(clk) then
            rd_valid   <= tracker_table(to_integer(rd_idx)).valid;
            callsign_r <= tracker_table(to_integer(rd_idx)).callsign;
            x_r        <= tracker_table(to_integer(rd_idx)).x;
            y_r        <= tracker_table(to_integer(rd_idx)).y;
            lat_r      <= tracker_table(to_integer(rd_idx)).lat;
            lon_r      <= tracker_table(to_integer(rd_idx)).lon;
            alt_r      <= tracker_table(to_integer(rd_idx)).alt;
            speed_r    <= tracker_table(to_integer(rd_idx)).speed;
            heading_r  <= tracker_table(to_integer(rd_idx)).heading;
        end if;
    end process;

    process (clk)
        variable icao_found : boolean := false;
        variable empty_slot_found : boolean := false;
        variable write_ind : integer := 0;
    begin
        if rising_edge(clk) then
            if reset = '1' then
    
                tracker_table <= (others =>
                    (valid => '0',
                     icao => (others => '0'),
                     callsign => (others => ' '),
                     x => (others => '0'),
                     y => (others => '0'),
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
                        
                        if not is_empty(std_logic_vector(x_w)) then
                            tracker_table(i).x <= x_w;
                        end if;
                        
                        if not is_empty(std_logic_vector(y_w)) then
                            tracker_table(i).y <= y_w;
                        end if;
    
                        if not is_empty(std_logic_vector(lat_w)) then
                            tracker_table(i).lat <= lat_w;
                        end if;
    
                        if not is_empty(std_logic_vector(lon_w)) then
                            tracker_table(i).lon <= lon_w;
                        end if;
    
                        if not is_empty(std_logic_vector(alt_w)) then
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
                    
                    if (write_ind = TABLE_SIZE-1) then -- make it circular so dont have to time how long since each flight updated
                        write_ind := 0;
                    end if;
                    
                    tracker_table(write_ind).valid <= '1';
                    tracker_table(write_ind).icao <= icao;
                    tracker_table(write_ind).callsign <= callsign_w;
                    tracker_table(write_ind).x <= x_w;
                    tracker_table(write_ind).y <= y_w;
                    tracker_table(write_ind).lat <= lat_w;
                    tracker_table(write_ind).lon <= lon_w;
                    tracker_table(write_ind).alt <= alt_w;
                    tracker_table(write_ind).speed <= speed_w;
                    tracker_table(write_ind).heading <= heading_w;
                    
                    write_ind := write_ind + 1;
    
                end if;
            end if;
        end if;
    end process;


end rtl;